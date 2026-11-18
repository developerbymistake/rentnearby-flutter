import 'dart:async';
import 'dart:math' as math;

import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../trip/utils/taxi_result.dart';
import 'controllers/driver_requests_controller.dart';
import 'data/driver_request_repository.dart';
import 'models/driver_request_models.dart';
import 'strings/driver_ring_strings.dart';

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
    this.controller,
    this.onAccepted,
    this.onClose,
    this.closeDelay = const Duration(seconds: 3),
  });

  final String offerId;
  final DriverRingAction? action;
  final DriverRequestsController? controller;
  final void Function(String offerId)? onAccepted;
  final VoidCallback? onClose;
  final Duration closeDelay;

  static DriverRingScreen fromArguments(Object? args) {
    final map = args is Map ? args : const {};
    return DriverRingScreen(
      offerId: map['offerId']?.toString() ?? '',
      action: DriverRingAction.parse(map['action']),
    );
  }

  @override
  State<DriverRingScreen> createState() => _DriverRingScreenState();
}

class _DriverRingScreenState extends State<DriverRingScreen> {
  static const Color _top = Color(0xFF14182A);
  static const Color _mid = Color(0xFF2B2F7E);
  static const Color _bottom = Color(0xFF3B3FA8);
  static const Color _onDark = Colors.white;
  static const String _art = 'assets/images/design/travel3d/taxi.png';
  static const Duration _ringWindow = Duration(minutes: 5);

  late final DriverRequestsController _c = widget.controller ?? DriverRequestsController.to;
  Timer? _tick;
  Timer? _closeTimer;
  bool _loadFailed = false;
  bool _actionFailed = false;
  bool _paused = false;
  bool _actionRan = false;
  bool _finished = false;
  bool _missed = false;

  String get _id => widget.offerId;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _closeTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loadFailed = false);
    final listed = _c.loaded.value ? Future<void>.value() : _c.load();
    final r = await _c.loadOffer(_id);
    await listed;
    if (!mounted) return;
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
    if (_answered(o)) return _openDetail();
    if (!_ringing(o)) return _showMissed();
    final a = widget.action;
    if (a != null && !_actionRan) {
      _actionRan = true;
      unawaited(a == DriverRingAction.accept ? _accept() : _decline());
    }
  }

  void _showMissed() {
    if (_closeTimer != null || _finished) return;
    _tick?.cancel();
    _closeTimer = Timer(widget.closeDelay, _close);
    if (mounted) setState(() {});
  }

  void _openDetail() {
    if (_finished) return;
    _finished = true;
    _tick?.cancel();
    final cb = widget.onAccepted;
    if (cb != null) return cb(_id);
    Get.offNamed(AppRoutes.taxiRequestDetail, arguments: {'offerId': _id});
  }

  void _close() {
    if (_finished) return;
    _finished = true;
    _tick?.cancel();
    final cb = widget.onClose;
    if (cb != null) return cb();
    final nav = Get.key.currentState;
    if (nav != null && nav.canPop()) {
      Get.back<void>();
    } else {
      Get.offNamed(AppRoutes.taxiRequests);
    }
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
        openOnOk ? _openDetail() : _close();
      case TaxiOfferMissed<DriverOffer>():
        _missed = true;
        _showMissed();
      default:
        final o = _c.offer(_id);
        if (o != null && o.state != OfferState.ringing && o.state != OfferState.accepted) return _settle();
        setState(() {
          _actionFailed = true;
          _paused = r is TaxiPaused<DriverOffer>;
        });
    }
  }

  void _onAccept() {
    setState(() => _actionFailed = false);
    unawaited(_accept());
  }

  void _onDecline() {
    setState(() => _actionFailed = false);
    unawaited(_decline());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _top,
      body: DecoratedBox(
        position: DecorationPosition.background,
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_top, _mid, _bottom], stops: [0, 0.7, 1]),
        ),
        child: SizedBox.expand(child: SafeArea(child: Obx(_body))),
      ),
    );
  }

  Widget _body() {
    final o = _c.offer(_id);
    if (o == null) {
      return _loadFailed
          ? _message(DriverRingStrings.loadFailedTitle, DriverRingStrings.loadFailedNote, action: DriverRingStrings.retry, onTap: _load)
          : _message(DriverRingStrings.loading, null);
    }
    if (!_missed && _ringing(o)) return _ring(o);
    if (_answered(o)) {
      if (!_finished) WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
      return _message(DriverRingStrings.loading, null);
    }
    if (_closeTimer == null) WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
    return _message(DriverRingStrings.missed, DriverRingStrings.missedNote, action: DriverRingStrings.close, onTap: _close);
  }

  Widget _message(String title, String? note, {String? action, VoidCallback? onTap}) {
    return Center(
      child: SingleChildScrollView(
        padding: DS.sym(h: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Art3D(asset: _art, size: 96),
            Gap.v(20),
            Text(title, textAlign: TextAlign.center, style: Ink3D.text(26, FontWeight.w700, _onDark, height: 1.25)),
            if (note != null) ...[
              Gap.v(8),
              Text(note, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w500, _onDark, height: 1.5)),
            ],
            if (action != null) ...[
              Gap.v(28),
              _PillAction(label: action, onTap: onTap),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(String text) => Padding(
        padding: EdgeInsets.only(top: DS.gv(6)),
        child: Text(text, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w500, _onDark, height: 1.5)),
      );

  Widget _ring(DriverOffer o) {
    final busy = _c.isBusy(DriverRequestAction.accept, _id) || _c.isBusy(DriverRequestAction.decline, _id);
    final chips = <String>[
      if (o.sections.pickup) DriverRingStrings.pickup,
      if (o.sections.sightseeing) DriverRingStrings.sightseeing(o.sightseeingDayCount),
      if (o.sections.drop) DriverRingStrings.drop,
    ];
    final box = DS.s(230);
    final disc = DS.s(180);
    final progress = (_c.remaining(o).inMilliseconds / _ringWindow.inMilliseconds).clamp(0.0, 1.0);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: DS.insets(l: 24, r: 24, t: 40, b: 16),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Text(DriverRingStrings.eyebrow.toUpperCase(), textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w500, _onDark, letterSpacing: 0.6)),
                  Gap.v(10),
                  Text(DriverRingStrings.title, textAlign: TextAlign.center, style: Ink3D.text(28, FontWeight.w700, _onDark, height: 1.25)),
                  Gap.v(14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: DS.gh(8),
                    runSpacing: DS.gv(8),
                    children: [for (final c in chips) _Chip(c)],
                  ),
                  Gap.v(10),
                  _line(DriverRingStrings.summary(o.dayCount, o.nightCount, o.fromDay, o.toDay)),
                  _line(o.routeLine),
                  _line(DriverRingStrings.seats(o.seats, o.travellers)),
                  Gap.v(44),
                  SizedBox(
                    width: box,
                    height: box,
                    child: CustomPaint(
                      key: const ValueKey('ring_progress'),
                      painter: _RingPainter(
                        progress: progress,
                        radius: DS.s(106),
                        stroke: DS.s(8),
                        pulseRadius: DS.s(139),
                        pulseStroke: DS.s(2),
                      ),
                      child: Center(
                        child: Container(
                          width: disc,
                          height: disc,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: Alpha.v14)),
                          alignment: Alignment.center,
                          child: Art3D(asset: _art, size: 120),
                        ),
                      ),
                    ),
                  ),
                  Gap.v(34),
                  Text(_c.countdownText(o), key: const ValueKey('ring_countdown'), style: Ink3D.text(28, FontWeight.w600, _onDark, letterSpacing: 1)),
                  if (_actionFailed) ...[
                    Gap.v(12),
                    Text(_paused ? DriverRingStrings.paused : DriverRingStrings.actionFailed, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w600, _onDark, height: 1.4)),
                  ],
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: DS.insets(l: 24, r: 24, t: 8, b: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Round(label: DriverRingStrings.decline, color: DesignColors.error, icon: Icons.close_rounded, onTap: busy ? null : _onDecline),
              _Round(label: DriverRingStrings.accept, color: DesignColors.success, icon: Icons.call_rounded, onTap: busy ? null : _onAccept),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.radius, required this.stroke, required this.pulseRadius, required this.pulseStroke});

  final double progress;
  final double radius;
  final double stroke;
  final double pulseRadius;
  final double pulseStroke;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
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
    canvas.drawCircle(c, radius, arc..color = Colors.white.withValues(alpha: Alpha.v18));
    if (progress <= 0) return;
    canvas.drawArc(Rect.fromCircle(center: c, radius: radius), -math.pi / 2, 2 * math.pi * progress, false, arc..color = ListingPalette.sunrise.g1);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.radius != radius || old.stroke != stroke || old.pulseRadius != pulseRadius || old.pulseStroke != pulseStroke;
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: Alpha.tint),
        borderRadius: DS.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: Alpha.soft)),
      ),
      child: Padding(
        padding: DS.sym(h: 12, v: 6),
        child: Text(text, style: Ink3D.text(12.5, FontWeight.w600, Colors.white)),
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.label, required this.color, required this.icon, required this.onTap});
  final String label;
  final Color color;
  final IconData icon;
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
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: DS.shadows(Ink3D.whiteBtn)),
              child: Icon(icon, color: Colors.white, size: DS.s(30)),
            ),
            Gap.v(8),
            Text(label, style: Ink3D.text(13, FontWeight.w600, Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tap3D(
      onTap: onTap,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(24), boxShadow: DS.shadows(Ink3D.whiteBtn)),
        child: Padding(
          padding: DS.sym(h: 32, v: 13),
          child: Text(label, style: Ink3D.text(14, FontWeight.w700, Ink3D.title)),
        ),
      ),
    );
  }
}
