import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../../design/tokens/intro_story_colors.dart';
import 'intro_story_math.dart';
import 'intro_story_state.dart';

class IntroSkyPainter extends CustomPainter {
  IntroSkyPainter(this.state, this.geo) : super(repaint: state.frame);

  final IntroStoryState state;
  final IntroStoryGeo geo;

  static const double _skyStop = 760 * .62;
  static const double _sunR = 38;
  static const List<List<double>> _clouds = [[20, 56, 120], [170, 96, 150], [250, 40, 100]];
  static final List<Path> _cloudPaths = [for (final c in _clouds) _cloudPath(c[2])];
  static final ui.Gradient _sunFill = ui.Gradient.radial(Offset.zero, _sunR * math.sqrt2, const [IntroStoryColors.sunCore, IntroStoryColors.sunMid, IntroStoryColors.sunEdge], const [0, .55, .72]);
  static final ui.Gradient _moonFill = ui.Gradient.radial(const Offset(-.15 * 76, -.15 * 76), .65 * 76 * math.sqrt2, const [IntroStoryColors.moonCore, IntroStoryColors.moonMid, IntroStoryColors.moonEdge], const [0, .6, 1]);
  static final ui.Gradient _sunGlow = ui.Gradient.radial(Offset.zero, IntroStoryColors.sunGlowRadius, IntroStoryColors.sunGlowColors, IntroStoryColors.sunGlowStops);
  static final ui.Gradient _moonGlow = ui.Gradient.radial(Offset.zero, IntroStoryColors.moonGlowRadius, IntroStoryColors.moonGlowColors, IntroStoryColors.moonGlowStops);
  static final Path _sunHalo = _halo(IntroStoryColors.sunGlowRadius);
  static final Path _moonHalo = _halo(IntroStoryColors.moonGlowRadius);

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _cloud = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
  ui.Gradient? _skyShader;
  Color? _skyT, _skyB;

  static Path _halo(double r) => Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: r))
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: _sunR));

  static Path _cloudPath(double w) => Path()
    ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, w * .1, w * .5, w * .24), Radius.circular(w * .12)))
    ..addOval(Rect.fromLTWH(w * .18, 0, w * .34, w * .3))
    ..addOval(Rect.fromLTWH(w * .4, w * .04, w * .4, w * .3))
    ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .3, w * .12, w * .6, w * .22), Radius.circular(w * .11)));

  @override
  void paint(Canvas canvas, Size size) {
    final pal = state.palette;
    final q = state.q;
    final t = state.time;
    final night = nightOf(q);
    canvas.save();
    canvas.translate(geo.ox, geo.oy);
    canvas.scale(geo.k);
    if (_skyT != pal.t || _skyB != pal.b) {
      _skyT = pal.t;
      _skyB = pal.b;
      _skyShader = ui.Gradient.linear(Offset.zero, const Offset(0, _skyStop), [pal.t, pal.b]);
    }
    _fill
      ..shader = _skyShader
      ..color = IntroStoryColors.white;
    canvas.drawRect(Rect.fromLTRB(geo.vx0, geo.vy0, geo.vx1, IntroStory.sceneH), _fill);
    _fill.shader = null;
    if (night > 0) _stars(canvas, night, t);
    _sun(canvas, q, night);
    _cloudsLayer(canvas, night, t);
    canvas.restore();
  }

  void _stars(Canvas canvas, double night, double t) {
    for (var i = 0; i < 36; i++) {
      final d = 2.0 + i % 3;
      final a = night * (.5 + .5 * math.sin(t * 2 + i));
      _fill.color = IntroStoryColors.white.withValues(alpha: clamp01(a));
      canvas.drawCircle(Offset((i * 97) % 360 + d / 2, (i * 53) % 260 + d / 2), d / 2, _fill);
    }
  }

  void _sun(Canvas canvas, double q, double night) {
    final moon = night > .5;
    canvas.save();
    canvas.translate(sunX(q), sunY(q));
    _fill
      ..color = IntroStoryColors.white
      ..shader = moon ? _moonGlow : _sunGlow;
    canvas.drawPath(moon ? _moonHalo : _sunHalo, _fill);
    _fill.shader = moon ? _moonFill : _sunFill;
    canvas.drawCircle(Offset.zero, _sunR, _fill);
    _fill.shader = null;
    canvas.restore();
  }

  void _cloudsLayer(Canvas canvas, double night, double t) {
    final alpha = clamp01(.9 - night * .8);
    if (alpha <= 0) return;
    final reduce = state.reduce;
    _cloud.color = IntroStoryColors.white.withValues(alpha: alpha);
    for (var i = 0; i < _clouds.length; i++) {
      final c = _clouds[i];
      final drift = reduce ? 0.0 : math.sin(t * .3 + i) * 8;
      canvas.save();
      canvas.translate(c[0] - state.d * (.05 + i * .02) + drift, c[1]);
      canvas.drawPath(_cloudPaths[i], _cloud);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant IntroSkyPainter old) => old.geo != geo || old.state != state;
}

class IntroHillsPainter extends CustomPainter {
  IntroHillsPainter(this.state, this.geo) : super(repaint: state.scroll);

  final IntroStoryState state;
  final IntroStoryGeo geo;

  static const double _period = 720;
  static final Path _far = _hill((x) => 290 - (math.sin(x / _period * math.pi * 2 + 1) * 30 + math.sin(x / _period * math.pi * 6) * 10));
  static final Path _mid = _hill((x) => 336 - (math.sin(x / _period * math.pi * 4 + 2.2) * 24 + math.sin(x / _period * math.pi * 10) * 7));
  static final double _farTop = _far.getBounds().top;
  static final double _midTop = _mid.getBounds().top;
  static final ui.Gradient _haze = ui.Gradient.linear(const Offset(0, 300), const Offset(0, 400), const [IntroStoryColors.clear, IntroStoryColors.white28]);

  final Paint _fill = Paint()..isAntiAlias = true;
  ui.Gradient? _farShader, _midShader;
  Color? _key;

  static Path _hill(double Function(double) f) {
    const n = 2160.0;
    final p = Path()
      ..moveTo(0, IntroStory.sceneH)
      ..lineTo(0, f(0));
    for (var x = 0.0; x <= n; x += 10) {
      p.lineTo(x, f(x));
    }
    return p
      ..lineTo(n, IntroStory.sceneH)
      ..close();
  }

  double _start(double shift) {
    var x = -(shift % _period);
    while (x > geo.vx0) {
      x -= _period;
    }
    return x;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pal = state.palette;
    if (_key != pal.h1 || _farShader == null) {
      _key = pal.h1;
      _farShader = ui.Gradient.linear(Offset(0, _farTop), const Offset(0, IntroStory.sceneH), [pal.h1, pal.h1b]);
      _midShader = ui.Gradient.linear(Offset(0, _midTop), const Offset(0, IntroStory.sceneH), [pal.h2, pal.h2b]);
    }
    final shift = state.d + state.e0 * 220;
    canvas.save();
    canvas.translate(geo.ox, geo.oy);
    canvas.scale(geo.k);
    _fill.color = IntroStoryColors.white;
    _fill.shader = _farShader;
    canvas.save();
    canvas.translate(_start(shift * .2), 0);
    canvas.drawPath(_far, _fill);
    canvas.restore();
    _fill.shader = _midShader;
    canvas.save();
    canvas.translate(_start(shift * .45), 0);
    canvas.drawPath(_mid, _fill);
    canvas.restore();
    _fill.shader = _haze;
    canvas.drawRect(Rect.fromLTRB(geo.vx0, 300, geo.vx1, 400), _fill);
    _fill.shader = null;
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant IntroHillsPainter old) => old.geo != geo || old.state != state;
}
