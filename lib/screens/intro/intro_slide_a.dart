import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../config/app_colors.dart';
import '../../features/trip/trip_colors.dart';
import 'intro_strings.dart';
import 'intro_widgets.dart';

Path introRoutePath(Size canvas) {
  final base = IntroSlideCanvas.size;
  final m = Matrix4.diagonal3Values(canvas.width / base.width, canvas.height / base.height, 1);
  return _RouteGeo.full.transform(m.storage);
}

TextStyle _poppins(double size, FontWeight weight, Color color) =>
    TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: weight, color: color, height: 1.1);

double _seg(double t, double begin, double end, [Curve curve = Curves.linear]) =>
    Interval(begin, math.min(end, 1.0), curve: curve).transform(t.clamp(0.0, 1.0));

abstract class _IntroSlideState<T extends StatefulWidget> extends State<T> with TickerProviderStateMixin {
  late final AnimationController entrance;
  late final AnimationController loop;
  late final AnimationController tap;
  bool reduce = false;
  bool _booted = false;

  Duration get entranceDuration;
  Duration get loopDuration;
  Duration get tapDuration;
  int get pageIndex;
  bool activeOf(T w);
  ValueListenable<double> progressOf(T w);
  void resetInteractions();

  @override
  void initState() {
    super.initState();
    entrance = AnimationController(vsync: this, duration: entranceDuration);
    loop = AnimationController(vsync: this, duration: loopDuration);
    tap = AnimationController(vsync: this, duration: tapDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduce = introReduceMotion(context);
    if (reduce) {
      entrance.value = 1;
      loop.stop();
    }
    if (!_booted) {
      _booted = true;
      if (activeOf(widget)) _start();
    } else if (!reduce && activeOf(widget) && !loop.isAnimating) {
      loop.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = activeOf(oldWidget);
    final now = activeOf(widget);
    if (!was && now) {
      _start();
    } else if (was && !now) {
      _stop();
    }
  }

  void _start() {
    if (reduce) {
      entrance.value = 1;
      loop.stop();
    } else {
      if (entrance.value < 1) entrance.forward(from: 0);
      loop.repeat();
    }
  }

  void _stop() {
    entrance.stop();
    loop.stop();
    tap.stop();
    tap.value = 0;
    resetInteractions();
  }

  void interacted() {
    HapticFeedback.selectionClick();
    const IntroInteractionNotification().dispatch(context);
  }

  Widget parallax(double factor, Widget child) {
    return Positioned.fill(
      child: ValueListenableBuilder<double>(
        valueListenable: progressOf(widget),
        child: child,
        builder: (context, p, child) {
          final offset = (p - pageIndex).clamp(-1.5, 1.5);
          final dx = reduce ? 0.0 : -offset * IntroSlideCanvas.size.width * factor;
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    entrance.dispose();
    loop.dispose();
    tap.dispose();
    super.dispose();
  }
}

class IntroSlidePick extends StatefulWidget {
  const IntroSlidePick({super.key, required this.isActive, required this.progress});

  final bool isActive;
  final ValueListenable<double> progress;

  @override
  State<IntroSlidePick> createState() => _IntroSlidePickState();
}

enum _PickLayer { sun, back, mid, front }

class _PickGeo {
  _PickGeo._();

  static const List<Offset> pins = [Offset(118, 172), Offset(70, 110), Offset(214, 120), Offset(172, 150)];
  static const List<bool> defaults = [true, true, false, true];

  static Path _ridge(List<Offset> pts) {
    final p = Path()..moveTo(0, IntroSlideCanvas.size.height)..lineTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      p.quadraticBezierTo((a.dx + b.dx) / 2, a.dy, b.dx, b.dy);
    }
    return p
      ..lineTo(IntroSlideCanvas.size.width, IntroSlideCanvas.size.height)
      ..close();
  }

  static final Path back = _ridge(const [
    Offset(0, 128), Offset(46, 106), Offset(84, 92), Offset(122, 110), Offset(162, 98),
    Offset(204, 84), Offset(242, 104), Offset(280, 96),
  ]);
  static final Path mid = _ridge(const [
    Offset(0, 150), Offset(36, 132), Offset(72, 122), Offset(110, 140), Offset(150, 124),
    Offset(192, 138), Offset(234, 120), Offset(280, 136),
  ]);
  static final Path front = _ridge(const [
    Offset(0, 170), Offset(50, 154), Offset(96, 166), Offset(140, 150), Offset(186, 164),
    Offset(232, 148), Offset(280, 162),
  ]);
  static final Path snow = Path()
    ..moveTo(190, 93)
    ..quadraticBezierTo(197, 86, 204, 84)
    ..quadraticBezierTo(210, 87, 217, 94);
  static final Rect lake = Rect.fromCenter(center: const Offset(140, 196), width: 150, height: 34);
  static final Path pin = Path()
    ..moveTo(9, 22)
    ..cubicTo(4, 16, 0, 13, 0, 9)
    ..arcToPoint(const Offset(18, 9), radius: const Radius.circular(9))
    ..cubicTo(18, 13, 14, 16, 9, 22)
    ..close();
}

class _PickScenePainter extends CustomPainter {
  _PickScenePainter({required this.layer, required this.entrance, required this.loop})
      : super(repaint: layer == _PickLayer.front ? Listenable.merge([entrance, loop]) : entrance);

  final _PickLayer layer;
  final Animation<double> entrance;
  final Animation<double> loop;

  @override
  void paint(Canvas canvas, Size size) {
    final e = entrance.value;
    final paint = Paint();
    switch (layer) {
      case _PickLayer.sun:
        final a = _seg(e, 0.0, 0.36, Curves.easeOutCubic);
        if (a <= 0) return;
        final c = Offset(196, 64 + 18 * (1 - a));
        paint.color = AppColors.warning.withValues(alpha: 0.18 * a);
        canvas.drawCircle(c, 34, paint);
        paint.color = AppColors.warning.withValues(alpha: 0.9 * a);
        canvas.drawCircle(c, 22, paint);
      case _PickLayer.back:
        final a = _seg(e, 0.0, 0.32, Curves.easeOutCubic);
        if (a <= 0) return;
        canvas.save();
        canvas.translate(0, 24 * (1 - a));
        paint.color = Colors.white.withValues(alpha: 0.14 * a);
        canvas.drawPath(_PickGeo.back, paint);
        canvas.drawPath(
          _PickGeo.snow,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.6 * a),
        );
        canvas.restore();
      case _PickLayer.mid:
        final a = _seg(e, 0.07, 0.39, Curves.easeOutCubic);
        if (a <= 0) return;
        canvas.save();
        canvas.translate(0, 24 * (1 - a));
        paint.color = Colors.white.withValues(alpha: 0.22 * a);
        canvas.drawPath(_PickGeo.mid, paint);
        canvas.restore();
      case _PickLayer.front:
        final a = _seg(e, 0.14, 0.46, Curves.easeOutCubic);
        if (a <= 0) return;
        canvas.save();
        canvas.translate(0, 24 * (1 - a));
        paint.color = Colors.white.withValues(alpha: 0.34 * a);
        canvas.drawPath(_PickGeo.front, paint);
        paint.color = Colors.white.withValues(alpha: 0.18 * a);
        canvas.drawOval(_PickGeo.lake, paint);
        final d = 6 * math.sin(2 * math.pi * loop.value);
        final line = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.4 * a);
        canvas.drawLine(Offset(100 + d, 190), Offset(126 + d, 190), line);
        canvas.drawLine(Offset(150 - d, 203), Offset(168 - d, 203), line);
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PickScenePainter old) =>
      old.layer != layer || old.entrance != entrance || old.loop != loop;
}

class _TeardropPainter extends CustomPainter {
  const _TeardropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_PickGeo.pin, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(9, 9), 3.5, Paint()..color = AppColors.trip);
  }

  @override
  bool shouldRepaint(covariant _TeardropPainter old) => false;
}

class _IntroSlidePickState extends _IntroSlideState<IntroSlidePick> {
  final ValueNotifier<List<bool>> _selected = ValueNotifier<List<bool>>(List<bool>.of(_PickGeo.defaults));
  int _tapIndex = -1;

  static final Animatable<double> _pop = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 60),
  ]);

  @override
  Duration get entranceDuration => const Duration(milliseconds: 1400);
  @override
  Duration get loopDuration => const Duration(milliseconds: 3200);
  @override
  Duration get tapDuration => const Duration(milliseconds: 260);
  @override
  int get pageIndex => 0;
  @override
  bool activeOf(IntroSlidePick w) => w.isActive;
  @override
  ValueListenable<double> progressOf(IntroSlidePick w) => w.progress;

  @override
  void resetInteractions() {
    _selected.value = List<bool>.of(_PickGeo.defaults);
    _tapIndex = -1;
  }

  @override
  void dispose() {
    _selected.dispose();
    super.dispose();
  }

  double _dropRaw(int i) {
    final begin = 0.50 + 0.086 * i;
    return _seg(entrance.value, begin, begin + 0.30);
  }

  bool _landed(int i) => _dropRaw(i) >= 0.37;

  void _toggle(int i) {
    final next = List<bool>.of(_selected.value);
    next[i] = !next[i];
    _selected.value = next;
    _tapIndex = i;
    if (!reduce) tap.forward(from: 0);
    interacted();
  }

  Widget _cityChip() {
    final chip = Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.location, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(IntroStrings.city, maxLines: 1, style: _poppins(11, FontWeight.w700, AppColors.primary)),
        ],
      ),
    );
    return Positioned(
      left: 0,
      right: 0,
      top: 6,
      height: 24,
      child: Center(
        child: AnimatedBuilder(
          animation: entrance,
          child: chip,
          builder: (context, child) {
            final e = entrance.value;
            final s = _seg(e, 0.32, 0.54, Curves.easeOutBack);
            return Opacity(
              opacity: _seg(e, 0.32, 0.42),
              child: Transform.scale(scale: 0.6 + 0.4 * s, child: child),
            );
          },
        ),
      ),
    );
  }

  Widget _counter() {
    return Positioned(
      left: 0,
      right: 0,
      top: 218,
      height: 20,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([entrance, _selected]),
          builder: (context, _) {
            final sel = _selected.value;
            var n = 0;
            for (var i = 0; i < sel.length; i++) {
              if (sel[i] && _landed(i)) n++;
            }
            return Opacity(
              opacity: _seg(entrance.value, 0.40, 0.56),
              child: Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.tick_circle, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(a), child: child),
                      ),
                      child: Text(
                        IntroStrings.spotsPicked(n),
                        key: ValueKey<int>(n),
                        maxLines: 1,
                        style: _poppins(10.5, FontWeight.w700, Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _pin(int i) {
    final at = _PickGeo.pins[i];
    final label = Container(
      height: 14,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7)),
      child: Text(
        IntroStrings.pickSpots[i],
        maxLines: 1,
        softWrap: false,
        style: _poppins(9, FontWeight.w700, AppColors.textDark),
      ),
    );
    const body = SizedBox(width: 18, height: 22, child: CustomPaint(painter: _TeardropPainter()));
    final tick = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: const Icon(Icons.check_rounded, size: 7, color: Colors.white),
    );
    final shadow = Container(
      width: 14,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.all(Radius.elliptical(7, 2)),
      ),
    );

    return Positioned(
      left: at.dx - 40,
      top: at.dy - 34,
      width: 80,
      height: 56,
      child: AnimatedBuilder(
        animation: Listenable.merge([entrance, loop, tap, _selected]),
        builder: (context, _) {
          final raw = _dropRaw(i);
          final drop = Curves.bounceOut.transform(raw);
          final sel = _selected.value[i];
          final pop = _tapIndex == i ? _pop.transform(tap.value) : 1.0;
          final t = loop.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (sel && !reduce && _landed(i)) ...[
                Positioned(left: 31, top: 25, width: 18, height: 18, child: IntroPingRing(phase: t)),
                Positioned(left: 31, top: 25, width: 18, height: 18, child: IntroPingRing(phase: (t + 0.5) % 1)),
              ],
              if (raw > 0) ...[
                Positioned(
                  left: 33,
                  top: 32,
                  width: 14,
                  height: 4,
                  child: Transform.scale(scale: drop.clamp(0.0, 1.0), child: shadow),
                ),
                Positioned(
                  left: 31,
                  top: 12,
                  width: 18,
                  height: 22,
                  child: Opacity(
                    opacity: (raw * 4).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -40 * (1 - drop)),
                      child: Transform.scale(
                        scale: pop,
                        alignment: Alignment.bottomCenter,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            body,
                            if (sel) Positioned(right: -5, top: -3, child: tick),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 37,
                  height: 15,
                  child: Opacity(opacity: raw, child: Center(child: label)),
                ),
              ],
              Positioned(
                left: 18,
                top: 0,
                width: 44,
                height: 44,
                child: Semantics(
                  button: true,
                  selected: sel,
                  label: IntroStrings.pickSpots[i],
                  child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _toggle(i)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = IntroSlideCanvas.size;
    CustomPaint scene(_PickLayer layer) =>
        CustomPaint(size: size, painter: _PickScenePainter(layer: layer, entrance: entrance, loop: loop));

    return MediaQuery.withNoTextScaling(
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            parallax(0.10, scene(_PickLayer.sun)),
            parallax(0.15, scene(_PickLayer.back)),
            parallax(0.30, scene(_PickLayer.mid)),
            parallax(
              0.50,
              Stack(
                clipBehavior: Clip.none,
                children: [Positioned.fill(child: scene(_PickLayer.front)), _counter()],
              ),
            ),
            parallax(
              0.70,
              Stack(
                clipBehavior: Clip.none,
                children: [_cityChip(), for (var i = 0; i < _PickGeo.pins.length; i++) _pin(i)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IntroSlidePlan extends StatefulWidget {
  const IntroSlidePlan({super.key, required this.isActive, required this.progress});

  final bool isActive;
  final ValueListenable<double> progress;

  @override
  State<IntroSlidePlan> createState() => _IntroSlidePlanState();
}

class _RouteGeo {
  _RouteGeo._();

  static const Offset nodeA = Offset(54, 120);
  static const Offset nodeB = Offset(150, 70);
  static const Offset nodeC = Offset(226, 118);
  static const List<Offset> spots = [Offset(40, 134), Offset(54, 139), Offset(68, 134)];
  static final RRect card = RRect.fromRectAndRadius(const Rect.fromLTWH(8, 8, 264, 172), const Radius.circular(18));

  static final Path leg1 = Path()
    ..moveTo(nodeA.dx, nodeA.dy)
    ..cubicTo(80, 84, 116, 62, nodeB.dx, nodeB.dy);
  static final Path leg2 = Path()
    ..moveTo(nodeB.dx, nodeB.dy)
    ..cubicTo(184, 78, 200, 118, nodeC.dx, nodeC.dy);
  static final Path full = Path()
    ..moveTo(nodeA.dx, nodeA.dy)
    ..cubicTo(80, 84, 116, 62, nodeB.dx, nodeB.dy)
    ..cubicTo(184, 78, 200, 118, nodeC.dx, nodeC.dy);
  static final PathMetric m1 = leg1.computeMetrics().first;
  static final PathMetric m2 = leg2.computeMetrics().first;

  static final List<Path> contours = [
    Path()
      ..moveTo(18, 50)
      ..quadraticBezierTo(80, 28, 140, 46)
      ..quadraticBezierTo(200, 62, 262, 38),
    Path()
      ..moveTo(18, 96)
      ..quadraticBezierTo(70, 74, 118, 98)
      ..quadraticBezierTo(180, 126, 262, 88),
    Path()
      ..moveTo(18, 166)
      ..quadraticBezierTo(100, 144, 170, 164)
      ..quadraticBezierTo(220, 176, 262, 150),
  ];

  static Tangent tangentAt(int day, double u) {
    final m = day == 1 ? m1 : m2;
    return m.getTangentForOffset(m.length * u.clamp(0.0, 1.0))!;
  }
}

class _RouteMapPainter extends CustomPainter {
  _RouteMapPainter({
    required this.entrance,
    required this.tap,
    required this.focusDay,
    required this.fadeDay,
    required this.fadeFrac,
  }) : super(repaint: Listenable.merge([entrance, tap, focusDay, fadeDay]));

  final Animation<double> entrance;
  final Animation<double> tap;
  final ValueListenable<int> focusDay;
  final ValueListenable<int> fadeDay;
  final double fadeFrac;

  static final Color _day1 = TripColors.dayColor(1);
  static final Color _day2 = TripColors.dayColor(2);

  Paint _stroke(Color c, double alpha) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = c.withValues(alpha: alpha);

  void _comet(Canvas canvas, Offset at, Color ring) {
    canvas.drawCircle(at, 4.5, Paint()..color = ring);
    canvas.drawCircle(at, 2.5, Paint()..color = Colors.white);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final e = entrance.value;

    final contour = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.divider;
    for (final c in _RouteGeo.contours) {
      canvas.drawPath(c, contour);
    }

    final reveal = _seg(e, 0.14, 0.68, Curves.easeInOutCubic);
    final recolour = _seg(e, 0.68, 0.80);
    final day2Color = Color.lerp(_day1, _day2, recolour)!;

    final dim = fadeDay.value == 0 ? 0.0 : _seg(tap.value, 0, fadeFrac);
    final a1 = fadeDay.value == 2 ? 1 - 0.7 * dim : 1.0;
    final a2 = fadeDay.value == 1 ? 1 - 0.7 * dim : 1.0;

    final l1 = _RouteGeo.m1.length;
    final l2 = _RouteGeo.m2.length;
    final drawn = (l1 + l2) * reveal;
    if (reveal >= 1) {
      canvas.drawPath(_RouteGeo.leg1, _stroke(_day1, a1));
      canvas.drawPath(_RouteGeo.leg2, _stroke(day2Color, a2));
    } else if (drawn > 0) {
      canvas.drawPath(_RouteGeo.m1.extractPath(0, math.min(drawn, l1)), _stroke(_day1, a1));
      if (drawn > l1) canvas.drawPath(_RouteGeo.m2.extractPath(0, drawn - l1), _stroke(day2Color, a2));
      final tip = drawn <= l1
          ? _RouteGeo.m1.getTangentForOffset(drawn)!.position
          : _RouteGeo.m2.getTangentForOffset(drawn - l1)!.position;
      _comet(canvas, tip, _day1);
    }

    final nodesA = _seg(e, 0.10, 0.22);
    if (nodesA > 0) {
      final spot = Paint()..color = AppColors.trip.withValues(alpha: nodesA);
      final spotRing = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: nodesA);
      for (final s in _RouteGeo.spots) {
        canvas.drawCircle(s, 3, spot);
        canvas.drawCircle(s, 3, spotRing);
      }
      final fill = Paint()..color = Colors.white.withValues(alpha: nodesA);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.textDark.withValues(alpha: 0.5 * nodesA);
      for (final n in const [_RouteGeo.nodeA, _RouteGeo.nodeB, _RouteGeo.nodeC]) {
        canvas.drawCircle(n, 7, fill);
        canvas.drawCircle(n, 7, ring);
      }
    }

    final focus = focusDay.value;
    if (focus != 0 && tap.status == AnimationStatus.forward) {
      final u = Curves.easeInOut.transform(tap.value);
      _comet(canvas, _RouteGeo.tangentAt(focus, u).position, TripColors.dayColor(focus));
    }
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter old) =>
      old.entrance != entrance ||
      old.tap != tap ||
      old.focusDay != focusDay ||
      old.fadeDay != fadeDay ||
      old.fadeFrac != fadeFrac;
}

class _IntroSlidePlanState extends _IntroSlideState<IntroSlidePlan> {
  final ValueNotifier<int> _focusDay = ValueNotifier<int>(0);
  final ValueNotifier<int> _fadeDay = ValueNotifier<int>(0);

  static const double _fadeFrac = 200 / 700;
  static const Alignment _cardOrigin = Alignment(0, -0.2167);

  @override
  Duration get entranceDuration => const Duration(milliseconds: 2200);
  @override
  Duration get loopDuration => const Duration(milliseconds: 4000);
  @override
  Duration get tapDuration => const Duration(milliseconds: 700);
  @override
  int get pageIndex => 1;
  @override
  bool activeOf(IntroSlidePlan w) => w.isActive;
  @override
  ValueListenable<double> progressOf(IntroSlidePlan w) => w.progress;

  @override
  void resetInteractions() {
    _focusDay.value = 0;
    _fadeDay.value = 0;
  }

  @override
  void dispose() {
    _focusDay.dispose();
    _fadeDay.dispose();
    super.dispose();
  }

  void _selectDay(int d) {
    interacted();
    if (_focusDay.value == d) {
      _focusDay.value = 0;
      if (reduce) {
        tap.value = 0;
      } else {
        tap.reverse(from: math.min(tap.value, _fadeFrac));
      }
      return;
    }
    _fadeDay.value = d;
    _focusDay.value = d;
    if (reduce) {
      tap.value = 1;
    } else {
      tap.forward(from: 0);
    }
  }

  ({Offset pos, double angle, double scale, double alpha}) _taxiPose(double t) {
    if (reduce) return (pos: _RouteGeo.nodeB, angle: 0.0, scale: 1.0, alpha: 1.0);
    double angleOf(Tangent tg) => math.atan2(tg.vector.dy, tg.vector.dx).clamp(-0.35, 0.35).toDouble();
    final alpha = t < 0.04
        ? t / 0.04
        : t > 0.96
            ? (1 - t) / 0.04
            : 1.0;
    if (t < 0.08) {
      return (pos: _RouteGeo.nodeA, angle: angleOf(_RouteGeo.tangentAt(1, 0)), scale: 1.0, alpha: alpha);
    }
    if (t < 0.46) {
      final tg = _RouteGeo.tangentAt(1, Curves.easeInOutSine.transform((t - 0.08) / 0.38));
      return (pos: tg.position, angle: angleOf(tg), scale: 1.0, alpha: alpha);
    }
    if (t < 0.54) {
      final u = (t - 0.46) / 0.08;
      return (pos: _RouteGeo.nodeB, angle: 0.0, scale: 1 - 0.3 * math.sin(math.pi * u), alpha: alpha);
    }
    if (t < 0.92) {
      final tg = _RouteGeo.tangentAt(2, Curves.easeInOutSine.transform((t - 0.54) / 0.38));
      return (pos: tg.position, angle: angleOf(tg), scale: 1.0, alpha: alpha);
    }
    return (pos: _RouteGeo.nodeC, angle: angleOf(_RouteGeo.tangentAt(2, 1)), scale: 1.0, alpha: alpha);
  }

  Widget _nodeLabel(String text, Offset center) {
    return Positioned(
      left: center.dx - 40,
      top: center.dy - 6.5,
      width: 80,
      height: 13,
      child: Center(
        child: Text(text, maxLines: 1, softWrap: false, style: _poppins(9, FontWeight.w700, AppColors.textMedium)),
      ),
    );
  }

  Widget _labels() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: entrance,
          child: Stack(
            children: [
              _nodeLabel(IntroStrings.nodeA, const Offset(54, 153)),
              _nodeLabel(IntroStrings.nodeB, const Offset(150, 53)),
              _nodeLabel(IntroStrings.nodeC, const Offset(226, 137)),
            ],
          ),
          builder: (context, child) => Opacity(opacity: _seg(entrance.value, 0.10, 0.22), child: child),
        ),
      ),
    );
  }

  Widget _changeCarTag() {
    final tag = Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.taxiSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.taxi.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.car, size: 10, color: AppColors.taxi),
          const SizedBox(width: 3),
          Text(IntroStrings.changeCar, maxLines: 1, style: _poppins(8.5, FontWeight.w700, AppColors.taxiDark)),
        ],
      ),
    );
    return Positioned(
      left: 120,
      top: 106,
      width: 80,
      height: 16,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: entrance,
          child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: tag)),
          builder: (context, child) {
            final e = entrance.value;
            final s = _seg(e, 0.82, 1.0, Curves.easeOutBack);
            return Opacity(
              opacity: _seg(e, 0.82, 0.92),
              child: Transform.scale(scale: 0.4 + 0.6 * s, child: child),
            );
          },
        ),
      ),
    );
  }

  Widget _spark() {
    return Positioned(
      left: _RouteGeo.nodeB.dx - 26,
      top: _RouteGeo.nodeB.dy - 26,
      width: 52,
      height: 52,
      child: AnimatedBuilder(
        animation: entrance,
        builder: (context, _) => IntroSparkBurst(
          t: _seg(entrance.value, 0.68, 0.95),
          count: 6,
          radius: 26,
          colors: [TripColors.dayColor(1), TripColors.dayColor(2)],
        ),
      ),
    );
  }

  Widget _taxiToken() {
    final token = Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.taxi, width: 1),
      ),
      child: const Icon(Iconsax.car, size: 12, color: AppColors.taxi),
    );
    return Positioned(
      left: 0,
      top: 0,
      width: 20,
      height: 20,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: Listenable.merge([entrance, loop]),
          child: token,
          builder: (context, child) {
            final show = _seg(entrance.value, 0.70, 0.82);
            if (show <= 0) return const SizedBox.shrink();
            final pose = _taxiPose(loop.value);
            return Transform.translate(
              offset: pose.pos - const Offset(10, 10),
              child: Opacity(
                opacity: (show * pose.alpha).clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: pose.angle,
                  child: Transform.scale(scale: pose.scale, child: child),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _dayChip(int d) {
    final begin = d == 1 ? 0.70 : 0.75;
    final color = TripColors.dayColor(d);
    return AnimatedBuilder(
      animation: Listenable.merge([entrance, _focusDay]),
      builder: (context, _) {
        final e = entrance.value;
        final rise = _seg(e, begin, begin + 0.16, Curves.easeOutBack);
        final focused = _focusDay.value == d;
        return Opacity(
          opacity: _seg(e, begin, begin + 0.16),
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - rise)),
            child: Semantics(
              button: true,
              selected: focused,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _selectDay(d),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: focused ? color : Colors.white, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Iconsax.calendar_1, size: 11, color: AppColors.textMedium),
                        const SizedBox(width: 4),
                        Text(
                          d == 1 ? IntroStrings.day1 : IntroStrings.day2,
                          maxLines: 1,
                          style: _poppins(10, FontWeight.w700, AppColors.textDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: _RouteGeo.card.outerRect,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _RouteMapPainter(
              entrance: entrance,
              tap: tap,
              focusDay: _focusDay,
              fadeDay: _fadeDay,
              fadeFrac: _fadeFrac,
            ),
          ),
        ),
        _labels(),
        _changeCarTag(),
        _spark(),
        _taxiToken(),
      ],
    );

    return MediaQuery.withNoTextScaling(
      child: SizedBox.fromSize(
        size: IntroSlideCanvas.size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            parallax(
              0.35,
              AnimatedBuilder(
                animation: entrance,
                child: card,
                builder: (context, child) {
                  final v = _seg(entrance.value, 0.0, 0.16, Curves.easeOutCubic);
                  return Opacity(
                    opacity: v,
                    child: Transform.scale(scale: 0.94 + 0.06 * v, alignment: _cardOrigin, child: child),
                  );
                },
              ),
            ),
            parallax(
              0.60,
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 182,
                    height: 36,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [_dayChip(1), const SizedBox(width: 8), _dayChip(2)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
