import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/design.dart';

abstract final class _T {
  static const farRiseA = 0.0, farRiseB = 0.400;
  static const midRiseA = 0.0533, midRiseB = 0.4533;
  static const nearRiseA = 0.1067, nearRiseB = 0.5067;
  static const dawnA = 0.0667, dawnB = 0.600;
  static const starsA = 0.0667, starsB = 0.400;
  static const sunA = 0.1667, sunB = 0.6667;
  static const stopA = 0.320, stopB = 0.440;
  static const routeA = 0.3733, routeB = 0.6667;
  static const taxiFadeA = 0.640, taxiFadeB = 0.680;
  static const dropA = 0.5467, dropB = 0.6667;
  static const pinAlphaA = 0.5467, pinAlphaB = 0.600;
  static const impact = 0.6667;
  static const squashA = 0.6667, squashB = 0.7467;
  static const ripple1A = 0.6667, ripple1B = 0.9333;
  static const ripple2A = 0.7467, ripple2B = 1.000;
  static const haloA = 0.6667, haloB = 0.8667;
  static const settleA = 0.700, settleB = 0.8667;
}

const Duration _introDuration = Duration(milliseconds: 1500);
const Duration _holdDuration = Duration(milliseconds: 2400);

const List<Offset> _stars = [
  Offset(0.06, 0.07),
  Offset(0.15, 0.15),
  Offset(0.24, 0.05),
  Offset(0.31, 0.24),
  Offset(0.39, 0.10),
  Offset(0.47, 0.18),
  Offset(0.55, 0.04),
  Offset(0.63, 0.13),
  Offset(0.71, 0.27),
  Offset(0.79, 0.08),
  Offset(0.87, 0.19),
  Offset(0.95, 0.11),
  Offset(0.10, 0.30),
  Offset(0.21, 0.34),
  Offset(0.42, 0.31),
  Offset(0.58, 0.33),
  Offset(0.83, 0.32),
  Offset(0.97, 0.26),
];

const List<double> _starRadii = [
  1.2, 1.0, 1.6, 1.1, 1.4, 1.0, 1.3, 1.5, 1.0,
  1.2, 1.6, 1.1, 1.0, 1.4, 1.2, 1.0, 1.5, 1.1,
];

const List<double> _farTop = [0.56, 0.54, 0.555, 0.535, 0.55, 0.535, 0.55, 0.54, 0.56];
const List<double> _midTop = [0.66, 0.65, 0.665, 0.65, 0.66, 0.65, 0.665, 0.655, 0.67];
const List<double> _nearTop = [0.77, 0.76, 0.775, 0.765, 0.77, 0.76, 0.775, 0.77, 0.78];

double _iv(double t, double a, double b, [Curve curve = Curves.linear]) {
  final x = ((t - a) / (b - a)).clamp(0.0, 1.0);
  return curve.transform(x);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

class SplashHero extends StatefulWidget {
  const SplashHero({super.key});

  @override
  State<SplashHero> createState() => _SplashHeroState();
}

class _SplashHeroState extends State<SplashHero> with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _hold;
  late final CurvedAnimation _holdCurve;
  bool _reduceMotion = false;
  bool _started = false;
  bool _hapticDone = false;
  _SplashGeometry? _geo;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: _introDuration);
    _hold = AnimationController(vsync: this, duration: _holdDuration);
    _holdCurve = CurvedAnimation(parent: _hold, curve: Curves.easeInOutSine);
    _intro.addListener(_onIntroTick);
    _intro.addStatusListener(_onIntroStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      if (_reduceMotion) {
        _intro.value = 1.0;
      } else {
        _intro.forward();
      }
    } else if (_reduceMotion && _hold.isAnimating) {
      _hold.stop();
    } else if (!_reduceMotion && _intro.isCompleted && !_hold.isAnimating) {
      _hold.repeat(reverse: true);
    }
  }

  void _onIntroTick() {
    if (_hapticDone || _reduceMotion || _intro.value < _T.impact) return;
    _hapticDone = true;
    HapticFeedback.lightImpact();
  }

  void _onIntroStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && !_reduceMotion) {
      _hold.repeat(reverse: true);
    }
  }

  _SplashGeometry _geoFor(Size size) {
    final cached = _geo;
    if (cached != null && cached.size == size) return cached;
    return _geo = _SplashGeometry(size);
  }

  @override
  void dispose() {
    _intro.removeListener(_onIntroTick);
    _intro.removeStatusListener(_onIntroStatus);
    _holdCurve.dispose();
    _hold.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.biggest.isEmpty || !constraints.biggest.isFinite) {
          return const ColoredBox(color: DesignColors.dinnerEnd);
        }
        final geo = _geoFor(constraints.biggest);
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: DesignColors.dinnerEnd),
            RepaintBoundary(
              child: CustomPaint(painter: _ScenePainter(geo, _intro)),
            ),
            RepaintBoundary(
              child: CustomPaint(
                painter: _PinPainter(geo, _intro, _holdCurve, _reduceMotion),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SplashGeometry {
  _SplashGeometry(this.size) {
    w = size.width;
    h = size.height;
    s = math.min(w, h);
    cx = w / 2;
    u = math.min(w, 0.62 * h);

    markW = (s * 0.22).clamp(64.0, 120.0);
    markH = markW * 1.3;
    markRect = Rect.fromCenter(center: Offset(cx, 0.42 * h), width: markW, height: markH);
    hc = Offset(cx, markRect.top + 0.38 * markH);
    hr = 0.5 * markW;
    tip = Offset(cx, markRect.top + 0.96 * markH);

    farTop = _smooth(_points(_farTop));
    farPath = _closeDown(Path()..addPath(farTop, Offset.zero));

    midPath = _closeDown(_smooth(_points(_midTop)));
    nearPath = _closeDown(_smooth(_points(_nearTop)));
    nearShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color.lerp(DesignColors.dinnerEnd, ListingPalette.indigo.g2, Alpha.v45)!, DesignColors.dinnerEnd],
    ).createShader(Rect.fromLTRB(0, 0.66 * h, w, h));

    final tipY = tip.dy;
    routeStart = Offset(x(0.14), 0.82 * h);
    final route = Path()
      ..moveTo(routeStart.dx, routeStart.dy)
      ..cubicTo(x(0.34), 0.82 * h, x(0.36), 0.72 * h, x(0.20), 0.68 * h)
      ..cubicTo(x(0.04), 0.65 * h, x(0.06), tipY + 0.14 * h, x(0.10), tipY + 0.06 * h)
      ..cubicTo(x(0.12), tipY, x(0.32), tipY, cx, tipY);
    routeMetric = route.computeMetrics().first;
    routeLen = routeMetric.length;

    final phi = math.asin(hr / (tipY - hc.dy));
    final leftTangent = hc + Offset(-hr * math.cos(phi), hr * math.sin(phi));
    pinPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(leftTangent.dx, leftTangent.dy)
      ..arcTo(Rect.fromCircle(center: hc, radius: hr), math.pi - phi, math.pi + 2 * phi, false)
      ..close();
    pinShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [TravelPalette.sunriseStart, TravelPalette.sunriseEnd],
    ).createShader(pinPath.getBounds());

    rr = 0.46 * hr;
  }

  final Size size;
  late final double w, h, s, cx, u;
  late final double markW, markH, hr, rr;
  late final Rect markRect;
  late final Offset hc, tip, routeStart;
  late final Path farTop, farPath, midPath, nearPath;
  late final Path pinPath;
  late final Shader nearShader, pinShader;
  late final PathMetric routeMetric;
  late final double routeLen;

  double x(double f) => cx + (f - 0.5) * u;

  List<Offset> _points(List<double> ys) =>
      [for (var i = 0; i < ys.length; i++) Offset(i / 8 * w, ys[i] * h)];

  Path _smooth(List<Offset> p) {
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    for (var i = 1; i < p.length - 1; i++) {
      final mid = Offset((p[i].dx + p[i + 1].dx) / 2, (p[i].dy + p[i + 1].dy) / 2);
      path.quadraticBezierTo(p[i].dx, p[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(p.last.dx, p.last.dy);
    return path;
  }

  Path _closeDown(Path top) => top
    ..lineTo(w, h + 120)
    ..lineTo(0, h + 120)
    ..close();
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.geo, this.intro) : super(repaint: intro);

  final _SplashGeometry geo;
  final Animation<double> intro;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final Color _farColor =
      Color.lerp(ListingPalette.indigo.g1, ListingPalette.indigo.g2, Alpha.half)!.withValues(alpha: Alpha.v90);

  @override
  void paint(Canvas canvas, Size size) {
    final t = intro.value;
    final g = geo;
    final full = Offset.zero & size;

    final dawn = _iv(t, _T.dawnA, _T.dawnB, Curves.easeInOutSine);
    _fill
      ..color = DesignColors.textInverse
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.40, 0.62],
        colors: [
          DesignColors.dinnerEnd,
          Color.lerp(DesignColors.primary, TravelPalette.sunriseStart, 0.70 * dawn)!,
          Color.lerp(DesignColors.primaryLight, DesignColors.warning, 0.85 * dawn)!,
        ],
      ).createShader(full);
    canvas.drawRect(full, _fill);
    _fill.shader = null;

    final starAlpha = Alpha.strong * (1 - _iv(t, _T.starsA, _T.starsB, Curves.easeIn));
    if (starAlpha > 0) {
      _fill.color = DesignColors.textInverse.withValues(alpha: starAlpha);
      for (var i = 0; i < _stars.length; i++) {
        canvas.drawCircle(Offset(_stars[i].dx * g.w, _stars[i].dy * g.h), _starRadii[i], _fill);
      }
    }

    final sunT = _iv(t, _T.sunA, _T.sunB, Curves.easeOutQuart);
    if (sunT > 0) {
      final c = Offset(g.cx, 0.47 * g.h - 18 * sunT);
      final r = _lerp(0.08 * g.u, 0.60 * g.u, sunT);
      _fill
        ..color = DesignColors.textInverse
        ..shader = RadialGradient(
          stops: const [0.0, 0.45, 1.0],
          colors: [
            TravelPalette.sunriseEnd.withValues(alpha: Alpha.half),
            DesignColors.warning.withValues(alpha: Alpha.soft),
            DesignColors.warning.withValues(alpha: Alpha.none),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, _fill);
      _fill.shader = null;
    }

    final farT = _iv(t, _T.farRiseA, _T.farRiseB, Curves.easeOutCubic);
    canvas.save();
    canvas.translate(0, (1 - farT) * 40);
    _fill.color = _farColor;
    canvas.drawPath(g.farPath, _fill);
    if (dawn > 0) {
      _stroke
        ..strokeWidth = 1
        ..color = TravelPalette.sunriseEnd.withValues(alpha: Alpha.strong * dawn);
      canvas.drawPath(g.farTop, _stroke);
    }
    canvas.restore();

    final midT = _iv(t, _T.midRiseA, _T.midRiseB, Curves.easeOutCubic);
    canvas.save();
    canvas.translate(0, (1 - midT) * 70);
    _fill.color = ListingPalette.indigo.g2;
    canvas.drawPath(g.midPath, _fill);
    canvas.restore();

    final nearT = _iv(t, _T.nearRiseA, _T.nearRiseB, Curves.easeOutCubic);
    canvas.save();
    canvas.translate(0, (1 - nearT) * 110);
    _fill
      ..color = DesignColors.textInverse
      ..shader = g.nearShader;
    canvas.drawPath(g.nearPath, _fill);
    _fill.shader = null;
    canvas.restore();

    final routeT = _iv(t, _T.routeA, _T.routeB, Curves.easeInOutCubic);
    if (routeT > 0) {
      final settle = 1 - 0.4 * _iv(t, _T.settleA, _T.settleB, Curves.easeOut);
      final sub = g.routeMetric.extractPath(0, g.routeLen * routeT);
      _stroke
        ..strokeWidth = 9
        ..color = TravelPalette.sunriseStart.withValues(alpha: Alpha.scrim * settle);
      canvas.drawPath(sub, _stroke);
      _stroke
        ..strokeWidth = 3
        ..color = TravelPalette.sunriseEnd.withValues(alpha: settle);
      canvas.drawPath(sub, _stroke);
    }

    final stopT = _iv(t, _T.stopA, _T.stopB, Curves.easeOutBack);
    if (stopT > 0) {
      canvas.save();
      canvas.translate(g.routeStart.dx, g.routeStart.dy);
      canvas.scale(stopT);
      _fill.color = ListingPalette.indigo.g1;
      canvas.drawCircle(Offset.zero, 5, _fill);
      _stroke
        ..strokeWidth = 2
        ..color = DesignColors.textInverse;
      canvas.drawCircle(Offset.zero, 6, _stroke);
      canvas.restore();
    }

    final taxiA = 1 - _iv(t, _T.taxiFadeA, _T.taxiFadeB);
    if (routeT > 0.02 && taxiA > 0) {
      final tan = g.routeMetric.getTangentForOffset(g.routeLen * routeT);
      if (tan != null) {
        canvas.save();
        canvas.translate(tan.position.dx, tan.position.dy);
        canvas.rotate(-tan.angle);
        final body = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 14, height: 9),
          const Radius.circular(2.5),
        );
        _fill.color = DesignColors.textInverse.withValues(alpha: taxiA);
        canvas.drawRRect(body, _fill);
        _stroke
          ..strokeWidth = 1.5
          ..color = DesignColors.accentTealDeep.withValues(alpha: taxiA);
        canvas.drawRRect(body, _stroke);
        _fill.color = DesignColors.dinnerEnd.withValues(alpha: taxiA);
        canvas.drawCircle(const Offset(-4, 4.5), 1.6, _fill);
        canvas.drawCircle(const Offset(4, 4.5), 1.6, _fill);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) => oldDelegate.geo != geo;
}

class _PinPainter extends CustomPainter {
  _PinPainter(this.geo, this.intro, this.hold, this.reduceMotion)
      : super(repaint: Listenable.merge([intro, hold]));

  final _SplashGeometry geo;
  final Animation<double> intro;
  final Animation<double> hold;
  final bool reduceMotion;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final t = intro.value;
    final g = geo;

    final haloIn = _iv(t, _T.haloA, _T.haloB, Curves.easeOut);
    if (haloIn > 0) {
      final k = reduceMotion ? 0.5 : hold.value;
      final r = g.hr * 1.15 * (1 + 0.25 * k);
      final a = haloIn * _lerp(0.22, 0.42, k);
      _fill
        ..color = DesignColors.textInverse
        ..shader = RadialGradient(
          colors: [
            TravelPalette.sunriseEnd.withValues(alpha: a),
            TravelPalette.sunriseEnd.withValues(alpha: Alpha.none),
          ],
        ).createShader(Rect.fromCircle(center: g.hc, radius: r));
      canvas.drawCircle(g.hc, r, _fill);
      _fill.shader = null;
    }

    final dropT = _iv(t, _T.dropA, _T.dropB, Curves.easeInCubic);
    if (dropT > 0) {
      _fill.color = DesignColors.dinnerEnd.withValues(alpha: Alpha.scrim * dropT);
      canvas.drawOval(
        Rect.fromCenter(center: g.tip, width: 0.6 * g.markW * dropT, height: 0.12 * g.markW),
        _fill,
      );
    }

    _ripple(canvas, _iv(t, _T.ripple1A, _T.ripple1B, Curves.easeOutCubic), 0.3);
    _ripple(canvas, _iv(t, _T.ripple2A, _T.ripple2B, Curves.easeOutCubic), 0.55);

    final pinA = _iv(t, _T.pinAlphaA, _T.pinAlphaB);
    if (pinA <= 0) return;

    final sq = _iv(t, _T.squashA, _T.squashB);
    final sv = math.sin(math.pi * sq) * (1 - sq);
    final sy = 1 - 0.35 * sv;
    final sx = 1 + 0.20 * sv;

    canvas.save();
    canvas.translate(0, -70 * (1 - dropT));
    canvas.translate(g.tip.dx, g.tip.dy);
    canvas.scale(sx, sy);
    canvas.translate(-g.tip.dx, -g.tip.dy);

    _fill
      ..color = DesignColors.textInverse.withValues(alpha: pinA)
      ..shader = g.pinShader;
    canvas.drawPath(g.pinPath, _fill);
    _fill.shader = null;
    _stroke
      ..strokeWidth = 1.5
      ..color = TravelPalette.sunriseStart.withValues(alpha: pinA);
    canvas.drawPath(g.pinPath, _stroke);

    _fill.color = DesignColors.textInverse.withValues(alpha: pinA);
    canvas.drawCircle(g.hc, g.rr, _fill);
    canvas.restore();
  }

  void _ripple(Canvas canvas, double r, double rest) {
    if (r <= 0) return;
    final done = r >= 1;
    final k = done ? rest : r;
    final width = _lerp(0.3, 2.6, k) * geo.markW;
    _stroke
      ..strokeWidth = 2
      ..color = TravelPalette.sunriseEnd.withValues(alpha: done ? Alpha.half * 0.5 : Alpha.half * (1 - r));
    canvas.drawOval(Rect.fromCenter(center: geo.tip, width: width, height: width * 0.35), _stroke);
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) =>
      oldDelegate.geo != geo || oldDelegate.reduceMotion != reduceMotion;
}
