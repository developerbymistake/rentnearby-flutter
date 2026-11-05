import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_colors.dart';
import '../../features/trip/trip_colors.dart';

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
  static const wordA = 0.6933, wordB = 0.8933;
  static const sweepA = 0.800, sweepB = 1.000;
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

const List<double> _farTop = [0.50, 0.43, 0.47, 0.37, 0.45, 0.38, 0.46, 0.41, 0.49];
const List<double> _midTop = [0.62, 0.57, 0.60, 0.55, 0.59, 0.56, 0.61, 0.58, 0.63];
const List<double> _nearTop = [0.74, 0.70, 0.72, 0.68, 0.71, 0.66, 0.69, 0.67, 0.72];

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
  late final CurvedAnimation _wordFade;
  late final Animation<Offset> _wordSlide;
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
    _wordFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(_T.wordA, _T.wordB, curve: Curves.easeOutCubic),
    );
    _wordSlide = Tween<Offset>(begin: const Offset(0, 14 / 56), end: Offset.zero)
        .animate(_wordFade);
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
    _wordFade.dispose();
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
          return const ColoredBox(color: AppColors.textDark);
        }
        final geo = _geoFor(constraints.biggest);
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.textDark),
            RepaintBoundary(
              child: CustomPaint(painter: _ScenePainter(geo, _intro)),
            ),
            RepaintBoundary(
              child: CustomPaint(
                painter: _PinPainter(geo, _intro, _holdCurve, _reduceMotion),
              ),
            ),
            Positioned.fromRect(
              rect: geo.wordRect,
              child: RepaintBoundary(
                child: _Wordmark(intro: _intro, fade: _wordFade, slide: _wordSlide),
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
    markRect = Rect.fromCenter(center: Offset(cx, 0.40 * h), width: markW, height: markH);
    hc = Offset(cx, markRect.top + 0.38 * markH);
    hr = 0.36 * markW;
    tip = Offset(cx, markRect.top + 0.96 * markH);

    final wordW = math.min(0.70 * w, 280.0);
    wordRect = Rect.fromLTWH(cx - wordW / 2, markRect.bottom + 14, wordW, 56);

    final farPts = _points(_farTop);
    farTop = Path()..moveTo(farPts.first.dx, farPts.first.dy);
    for (var i = 1; i < farPts.length; i++) {
      farTop.lineTo(farPts[i].dx, farPts[i].dy);
    }
    farPath = _closeDown(Path()..addPath(farTop, Offset.zero));

    snowPath = Path();
    for (final i in const [3, 5, 7]) {
      final p = farPts[i];
      snowPath
        ..moveTo(p.dx, p.dy)
        ..lineTo(p.dx + 0.035 * w, p.dy + 0.028 * h)
        ..lineTo(p.dx + 0.012 * w, p.dy + 0.020 * h)
        ..lineTo(p.dx, p.dy + 0.030 * h)
        ..lineTo(p.dx - 0.012 * w, p.dy + 0.020 * h)
        ..lineTo(p.dx - 0.035 * w, p.dy + 0.028 * h)
        ..close();
    }

    midPath = _closeDown(_smooth(_points(_midTop)));
    nearPath = _closeDown(_smooth(_points(_nearTop)));
    nearShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color.lerp(AppColors.textDark, AppColors.primary, 0.30)!, AppColors.textDark],
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
    pinShader = TripColors.gradient.createShader(pinPath.getBounds());

    rr = 0.46 * hr;
    mountainPath = _glyph(const [
      Offset(-0.75, 0.45),
      Offset(-0.25, -0.45),
      Offset(0.05, 0.05),
      Offset(0.30, -0.25),
      Offset(0.75, 0.45),
    ]);
    snowNotchPath = _glyph(const [
      Offset(-0.25, -0.45),
      Offset(-0.38, -0.22),
      Offset(-0.12, -0.22),
    ]);
  }

  final Size size;
  late final double w, h, s, cx, u;
  late final double markW, markH, hr, rr;
  late final Rect markRect, wordRect;
  late final Offset hc, tip, routeStart;
  late final Path farTop, farPath, snowPath, midPath, nearPath;
  late final Path pinPath, mountainPath, snowNotchPath;
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

  Path _glyph(List<Offset> pts) {
    final path = Path()..moveTo(hc.dx + pts.first.dx * rr, hc.dy + pts.first.dy * rr);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(hc.dx + pts[i].dx * rr, hc.dy + pts[i].dy * rr);
    }
    return path..close();
  }
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
      Color.lerp(AppColors.primary, AppColors.primaryLight, 0.35)!.withValues(alpha: 0.9);

  @override
  void paint(Canvas canvas, Size size) {
    final t = intro.value;
    final g = geo;
    final full = Offset.zero & size;

    final dawn = _iv(t, _T.dawnA, _T.dawnB, Curves.easeInOutSine);
    _fill
      ..color = AppColors.textWhite
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.40, 0.62],
        colors: [
          AppColors.textDark,
          Color.lerp(AppColors.primary, AppColors.tripDark, 0.70 * dawn)!,
          Color.lerp(AppColors.primaryLight, AppColors.warning, 0.85 * dawn)!,
        ],
      ).createShader(full);
    canvas.drawRect(full, _fill);
    _fill.shader = null;

    final starAlpha = 0.7 * (1 - _iv(t, _T.starsA, _T.starsB, Curves.easeIn));
    if (starAlpha > 0) {
      _fill.color = AppColors.textWhite.withValues(alpha: starAlpha);
      for (var i = 0; i < _stars.length; i++) {
        canvas.drawCircle(Offset(_stars[i].dx * g.w, _stars[i].dy * g.h), _starRadii[i], _fill);
      }
    }

    final sunT = _iv(t, _T.sunA, _T.sunB, Curves.easeOutQuart);
    if (sunT > 0) {
      final c = Offset(g.cx, 0.47 * g.h - 18 * sunT);
      final r = _lerp(0.08 * g.u, 0.60 * g.u, sunT);
      _fill
        ..color = AppColors.textWhite
        ..shader = RadialGradient(
          stops: const [0.0, 0.45, 1.0],
          colors: [
            AppColors.tripLight.withValues(alpha: 0.55),
            AppColors.warning.withValues(alpha: 0.22),
            AppColors.warning.withValues(alpha: 0),
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
    _fill.color = AppColors.textWhite.withValues(alpha: 0.85);
    canvas.drawPath(g.snowPath, _fill);
    if (dawn > 0) {
      _stroke
        ..strokeWidth = 1
        ..color = AppColors.tripLight.withValues(alpha: 0.6 * dawn);
      canvas.drawPath(g.farTop, _stroke);
    }
    canvas.restore();

    final midT = _iv(t, _T.midRiseA, _T.midRiseB, Curves.easeOutCubic);
    canvas.save();
    canvas.translate(0, (1 - midT) * 70);
    _fill.color = AppColors.primary;
    canvas.drawPath(g.midPath, _fill);
    canvas.restore();

    final nearT = _iv(t, _T.nearRiseA, _T.nearRiseB, Curves.easeOutCubic);
    canvas.save();
    canvas.translate(0, (1 - nearT) * 110);
    _fill
      ..color = AppColors.textWhite
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
        ..color = AppColors.trip.withValues(alpha: 0.28 * settle);
      canvas.drawPath(sub, _stroke);
      _stroke
        ..strokeWidth = 3
        ..color = AppColors.tripLight.withValues(alpha: settle);
      canvas.drawPath(sub, _stroke);
    }

    final stopT = _iv(t, _T.stopA, _T.stopB, Curves.easeOutBack);
    if (stopT > 0) {
      canvas.save();
      canvas.translate(g.routeStart.dx, g.routeStart.dy);
      canvas.scale(stopT);
      _fill.color = AppColors.accentLight;
      canvas.drawCircle(Offset.zero, 5, _fill);
      _stroke
        ..strokeWidth = 2
        ..color = AppColors.textWhite;
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
        _fill.color = AppColors.textWhite.withValues(alpha: taxiA);
        canvas.drawRRect(body, _fill);
        _stroke
          ..strokeWidth = 1.5
          ..color = AppColors.taxi.withValues(alpha: taxiA);
        canvas.drawRRect(body, _stroke);
        _fill.color = AppColors.textDark.withValues(alpha: taxiA);
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
      final r = g.hr * 1.6 * (1 + 0.25 * k);
      final a = haloIn * _lerp(0.22, 0.42, k);
      _fill
        ..color = AppColors.textWhite
        ..shader = RadialGradient(
          colors: [
            AppColors.tripLight.withValues(alpha: a),
            AppColors.tripLight.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: g.hc, radius: r));
      canvas.drawCircle(g.hc, r, _fill);
      _fill.shader = null;
    }

    final dropT = _iv(t, _T.dropA, _T.dropB, Curves.easeInCubic);
    if (dropT > 0) {
      _fill.color = AppColors.textDark.withValues(alpha: 0.35 * dropT);
      canvas.drawOval(
        Rect.fromCenter(center: g.tip, width: 0.6 * g.markW * dropT, height: 0.12 * g.markW),
        _fill,
      );
    }

    _ripple(canvas, _iv(t, _T.ripple1A, _T.ripple1B, Curves.easeOutCubic));
    _ripple(canvas, _iv(t, _T.ripple2A, _T.ripple2B, Curves.easeOutCubic));

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
      ..color = AppColors.textWhite.withValues(alpha: pinA)
      ..shader = g.pinShader;
    canvas.drawPath(g.pinPath, _fill);
    _fill.shader = null;
    _stroke
      ..strokeWidth = 1.5
      ..color = TripColors.accentDark.withValues(alpha: pinA);
    canvas.drawPath(g.pinPath, _stroke);

    _fill.color = AppColors.textWhite.withValues(alpha: pinA);
    canvas.drawCircle(g.hc, g.rr, _fill);
    _fill.color = AppColors.primary.withValues(alpha: pinA);
    canvas.drawPath(g.mountainPath, _fill);
    _fill.color = AppColors.textWhite.withValues(alpha: pinA);
    canvas.drawPath(g.snowNotchPath, _fill);
    canvas.restore();
  }

  void _ripple(Canvas canvas, double r) {
    if (r <= 0 || r >= 1) return;
    final width = _lerp(0.3, 2.6, r) * geo.markW;
    _stroke
      ..strokeWidth = 2
      ..color = AppColors.tripLight.withValues(alpha: 0.5 * (1 - r));
    canvas.drawOval(Rect.fromCenter(center: geo.tip, width: width, height: width * 0.35), _stroke);
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) =>
      oldDelegate.geo != geo || oldDelegate.reduceMotion != reduceMotion;
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.intro, required this.fade, required this.slide});

  final Animation<double> intro;
  final Animation<double> fade;
  final Animation<Offset> slide;

  static final Color _glint = Color.lerp(AppColors.textWhite, AppColors.tripLight, 0.55)!;

  @override
  Widget build(BuildContext context) {
    final text = Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'Bakhli',
          maxLines: 1,
          textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 34,
            letterSpacing: 0.6,
            height: 1.2,
            color: AppColors.textWhite,
          ),
        ),
      ),
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: AnimatedBuilder(
          animation: intro,
          child: text,
          builder: (_, child) {
            final v = intro.value;
            if (v <= _T.sweepA || v >= 1.0) return child!;
            final p = _lerp(-0.3, 1.3, _iv(v, _T.sweepA, _T.sweepB, Curves.easeInOutSine));
            return ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                colors: [AppColors.textWhite, _glint, AppColors.textWhite],
                stops: [
                  (p - 0.18).clamp(0.0, 1.0),
                  p.clamp(0.0, 1.0),
                  (p + 0.18).clamp(0.0, 1.0),
                ],
              ).createShader(bounds),
              child: child,
            );
          },
        ),
      ),
    );
  }
}
