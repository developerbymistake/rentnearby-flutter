import 'dart:async';

import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../services/notification_service.dart';
import '../../../services/system_settings_channel.dart';
import '../../../services/taxi_ring_service.dart';
import '../../../services/taxi_ring_session.dart';
import '../../../widgets/ring/ring_call_parts.dart';
import '../../../widgets/ring/ring_countdown.dart';
import '../strings/stay_ring_strings.dart';
import 'stay_ring_api.dart';

enum StayRingAction {
  accept,
  decline;

  static StayRingAction? parse(Object? raw) => switch (raw) {
        'accept' => accept,
        'decline' => decline,
        _ => null,
      };
}

/// Call-style screen for a new stay enquiry. Accept opens the enquiry in Enquiries; Decline only silences
/// this phone. Neither changes the enquiry.
class StayRingScreen extends StatefulWidget {
  const StayRingScreen({
    super.key,
    required this.enquiryId,
    this.action,
    this.expiresAt,
    this.info = const StayRingInfo(),
    this.alert,
    this.notifier,
    this.onAccepted,
    this.onClose,
    this.clock,
    this.closeDelay = const Duration(seconds: 3),
    this.sendAccepted,
  });

  final String enquiryId;
  final StayRingAction? action;
  final DateTime? expiresAt;
  final StayRingInfo info;
  final RingAlertControl? alert;
  final TaxiRingNotifier? notifier;
  final void Function(String enquiryId)? onAccepted;
  final VoidCallback? onClose;
  final DateTime Function()? clock;
  final Duration closeDelay;
  final Future<void> Function(String enquiryId)? sendAccepted;

  static StayRingScreen fromArguments(Object? args) {
    final map = args is Map ? args : const {};
    final at = map['expiresAt'];
    return StayRingScreen(
      enquiryId: map['enquiryId']?.toString() ?? '',
      action: StayRingAction.parse(map['action']),
      expiresAt: at is String ? DateTime.tryParse(at)?.toUtc() : null,
      info: StayRingInfo.fromData(map),
    );
  }

  static void openEnquiry(String enquiryId) {
    if (!Get.isRegistered<NotificationService>()) return;
    NotificationService.to.openActionRoute(AppRoutes.stayEnquiries, {'enquiryId': enquiryId});
  }

  @override
  State<StayRingScreen> createState() => _StayRingScreenState();
}

enum _Phase { ringing, missed, ended }

class _StayRingScreenState extends State<StayRingScreen> {
  static const Color _onDark = RingCallLook.onDark;

  late final RingAlertControl _alert = widget.alert ?? SystemSettingsChannel.instance;
  late final TaxiRingNotifier _notifier = widget.notifier ?? PluginTaxiRingNotifier(FlutterLocalNotificationsPlugin());
  late final String _tag = TaxiRingNotification.stayTagFor(widget.enquiryId);
  late final Duration _window = _left();
  final ValueNotifier<int> _ticks = ValueNotifier(0);
  Timer? _tick;
  Timer? _closeTimer;
  Animation<double>? _routeAnimation;
  _Phase _phase = _Phase.ringing;
  String? _endReason;
  bool _claimed = false;
  bool _finished = false;

  String get _id => widget.enquiryId;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  Duration _left() {
    final at = widget.expiresAt;
    if (at == null) return TaxiRingPush.maxRing;
    final left = RingCountdown.remaining(at, offset: Duration.zero, now: _now());
    return left > TaxiRingPush.maxRing ? TaxiRingPush.maxRing : left;
  }

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    TaxiRingSession.ended.addListener(_onRingEnded);
    TaxiRingSession.relaunched.addListener(_onRelaunched);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimation);
    unawaited(_alert.ringAlertEnd(_tag).catchError((_) => false));
    TaxiRingSession.ended.removeListener(_onRingEnded);
    TaxiRingSession.relaunched.removeListener(_onRelaunched);
    _tick?.cancel();
    _closeTimer?.cancel();
    _ticks.dispose();
    super.dispose();
  }

  void _start() {
    if (!mounted || _finished) return;
    final ended = TaxiRingSession.ended.value;
    if (ended != null && ended.role == RingRole.stay && ended.offerId == _id) return _onRingEnded();
    switch (widget.action) {
      case StayRingAction.accept:
        unawaited(_accept());
      case StayRingAction.decline:
        unawaited(_decline());
      case null:
        if (_left() <= Duration.zero) return _toMissed();
        _claim();
    }
  }

  // The native cover over the lock screen lifts at the first hold, so it waits until this page is fully on top.
  void _claim() {
    if (_claimed || _finished || !mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final animation = route?.animation;
    if (animation != null && animation.status != AnimationStatus.completed) {
      if (_routeAnimation == null) {
        _routeAnimation = animation;
        animation.addStatusListener(_onRouteAnimation);
      }
      return;
    }
    _claimed = true;
    _hold();
  }

  void _onRouteAnimation(AnimationStatus status) {
    if (status == AnimationStatus.completed) _claim();
  }

  void _onRelaunched() {
    final r = TaxiRingSession.relaunched.value;
    if (!mounted || r == null || r.offerId != _id || _finished || !_claimed) return;
    _hold();
  }

  void _hold() => unawaited(_alert.ringAlertHold(_tag, _left()).catchError((_) => false));

  Future<void> _endAlert({bool unlock = false}) async {
    try {
      await _alert.ringAlertEnd(_tag, unlock: unlock);
    } catch (_) {}
  }

  Future<void> _stopRing() async {
    await TaxiRingNotification.stopStay(_notifier, _id);
    await TaxiRingEndedLog.record(_id, _now());
  }

  void _onTick() {
    if (!mounted || _phase != _Phase.ringing) return;
    _ticks.value++;
    if (_left() <= Duration.zero) _toMissed();
  }

  void _toMissed() {
    if (_phase != _Phase.ringing || _finished) return;
    unawaited(_stopRing());
    setState(() => _phase = _Phase.missed);
    _scheduleClose();
  }

  void _onRingEnded() {
    final e = TaxiRingSession.ended.value;
    if (!mounted || e == null || e.role != RingRole.stay || e.offerId != _id || _finished) return;
    if (e.reason == StayRingEnds.declinedHere) {
      unawaited(_close());
      return;
    }
    if (e.reason == StayRingEnds.missed) return _toMissed();
    unawaited(_stopRing());
    setState(() {
      _phase = _Phase.ended;
      _endReason = e.reason;
    });
    _scheduleClose();
  }

  void _scheduleClose() {
    if (_closeTimer != null || _finished) return;
    _tick?.cancel();
    _closeTimer = Timer(widget.closeDelay, () => unawaited(_close()));
  }

  Future<void> _accept() async {
    if (_finished) return;
    _finished = true;
    _tick?.cancel();
    _closeTimer?.cancel();
    await _stopRing();
    unawaited(_tellAccepted());
    await _endAlert(unlock: true);
    if (!mounted) return;
    final cb = widget.onAccepted;
    if (cb != null) return cb(_id);
    final nav = Get.key.currentState;
    if (nav != null && nav.canPop()) {
      Get.back<void>();
    } else {
      Get.offAllNamed(AppRoutes.main);
    }
    StayRingScreen.openEnquiry(_id);
  }

  // Accept stops the ring on the owner's other phones; Decline sends nothing.
  Future<void> _tellAccepted() async {
    try {
      final send = widget.sendAccepted;
      if (send != null) return await send(_id);
      await StayRingApi.sendAccepted(_id);
    } catch (_) {}
  }

  Future<void> _decline() async {
    if (_finished) return;
    await _stopRing();
    await _close();
  }

  Future<void> _close() async {
    if (_finished) return;
    _finished = true;
    _tick?.cancel();
    _closeTimer?.cancel();
    await _endAlert();
    if (!mounted) return;
    final cb = widget.onClose;
    if (cb != null) return cb();
    final nav = Get.key.currentState;
    if (nav != null && nav.canPop()) {
      Get.back<void>();
    } else {
      Get.offAllNamed(AppRoutes.main);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RingCallPage(onClose: () => unawaited(_close()), child: _body());
  }

  Widget _body() => switch (_phase) {
        _Phase.ringing => _ring(),
        _Phase.missed => RingStateView(
            key: const ValueKey('stay_ring_missed'),
            eyebrow: StayRingScreenStrings.eyebrow,
            art: ListingArt.alarmClock,
            title: StayRingScreenStrings.missedTitle,
            sub: StayRingScreenStrings.stillWaiting,
            primary: StayRingScreenStrings.openEnquiries,
            onPrimary: () => unawaited(_accept()),
            secondary: StayRingScreenStrings.close,
            onSecondary: () => unawaited(_close()),
          ),
        _Phase.ended => RingStateView(
            key: const ValueKey('stay_ring_ended'),
            eyebrow: StayRingScreenStrings.eyebrow,
            art: ListingArt.stay,
            title: StayRingScreenStrings.endTitle(_endReason),
            sub: StayRingScreenStrings.stillWaiting,
            primary: StayRingScreenStrings.close,
            onPrimary: () => unawaited(_close()),
          ),
      };

  Widget _line(String text) => Padding(
        padding: EdgeInsets.only(top: DS.gv(6)),
        child: Text(text, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w400, _onDark, height: 1.5)),
      );

  Widget _ring() {
    final info = widget.info;
    final dates = StayRingScreenStrings.dates(info.checkIn, info.checkOut);
    final guests = info.guests;
    final price = info.price;
    final column = Padding(
      padding: DS.insets(l: 24, r: 24, t: 40, b: 40),
      child: Column(
        children: [
          Text(StayRingScreenStrings.eyebrow.toUpperCase(), textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, _onDark.withValues(alpha: Alpha.v80), letterSpacing: 0.6)),
          Gap.v(10),
          Text(StayRingScreenStrings.title, textAlign: TextAlign.center, style: Ink3D.text(28, FontWeight.w700, _onDark, height: 1.25)),
          Gap.v(14),
          if (info.stayName.isNotEmpty) RingChip(info.stayName, key: const ValueKey('stay_ring_stay')),
          if (info.travellerFirstName.isNotEmpty) _line(StayRingScreenStrings.from(info.travellerFirstName)),
          if (dates.isNotEmpty) _line(dates),
          if (guests != null) _line(StayRingScreenStrings.guests(guests)),
          if (price != null) _line(StayRingScreenStrings.price(price)),
          Gap.v(44),
          RingCallDial(
            art: ListingArt.stay,
            ticks: _ticks,
            progressOf: () => _window.inMilliseconds <= 0 ? 0.0 : (_left().inMilliseconds / _window.inMilliseconds).clamp(0.0, 1.0),
          ),
          Gap.v(34),
          ValueListenableBuilder<int>(
            valueListenable: _ticks,
            builder: (context, _, _) {
              final left = _left();
              final spoken = RingCountdown.text(Duration(seconds: ((left.inSeconds + 9) ~/ 10) * 10));
              return Semantics(
                liveRegion: true,
                label: spoken,
                child: ExcludeSemantics(
                  child: Text(RingCountdown.text(left), key: const ValueKey('ring_countdown'), style: Ink3D.text(28, FontWeight.w600, _onDark, letterSpacing: 1)),
                ),
              );
            },
          ),
          const Spacer(),
          RingCallButtons(
            declineLabel: StayRingScreenStrings.decline,
            acceptLabel: StayRingScreenStrings.accept,
            onDecline: () => unawaited(_decline()),
            onAccept: () => unawaited(_accept()),
          ),
          Gap.v(28),
          Text(StayRingScreenStrings.swipeUp, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, _onDark.withValues(alpha: Alpha.high))),
        ],
      ),
    );
    return RingCallLayout(onSwipeUp: () => unawaited(_accept()), child: column);
  }
}
