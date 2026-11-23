import 'dart:async';
import 'dart:math' as math;

import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../services/system_settings_channel.dart';
import '../../../services/taxi_ring_service.dart';
import '../../../services/taxi_ring_session.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../taxi_driver/strings/taxi_work_strings.dart';
import '../../taxi_driver/taxi_driver_deps.dart';
import '../../trip/utils/taxi_result.dart';
import 'controllers/driver_requests_controller.dart';
import 'data/driver_request_repository.dart';
import 'models/driver_request_models.dart';
import 'models/ring_end.dart';
import 'strings/driver_ring_strings.dart';
import 'utils/taxi_countdown.dart';

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
  static const Color _acceptGreen = Color(0xFF2EA84F);
  static const Color _onDark = Colors.white;
  static const String _art = 'assets/images/design/travel3d/taxi.png';
  static const Duration _ringWindow = Duration(minutes: 5);
  static final Color _top = Color.lerp(ListingPalette.sunrise.g2, ListingPalette.coral.g1, 0.55)!;
  static final Color _mid = Color.lerp(ListingPalette.coral.g1, ListingPalette.coral.g2, 0.35)!;
  static final Color _bottom = ListingPalette.coral.g2;

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

  void _onRouteAnimation(AnimationStatus status) {
    if (status == AnimationStatus.completed) _claim();
  }

  void _hold() {
    final o = _c.offer(_id);
    final at = widget.expiresAt;
    final left = o != null
        ? _c.remaining(o)
        : at != null
            ? TaxiCountdown.remaining(at, offset: _c.clockOffset.value, now: DateTime.now())
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        backgroundColor: _bottom,
        body: DecoratedBox(
          position: DecorationPosition.background,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_top, _mid, _bottom], stops: const [0, 0.55, 1]),
          ),
          child: SizedBox.expand(child: SafeArea(child: Obx(_body))),
        ),
      ),
    );
  }

  String _leftForFailed() {
    final at = widget.expiresAt;
    if (at == null) return '';
    final left = TaxiCountdown.remaining(at, offset: _c.clockOffset.value, now: DateTime.now());
    return left > Duration.zero ? TaxiCountdown.text(left) : '';
  }

  Widget _opening() =>
      const _RingStateView(key: ValueKey('ring_opening'), eyebrow: TaxiWorkStrings.incomingRequest, spinner: true, title: TaxiWorkStrings.opening, sub: TaxiWorkStrings.oneMoment);

  Widget _body() {
    final o = _c.offer(_id);
    if (_requestsPaused) return _endView(RingEnd.paused);
    final pushed = _pushedEnd;
    if (pushed != null) return _endView(pushed);
    if (o == null) {
      if (!_loadFailed) return _opening();
      final left = _leftForFailed();
      return _RingStateView(
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
    return _RingStateView(
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
    final box = DS.s(230);
    final disc = DS.s(180);
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
            children: [for (final c in chips) _Chip(c)],
          ),
          _line(DriverRingStrings.summary(o.dayCount, o.nightCount, o.fromDay, o.toDay)),
          if (o.routeLine.isNotEmpty) _line(o.routeLine),
          _line(TaxiWorkStrings.seats(o.seats, o.travellers)),
          Gap.v(44),
          SizedBox(
            width: box,
            height: box,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const ValueKey('ring_progress'),
                      painter: _RingPainter(
                        progressOf: () => (_c.remaining(o).inMilliseconds / _ringWindow.inMilliseconds).clamp(0.0, 1.0),
                        repaint: _ticks,
                        radius: DS.s(92),
                        stroke: DS.s(8),
                        pulseRadius: DS.s(139),
                        pulseStroke: DS.s(2),
                        ringShift: DS.s(15),
                      ),
                    ),
                  ),
                ),
                RepaintBoundary(
                  child: Container(
                    width: disc,
                    height: disc,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: Alpha.v14)),
                    alignment: Alignment.center,
                    child: Art3D(asset: _art, size: 120, shadowOffset: const Offset(6, 9), shadowBlur: 8, shadowAlpha: Alpha.scrim),
                  ),
                ),
              ],
            ),
          ),
          Gap.v(34),
          ValueListenableBuilder<int>(
            valueListenable: _ticks,
            builder: (context, _, _) {
              final left = _c.remaining(o);
              final spoken = TaxiCountdown.text(Duration(seconds: ((left.inSeconds + 9) ~/ 10) * 10));
              return Semantics(
                liveRegion: true,
                label: spoken,
                child: ExcludeSemantics(
                  child: Text(TaxiCountdown.text(left), key: const ValueKey('ring_countdown'), style: Ink3D.text(28, FontWeight.w600, _onDark, letterSpacing: 1)),
                ),
              );
            },
          ),
          if (_actionFailed) ...[
            Gap.v(12),
            Text(TaxiWorkStrings.answerFailed, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w600, _onDark, height: 1.4)),
          ],
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Round(label: TaxiWorkStrings.decline, color: DesignColors.error, glyph: const _DeclineX(), onTap: busy ? null : _onDecline),
              Gap.h(90),
              _Round(label: TaxiWorkStrings.accept, color: _acceptGreen, glyph: Icon(Icons.call, color: Colors.white, size: DS.s(30)), onTap: busy ? null : _onAccept),
            ],
          ),
          Gap.v(28),
          Text(TaxiWorkStrings.swipeUp, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, _onDark.withValues(alpha: Alpha.high))),
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: busy
          ? null
          : (d) {
              if ((d.primaryVelocity ?? 0) < -300) _onAccept();
            },
      child: LayoutBuilder(
        builder: (context, c) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: c.maxWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: IntrinsicHeight(child: column),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingStateView extends StatelessWidget {
  static const double _pillFont = 13;

  const _RingStateView({
    super.key,
    required this.eyebrow,
    this.art,
    this.spinner = false,
    required this.title,
    required this.sub,
    this.primary,
    this.onPrimary,
    this.secondary,
    this.onSecondary,
  });

  final String eyebrow;
  final String? art;
  final bool spinner;
  final String title;
  final String sub;
  final String? primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final a = art;
    final disc = DS.s(112);
    final p = primary;
    final s = secondary;
    return Padding(
      padding: DS.insets(l: 18, r: 18, t: 40, b: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(eyebrow.toUpperCase(), textAlign: TextAlign.center, style: Ink3D.text(11, FontWeight.w500, Colors.white.withValues(alpha: Alpha.v80), letterSpacing: 0.6)),
                  Gap.v(36),
                  if (spinner)
                    SizedBox(
                      width: DS.s(88),
                      height: DS.s(88),
                      child: CircularProgressIndicator(
                        key: const ValueKey('ring_opening_spinner'),
                        strokeWidth: DS.s(4),
                        color: ListingPalette.sunrise.g1,
                        backgroundColor: Colors.white.withValues(alpha: Alpha.v18),
                      ),
                    )
                  else if (a != null)
                    Container(
                      width: disc,
                      height: disc,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: Alpha.v14)),
                      child: Art3D(asset: a, size: 72, shadowAlpha: Alpha.scrim),
                    ),
                  Gap.v(24),
                  Text(title, key: const ValueKey('ring_state_title'), textAlign: TextAlign.center, style: Ink3D.text(18, FontWeight.w700, Colors.white, height: 1.3)),
                  Gap.v(8),
                  Text(sub, key: const ValueKey('ring_state_sub'), textAlign: TextAlign.center, style: Ink3D.text(11.5, FontWeight.w500, Colors.white, height: 1.5)),
                ],
              ),
            ),
          ),
          if (p != null) GradientPillButton(key: const ValueKey('ring_state_primary'), tone: ListingTone.coral, label: p, onTap: onPrimary, height: 44, fontSize: _pillFont),
          if (s != null) ...[
            Gap.v(10),
            WhitePillButton(key: const ValueKey('ring_state_secondary'), tone: ListingTone.coral, label: s, onTap: onSecondary, height: 44, fontSize: _pillFont),
          ],
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progressOf,
    required Listenable repaint,
    required this.radius,
    required this.stroke,
    required this.pulseRadius,
    required this.pulseStroke,
    required this.ringShift,
  }) : super(repaint: repaint);

  final double Function() progressOf;
  final double radius;
  final double stroke;
  final double pulseRadius;
  final double pulseStroke;
  final double ringShift;

  double get progress => progressOf();

  @override
  void paint(Canvas canvas, Size size) {
    final progress = this.progress;
    final c = size.center(Offset.zero);
    final rc = c - Offset(ringShift, ringShift);
    canvas.drawCircle(
      c,
      pulseRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = pulseStroke
        ..color = Colors.white.withValues(alpha: Alpha.v22),
    );
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(rc, radius, arc..color = Colors.white.withValues(alpha: Alpha.v18));
    if (progress <= 0) return;
    canvas.drawArc(Rect.fromCircle(center: rc, radius: radius), -math.pi / 2, 2 * math.pi * progress, false, arc..color = ListingPalette.sunrise.g1);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progressOf != progressOf || old.radius != radius || old.stroke != stroke || old.pulseRadius != pulseRadius || old.pulseStroke != pulseStroke || old.ringShift != ringShift;
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: Alpha.v16),
        borderRadius: DS.circular(14),
      ),
      child: Padding(
        padding: DS.sym(h: 14, v: 6),
        child: Text(text, style: Ink3D.text(12.5, FontWeight.w600, Colors.white)),
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.label, required this.color, required this.glyph, required this.onTap});
  static const List<BoxShadow> _shadow = [BoxShadow(color: Color(0x59000000), offset: Offset(0, 8), blurRadius: 18)];
  final String label;
  final Color color;
  final Widget glyph;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = DS.s(76);
    return Tap3D(
      onTap: onTap,
      label: label,
      exclude: true,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: DS.shadows(_shadow)),
              alignment: Alignment.center,
              child: glyph,
            ),
            Gap.v(10),
            Text(label, style: Ink3D.text(13, FontWeight.w600, Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _DeclineX extends StatelessWidget {
  const _DeclineX();

  @override
  Widget build(BuildContext context) {
    final side = DS.s(30);
    return CustomPaint(key: const ValueKey('ring_decline_x'), size: Size.square(side), painter: _XPainter());
  }
}

class _XPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 3 / 24
      ..strokeCap = StrokeCap.round;
    final a = size.width * 0.25;
    final b = size.width * 0.75;
    canvas.drawLine(Offset(a, a), Offset(b, b), p);
    canvas.drawLine(Offset(b, a), Offset(a, b), p);
  }

  @override
  bool shouldRepaint(_XPainter old) => false;
}
