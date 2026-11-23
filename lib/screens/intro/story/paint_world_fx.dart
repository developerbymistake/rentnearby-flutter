import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../../design/tokens/intro_story_colors.dart';
import 'intro_story_art.dart';
import 'intro_story_math.dart';
import 'intro_story_state.dart';
import 'paint_world.dart';

class IntroWorldFxPainter extends CustomPainter {
  IntroWorldFxPainter(this.state, this.geo) : super(repaint: state.frame);

  final IntroStoryState state;
  final IntroStoryGeo geo;

  static const List<IntroRipple> ripples = [
    IntroRipple(356, 16, 30, 18, .6, 2),
    IntroRipple(368, 10, 34, 11, .45, 2),
    IntroRipple(378, 22, 40, 26, .35, 1.6),
  ];
  static const Offset houseAt = Offset(2196, 350);
  static const Offset canoeAt = Offset(2132, 386);
  static const Offset fireGlowAt = Offset(3262, 404);
  static const double fireGlowR = 150, houseGlowR = 48;
  static final ui.Gradient _warm = ui.Gradient.radial(const Offset(37, -34), houseGlowR, const [IntroStoryColors.warmCore, IntroStoryColors.warmEdge]);
  static final ui.Gradient _fire = ui.Gradient.radial(fireGlowAt, fireGlowR, const [IntroStoryColors.fireCore, IntroStoryColors.fireEdge]);

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _glow = Paint()..isAntiAlias = true;
  final Paint _line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _image = Paint()..filterQuality = FilterQuality.medium;

  bool _visible(double x0, double x1, double s) => x1 - s >= geo.vx0 && x0 - s <= geo.vx1;

  @override
  void paint(Canvas canvas, Size size) {
    final s = state.s;
    final river = _visible(IntroRiver.x0, IntroRiver.x1, s);
    final camp = _visible(IntroCamp.lakeX0, fireGlowAt.dx + fireGlowR, s);
    if (!river && !camp) return;
    final t = state.time;
    final q = state.q;
    canvas.save();
    canvas.translate(geo.ox, geo.oy);
    canvas.scale(geo.k);
    canvas.translate(-s, 0);
    if (river) {
      for (final r in ripples) {
        _ripple(canvas, r, t);
      }
      _glint(canvas, const Offset(2060, 362), 28, 4, .25 + .45 * math.sin(t * 2.1));
      _glint(canvas, const Offset(2260, 374), 20, 3.2, .25 + .45 * math.sin(t * 1.7 + 1));
      _house(canvas, q, t);
      _canoe(canvas, t);
    }
    if (camp) {
      _glint(canvas, const Offset(3220, 378), 84, 6, .25 + .35 * math.sin(t * 1.5));
      final on = fireOnOf(q);
      if (on > 0) {
        _glow
          ..shader = _fire
          ..color = IntroStoryColors.white.withValues(alpha: clamp01(.85 * on * (.85 + .15 * math.sin(t * 9))));
        canvas.drawCircle(fireGlowAt, fireGlowR, _glow);
      }
    }
    canvas.restore();
  }

  void _ripple(Canvas canvas, IntroRipple r, double t) {
    final period = r.dash + r.gap;
    _line.strokeWidth = r.width;
    var x = (t * r.speed) % period - period;
    for (; x < IntroRiver.x1 - IntroRiver.x0; x += period) {
      final a = math.max(0.0, x), b = math.min(IntroRiver.x1 - IntroRiver.x0, x + r.dash);
      if (b <= a) continue;
      final e = IntroRiver.edge(IntroRiver.x0 + (a + b) / 2);
      if (e <= 0) continue;
      _line.color = IntroStoryColors.white.withValues(alpha: r.alpha * e);
      canvas.drawLine(Offset(IntroRiver.x0 + a, r.y), Offset(IntroRiver.x0 + b, r.y), _line);
    }
  }

  void _glint(Canvas canvas, Offset c, double w, double h, double alpha) {
    final a = clamp01(alpha);
    if (a <= 0) return;
    _fill.color = IntroStoryColors.white.withValues(alpha: a);
    canvas.drawOval(Rect.fromCenter(center: c, width: w, height: h), _fill);
  }

  void _house(Canvas canvas, double q, double t) {
    final art = state.artIn;
    canvas.save();
    canvas.translate(houseAt.dx, houseAt.dy);
    _fill.color = IntroStoryColors.shadow18.withValues(alpha: IntroStoryColors.shadow18.a * art);
    canvas.drawOval(Rect.fromCenter(center: const Offset(37, 0), width: 68, height: 8), _fill);
    final lamp = lampOf(q) * .7;
    if (lamp > 0) {
      _glow
        ..shader = _warm
        ..color = IntroStoryColors.white.withValues(alpha: lamp);
      canvas.drawCircle(const Offset(37, -34), houseGlowR, _glow);
    }
    final img = IntroStoryArt.instance[IntroArt.house];
    if (img != null && art > 0) _drawImage(canvas, img, const Rect.fromLTWH(0, -74, 74, 74), art);
    final gain = smokeGainOf(q);
    if (gain > 0) {
      for (var i = 0; i < 4; i++) {
        final ph = (t * .35 + i / 4) % 1;
        final a = (1 - ph) * .55 * gain;
        _fill.color = IntroStoryColors.white.withValues(alpha: a);
        canvas.drawCircle(Offset(22 + math.sin(ph * 6 + i) * 4 + ph * 6, -62 - ph * 26), 2.4 + ph * 5, _fill);
      }
    }
    canvas.restore();
  }

  void _canoe(Canvas canvas, double t) {
    final art = state.artIn;
    canvas.save();
    canvas.translate(canoeAt.dx, canoeAt.dy);
    _fill.color = IntroStoryColors.shadow20.withValues(alpha: IntroStoryColors.shadow20.a * art);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 3), width: 56, height: 9), _fill);
    final img = IntroStoryArt.instance[IntroArt.canoe];
    if (img != null && art > 0) {
      canvas.translate(0, math.sin(t * 1.6) * 2.2);
      canvas.rotate(math.sin(t * 1.2) * 3 * math.pi / 180);
      _drawImage(canvas, img, const Rect.fromLTWH(-36, -60, 72, 72), art);
    }
    canvas.restore();
  }

  void _drawImage(Canvas canvas, ui.Image img, Rect dst, double alpha) {
    _image.color = IntroStoryColors.white.withValues(alpha: alpha);
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, _image);
  }

  @override
  bool shouldRepaint(covariant IntroWorldFxPainter old) => old.geo != geo || old.state != state;
}

class IntroRipple {
  const IntroRipple(this.y, this.dash, this.gap, this.speed, this.alpha, this.width);

  final double y, dash, gap, speed, alpha, width;
}
