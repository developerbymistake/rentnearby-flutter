import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../../design/tokens/intro_story_colors.dart';
import 'intro_story_art.dart';
import 'intro_story_math.dart';
import 'intro_story_state.dart';

class IntroWorldPainter extends CustomPainter {
  IntroWorldPainter(this.state, this.geo) : super(repaint: state.scroll);

  final IntroStoryState state;
  final IntroStoryGeo geo;

  static const Offset signAt = Offset(338, 428);

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _image = Paint()..filterQuality = FilterQuality.medium;

  bool _visible(double x0, double x1, double s) => x1 - s >= geo.vx0 && x0 - s <= geo.vx1;

  @override
  void paint(Canvas canvas, Size size) {
    final s = state.s;
    canvas.save();
    canvas.translate(geo.ox, geo.oy);
    canvas.scale(geo.k);
    canvas.translate(-s, 0);
    if (_visible(signAt.dx - 20, signAt.dx + 20, s)) _sign(canvas);
    if (_visible(IntroMountain.x0, IntroMountain.x1, s)) IntroMountain.paint(canvas, state, _fill);
    if (_visible(IntroRiver.x0, IntroRiver.x1, s)) canvas.drawPicture(IntroRiver.picture);
    if (_visible(IntroCamp.lakeX0, IntroCamp.grassX1, s)) _camp(canvas);
    canvas.restore();
  }

  Color? _grassG;
  ui.Gradient? _grassShader;

  void _camp(Canvas canvas) {
    _fill.color = IntroStoryColors.lake;
    canvas.drawOval(IntroCamp.lake, _fill);
    final g = state.palette.g;
    if (_grassG != g) {
      _grassG = g;
      _grassShader = ui.Gradient.linear(
        const Offset(IntroCamp.grassX0, 0),
        const Offset(IntroCamp.grassX1, 0),
        [g.withValues(alpha: IntroCamp.none), g, g],
        IntroCamp.grassStops,
      );
    }
    _fill
      ..shader = _grassShader
      ..color = IntroStoryColors.white;
    canvas.drawRect(IntroCamp.grass, _fill);
    _fill.shader = null;
    canvas.save();
    canvas.translate(IntroCamp.tentAt.dx, IntroCamp.tentAt.dy);
    final a = state.artIn;
    _fill.color = IntroStoryColors.shadow20.withValues(alpha: IntroStoryColors.shadow20.a * a);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 92, height: 10), _fill);
    final img = IntroStoryArt.instance[IntroArt.camping];
    if (img != null && a > 0) _drawImage(canvas, img, const Rect.fromLTWH(-46, -88, 92, 92), a);
    canvas.restore();
  }

  void _sign(Canvas canvas) {
    canvas.save();
    canvas.translate(signAt.dx, signAt.dy);
    _fill.color = IntroStoryColors.shadow25;
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 28, height: 7), _fill);
    _fill.color = IntroStoryColors.signPole;
    canvas.drawRRect(RRect.fromLTRBR(-2.5, -64, 2.5, 0, const Radius.circular(2.5)), _fill);
    _fill.color = IntroStoryColors.signBoard;
    canvas.drawRRect(RRect.fromLTRBR(-19, -92, 19, -62, const Radius.circular(9)), _fill);
    _fill.color = IntroStoryColors.white35;
    canvas.drawRRect(RRect.fromLTRBR(-19, -92, 19, -80, const Radius.circular(9)), _fill);
    final img = IntroStoryArt.instance[IntroArt.taxi];
    final a = state.artIn;
    if (img != null && a > 0) _drawImage(canvas, img, const Rect.fromLTWH(-15, -90, 30, 30), a);
    canvas.restore();
  }

  void _drawImage(Canvas canvas, ui.Image img, Rect dst, double alpha) {
    _image.color = IntroStoryColors.white.withValues(alpha: alpha);
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, _image);
  }

  @override
  bool shouldRepaint(covariant IntroWorldPainter old) => old.geo != geo || old.state != state;
}

abstract final class IntroRiver {
  static const double x0 = 1780, x1 = 2420, top = 344, bottom = 390;
  static const List<double> edgeStops = [0, .12, .88, 1];

  static double edge(double x) {
    final u = (x - x0) / (x1 - x0);
    if (u <= 0 || u >= 1) return 0;
    if (u < .12) return u / .12;
    if (u > .88) return (1 - u) / .12;
    return 1;
  }

  static ui.Picture? _picture;

  static ui.Picture get picture => _picture ??= _record();

  static ui.Gradient _fade(Color c) {
    final none = c.withValues(alpha: IntroCamp.none);
    return ui.Gradient.linear(const Offset(x0, 0), const Offset(x1, 0), [none, c, c, none], edgeStops);
  }

  static ui.Picture _record() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final p = Paint()..isAntiAlias = false;
    const rows = bottom - top;
    for (var y = top; y < bottom; y++) {
      p.shader = _fade(Color.lerp(IntroStoryColors.riverTop, IntroStoryColors.riverBottom, (y + .5 - top) / rows)!);
      c.drawRect(Rect.fromLTRB(x0, y, x1, y + 1), p);
    }
    p.shader = _fade(IntroStoryColors.riverBank);
    c.drawRect(const Rect.fromLTRB(x0, 340, x1, 346), p);
    p.shader = _fade(IntroStoryColors.riverShade);
    c.drawRect(const Rect.fromLTRB(x0, 384, x1, bottom), p);
    return rec.endRecording();
  }
}

abstract final class IntroCamp {
  static const double none = 0;
  static const double lakeX0 = 3102, grassX0 = 3170, grassX1 = 3970;
  static const List<double> grassStops = [0, .08, 1];
  static const Rect lake = Rect.fromLTRB(3102, 362, 3402, 394);
  static const Rect grass = Rect.fromLTRB(grassX0, 390, grassX1, 490);
  static const Offset tentAt = Offset(3340, 394);
}

abstract final class IntroMountain {
  static const double cx = 1200, base = 396;
  static const double x0 = cx - 180, x1 = cx + 180;
  static const double tintAlpha = .2, nightAlpha = .55;
  static const double dotStep = 7, dotLength = 1;
  static const List<Offset> pines = [
    Offset(-120, -12), Offset(-104, -20), Offset(-88, -12), Offset(-76, -24), Offset(-60, -10), Offset(-40, -14), Offset(-120, -4),
    Offset(60, -14), Offset(76, -8), Offset(96, -16), Offset(112, -8), Offset(128, -14), Offset(142, -6), Offset(48, -8),
  ];

  static final Path outline = Path()
    ..addPolygon(const [
      Offset(-170, 0), Offset(-132, -32), Offset(-100, -72), Offset(-66, -104), Offset(-34, -150), Offset(-12, -164), Offset(2, -192),
      Offset(24, -168), Offset(42, -142), Offset(70, -118), Offset(98, -88), Offset(128, -54), Offset(170, 0),
    ], true);

  static ui.Picture? _body;
  static ui.Picture? _front;

  static void paint(Canvas canvas, IntroStoryState state, Paint fill) {
    canvas.save();
    canvas.translate(cx, base);
    canvas.drawPicture(_body ??= _recordBody());
    fill.color = state.palette.b.withValues(alpha: tintAlpha);
    canvas.drawPath(outline, fill);
    final dark = nightOf(state.q) * nightAlpha;
    if (dark > 0) {
      fill.color = IntroStoryColors.mountainNight.withValues(alpha: dark);
      canvas.drawPath(outline, fill);
    }
    canvas.restore();
    canvas.drawPicture(_front ??= _recordFront());
  }

  static ui.Picture _recordBody() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final p = Paint()..isAntiAlias = true;
    c.save();
    c.clipPath(outline);
    p.shader = ui.Gradient.linear(const Offset(0, -192), Offset.zero, const [IntroStoryColors.mountainLitTop, IntroStoryColors.mountainLitBottom]);
    c.drawPath(outline, p);
    p.shader = ui.Gradient.linear(const Offset(0, -192), Offset.zero, const [IntroStoryColors.mountainShadeTop, IntroStoryColors.mountainShadeBottom]);
    c.drawPath(
      Path()
        ..addPolygon(const [
          Offset(2, -192), Offset(24, -168), Offset(42, -142), Offset(70, -118), Offset(98, -88), Offset(128, -54), Offset(170, 0),
          Offset(36, 0), Offset(24, -52), Offset(36, -86), Offset(14, -116), Offset(20, -150),
        ], true),
      p,
    );
    p.shader = null;
    final ridge = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;
    ridge
      ..color = IntroStoryColors.mountainRidge35
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    c.drawPath(
      Path()
        ..addPolygon(const [
          Offset(-34, -150), Offset(-18, -128), Offset(-34, -104), Offset(-20, -80), Offset(-44, -52), Offset(-30, -30), Offset(-60, -12), Offset(-70, 0),
        ], false),
      ridge,
    );
    ridge
      ..color = IntroStoryColors.mountainRidge25
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.butt;
    c.drawPath(Path()..addPolygon(const [Offset(-100, -72), Offset(-70, -74), Offset(-62, -50)], false), ridge);
    p.color = IntroStoryColors.white;
    c.drawPath(
      Path()
        ..addPolygon(const [
          Offset(-20, -166), Offset(-12, -164), Offset(2, -192), Offset(24, -168), Offset(16, -160), Offset(10, -170), Offset(2, -158), Offset(-4, -170),
        ], true),
      p,
    );
    p.color = IntroStoryColors.snowShade;
    c.drawPath(Path()..addPolygon(const [Offset(2, -192), Offset(24, -168), Offset(16, -160), Offset(10, -170), Offset(6, -176)], true), p);
    p.color = IntroStoryColors.pine;
    final pineP = Path();
    for (final o in pines) {
      pineP.addPolygon([o, o.translate(-5, 12), o.translate(5, 12)], true);
    }
    c.drawPath(pineP, p);
    p.shader = ui.Gradient.linear(const Offset(0, -60), const Offset(0, 2), const [IntroStoryColors.clear, IntroStoryColors.white62]);
    c.drawRect(const Rect.fromLTWH(-180, -60, 360, 62), p);
    c.restore();
    return rec.endRecording();
  }

  static ui.Picture _recordFront() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final p = Paint()..isAntiAlias = true;
    p.color = IntroStoryColors.mountainBaseLeft;
    c.drawOval(Rect.fromCenter(center: const Offset(cx - 86, base + 2), width: 160, height: 24), p);
    p.color = IntroStoryColors.mountainBaseRight;
    c.drawOval(Rect.fromCenter(center: const Offset(cx + 86, base + 2), width: 172, height: 24), p);
    final dots = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..color = IntroStoryColors.trail
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    c.drawPath(trailDots(), dots);
    return rec.endRecording();
  }

  static Path trailDots() {
    final line = Path()..addPolygon(IntroTrail.instance.points, false);
    final out = Path();
    for (final m in line.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += dotStep) {
        out.addPath(m.extractPath(d, d + dotLength), Offset.zero);
      }
    }
    return out;
  }
}
