import 'dart:async';
import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../services/system_settings_channel.dart';
import '../../../services/taxi_ring_service.dart';
import '../../../services/taxi_ring_session.dart';
import '../../../widgets/ring/ring_call_parts.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../taxi_driver/strings/taxi_work_strings.dart';
import '../../taxi_driver/taxi_driver_deps.dart';
import '../../trip/utils/taxi_result.dart';
import 'controllers/driver_requests_controller.dart';
import 'data/driver_request_repository.dart';
import 'models/driver_request_models.dart';
import 'models/ring_end.dart';
import 'strings/driver_ring_strings.dart';
import '../../../widgets/ring/ring_countdown.dart';

enum DriverRingAction {
  accept,
  decline;

  static DriverRingAction? parse(Object? raw) => switch (raw) {
        'accept' => accept,
        'decline' => decline,
        _ => null,
      };
}

class DriverRingScreen extends StatefulWidget {
  const DriverRingScreen({
    super.key,
    required this.offerId,
    this.action,
    this.expiresAt,
    this.controller,
    this.onAccepted,
    this.onClose,
    this.onChooseRoute,
    this.closeDelay = const Duration(seconds: 3),
    this.alert,
  });

  final String offerId;
  final DriverRingAction? action;
  final DateTime? expiresAt;
  final DriverRequestsController? controller;
  final void Function(String offerId)? onAccepted;
  final VoidCallback? onClose;
  final VoidCallback? onChooseRoute;
  final Duration closeDelay;
  final RingAlertControl? alert;

  static DriverRingScreen fromArguments(Object? args) {
    final map = args is Map ? args : const {};
    final at = map['expiresAt'];
    return DriverRingScreen(
      offerId: map['offerId']?.toString() ?? '',
      action: DriverRingAction.parse(map['action']),
      expiresAt: at is String ? DateTime.tryParse(at)?.toUtc() : null,
    );
  }

  @override
  State<DriverRingScreen> createState() => _DriverRingScreenState();
}

class _DriverRingScreenState extends State<DriverRingScreen> {
  static const Color _onDark = RingCallLook.onDark;
  static const String _art = 'assets/images/design/travel3d/taxi.png';
  static const Duration _ringWindow = Duration(minutes: 5);

  late final DriverRequestsController _c = widget.controller ?? DriverRequestsController.to;
  late final RingAlertControl _alert = widget.alert ?? SystemSettingsChannel.instance;
  late final String _tag = TaxiRingNotification.tagFor(widget.offerId);
  final ValueNotifier<int> _ticks = ValueNotifier(0);
  Timer? _tick;
  Timer? _closeTimer;
  bool _loadFailed = false;
  bool _actionFailed = false;
  bool _requestsPaused = false;
  bool _actionRan = false;
  bool _finished = false;
  bool _missed = false;
  bool _loading = false;
  bool _claimed = false;
  Animation<double>? _routeAnimation;
  RingEnd? _pushedEnd;

  String get _id => widget.offerId;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    TaxiRingSession.ended.addListener(_onRingEnded);
    TaxiRingSession.relaunched.addListener(_onRelaunched);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _claim();
      _load();
    });
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

  void _onRelaunched() {
    final r = TaxiRingSession.relaunched.value;
    if (!mounted || r == null || r.offerId != _id || _finished || !_claimed) return;
    _hold();
  }

  void _onRouteAnimation(AnimationStatus status) {
    if (status == AnimationStatus.completed) _claim();
  }

  void _hold() {
    final o = _c.offer(_id);
    final at = widget.expiresAt;
    final left = o != null
        ? _c.remaining(o)
        : at != null
            ? RingCountdown.remaining(at, offset: _c.clockOffset.value, now: DateTime.now())
            : TaxiRingPush.maxRing;
    unawaited(_alert.ringAlertHold(_tag, left).catchError((_) => false));
  }

  Future<void> _endAlert({bool unlock = false}) async {
    try {
      await _alert.ringAlertEnd(_tag, unlock: unlock);
    } catch (_) {}
  }

  // Only the countdown and the arc listen to the tick; the page rebuilds on a real state change.
  void _onTick() {
    if (!mounted) return;
    _ticks.value++;
    final o = _c.offer(_id);
    final expired = o != null && !_missed && o.state == OfferState.ringing && _c.remaining(o) <= Duration.zero;
    final failedWithTime = o == null && _loadFailed && widget.expiresAt != null;
    if (expired || failedWithTime) setState(() {});
  }

  void _onRingEnded() {
    final e = TaxiRingSession.ended.value;
    if (!mounted || e == null || e.offerId != _id || _finished) return;
    final end = RingEnd.forReason(e.reason, paymentOn: PlanGate.paymentOn);
    setState(() => _pushedEnd = end);
    unawaited(_c.stopRing(_id));
    if (end.kind == RingEndKind.ended) _scheduleClose();
  }

  Future<void> _load() async {
    if (!mounted || _loading) return;
    _loading = true;
    setState(() => _loadFailed = false);
    final listed = _c.loaded.value ? Future<void>.value() : _c.load();
    final r = await _c.loadOffer(_id);
    await listed;
    _loading = false;
    if (!mounted) return;
    if (r is TaxiPaused<DriverOffer> && _c.offer(_id) == null) {
      setState(() => _requestsPaused = true);
      return;
    }
    if (r is! TaxiOk<DriverOffer> && _c.offer(_id) == null) {
      setState(() => _loadFailed = true);
      return;
    }
    _settle();
  }

  bool _ringing(DriverOffer o) => o.state == OfferState.ringing && _c.remaining(o) > Duration.zero;

  bool _answered(DriverOffer o) => o.state == OfferState.accepted || o.state == OfferState.selected || o.state == OfferState.confirmed;

  void _settle() {
    final o = _c.offer(_id);
    if (o == null || _finished) return;
    if (_answered(o) || !_ringing(o)) unawaited(_c.stopRing(_id));
    if (_answered(o)) {
      unawaited(_openDetail());
      return;
    }
    if (!_ringing(o)) {
      final end = RingEnd.forOffer(o, paymentOn: PlanGate.paymentOn) ?? RingEnd.missed;
      if (end.kind == RingEndKind.missed || end.kind == RingEndKind.ended) _scheduleClose();
      if (mounted) setState(() {});
      return;
    }
    _claimed ? _hold() : _claim();
    final a = widget.action;
    if (a != null && !_actionRan) {
      _actionRan = true;
      unawaited(a == DriverRingAction.accept ? _accept() : _decline());
    }
  }

  void _scheduleClose() {
    if (_closeTimer != null || _finished) return;
    _tick?.cancel();
    _closeTimer = Timer(widget.closeDelay, _close);
  }

  void _showMissed() {
    _missed = true;
    _scheduleClose();
    if (mounted) setState(() {});
  }

  Future<void> _openDetail() async {
    if (_finished) return;
    _finished = true;
    _tick?.cancel();
    await _endAlert(unlock: true);
    if (!mounted) return;
    final cb = widget.onAccepted;
    if (cb != null) return cb(_id);
    Get.offNamed(AppRoutes.taxiRequestDetail, arguments: {'offerId': _id});
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
      Get.offNamed(AppRoutes.taxiRequests);
    }
  }

  Future<void> _chooseRoute() async {
    final cb = widget.onChooseRoute;
    if (cb != null) return cb();
    await _endAlert(unlock: true);
    await _close();
    TaxiDriverDeps.openChooseRoute();
  }

  Future<void> _accept() async {
    final r = await _c.accept(_id);
    if (!mounted) return;
    _afterAnswer(r, openOnOk: true);
  }

  Future<void> _decline() async {
    final r = await _c.decline(_id);
    if (!mounted) return;
    _afterAnswer(r, openOnOk: false);
  }

  void _afterAnswer(TaxiResult<DriverOffer> r, {required bool openOnOk}) {
    switch (r) {
      case TaxiOk<DriverOffer>():
        unawaited(openOnOk ? _openDetail() : _close());
      case TaxiOfferMissed<DriverOffer>():
        _showMissed();
      case TaxiPaused<DriverOffer>():
        setState(() => _requestsPaused = true);
      default:
        final o = _c.offer(_id);
        if (o != null && o.state != OfferState.ringing && o.state != OfferState.accepted) return _settle();
        setState(() => _actionFailed = true);
    }
  }

  void _onAccept() {
    if (_c.isBusy(DriverRequestAction.accept, _id) || _c.isBusy(DriverRequestAction.decline, _id)) return;
    setState(() => _actionFailed = false);
    unawaited(_accept());
  }

  void _onDecline() {
    if (_c.isBusy(DriverRequestAction.accept, _id) || _c.isBusy(DriverRequestAction.decline, _id)) return;
    setState(() => _actionFailed = false);
    unawaited(_decline());
  }

  @override
  Widget build(BuildContext context) {
    return RingCallPage(onClose: () => unawaited(_close()), child: Obx(_body));
  }

  String _leftForFailed() {
    final at = widget.expiresAt;
    if (at == null) return '';
    final left = RingCountdown.remaining(at, offset: _c.clockOffset.value, now: DateTime.now());
    return left > Duration.zero ? RingCountdown.text(left) : '';
  }

  Widget _opening() =>
      const RingStateView(key: ValueKey('ring_opening'), eyebrow: TaxiWorkStrings.incomingRequest, spinner: true, title: TaxiWorkStrings.opening, sub: TaxiWorkStrings.oneMoment);

  Widget _body() {
    final o = _c.offer(_id);
    if (_requestsPaused) return _endView(RingEnd.paused);
    final pushed = _pushedEnd;
    if (pushed != null) return _endView(pushed);
    if (o == null) {
      if (!_loadFailed) return _opening();
      final left = _leftForFailed();
      return RingStateView(
        key: const ValueKey('ring_failed'),
        eyebrow: TaxiWorkStrings.taxiRequest,
        art: ListingArt.warning,
        title: TaxiWorkStrings.couldNotOpen,
        sub: left.isEmpty ? TaxiWorkStrings.couldNotOpenNoTime : TaxiWorkStrings.stillYours(left),
        primary: TaxiWorkStrings.tryAgain,
        onPrimary: _load,
        secondary: TaxiWorkStrings.close,
        onSecondary: _close,
      );
    }
    if (!_missed && _ringing(o)) return _ring(o);
    if (_answered(o)) {
      if (!_finished) WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
      return _opening();
    }
    if (_closeTimer == null && !_finished) WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
    if (_missed) return _endView(RingEnd.missed);
    return _endView(RingEnd.forOffer(o, paymentOn: PlanGate.paymentOn) ?? RingEnd.missed);
  }

  Widget _endView(RingEnd end) {
    final art = switch (end.kind) {
      RingEndKind.missed || RingEndKind.requestsPaused => ListingArt.alarmClock,
      RingEndKind.pausedOnFree => ListingArt.locked,
      RingEndKind.ended => ListingArt.taxi,
    };
    final paused = end.kind == RingEndKind.pausedOnFree;
    return RingStateView(
      key: ValueKey('ring_end_${end.kind.name}'),
      eyebrow: TaxiWorkStrings.taxiRequest,
      art: art,
      title: end.title,
      sub: end.sub,
      primary: paused ? TaxiWorkStrings.chooseYourRoute : TaxiWorkStrings.close,
      onPrimary: paused ? _chooseRoute : _close,
      secondary: paused ? TaxiWorkStrings.close : null,
      onSecondary: paused ? _close : null,
    );
  }

  Widget _line(String text) => Padding(
        padding: EdgeInsets.only(top: DS.gv(6)),
        child: Text(text, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w400, _onDark, height: 1.5)),
      );

  Widget _ring(DriverOffer o) {
    final busy = _c.isBusy(DriverRequestAction.accept, _id) || _c.isBusy(DriverRequestAction.decline, _id);
    final chips = <String>[
      if (o.sections.pickup) TaxiWorkStrings.pickup,
      if (o.sections.sightseeing) TaxiWorkStrings.sightseeing(o.sightseeingDayCount),
      if (o.sections.drop) TaxiWorkStrings.drop,
    ];
    final column = Padding(
      padding: DS.insets(l: 24, r: 24, t: 40, b: 40),
      child: Column(
        children: [
          Text(TaxiWorkStrings.incomingRequest.toUpperCase(), textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, _onDark.withValues(alpha: Alpha.v80), letterSpacing: 0.6)),
          Gap.v(10),
          Text(TaxiWorkStrings.newTaxiRequest, textAlign: TextAlign.center, style: Ink3D.text(28, FontWeight.w700, _onDark, height: 1.25)),
          Gap.v(14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: DS.gh(8),
            runSpacing: DS.gv(8),
            children: [for (final c in chips) RingChip(c)],
          ),
          _line(DriverRingStrings.summary(o.dayCount, o.nightCount, o.fromDay, o.toDay)),
          if (o.routeLine.isNotEmpty) _line(o.routeLine),
          _line(TaxiWorkStrings.seats(o.seats, o.travellers)),
          Gap.v(44),
          RingCallDial(
            art: _art,
            ticks: _ticks,
            progressOf: () => (_c.remaining(o).inMilliseconds / _ringWindow.inMilliseconds).clamp(0.0, 1.0),
          ),
          Gap.v(34),
          ValueListenableBuilder<int>(
            valueListenable: _ticks,
            builder: (context, _, _) {
              final left = _c.remaining(o);
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
          if (_actionFailed) ...[
            Gap.v(12),
            Text(TaxiWorkStrings.answerFailed, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w600, _onDark, height: 1.4)),
          ],
          const Spacer(),
          RingCallButtons(
            declineLabel: TaxiWorkStrings.decline,
            acceptLabel: TaxiWorkStrings.accept,
            onDecline: busy ? null : _onDecline,
            onAccept: busy ? null : _onAccept,
          ),
          Gap.v(28),
          Text(TaxiWorkStrings.swipeUp, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, _onDark.withValues(alpha: Alpha.high))),
        ],
      ),
    );
    return RingCallLayout(onSwipeUp: busy ? null : _onAccept, child: column);
  }
}
