import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../../design/tokens/intro_story_colors.dart';
import 'intro_story_art.dart';
import 'intro_story_cast.dart';
import 'intro_story_math.dart';
import 'intro_story_state.dart';
import 'paint_taxi.dart';

class IntroActorsPainter extends CustomPainter {
  IntroActorsPainter(this.state, this.geo) : super(repaint: state.frame);

  final IntroStoryState state;
  final IntroStoryGeo geo;

  static const List<IntroArt> _art = [IntroArt.panda, IntroArt.fox, IntroArt.lion];
  static const List<Color> _feet = [IntroStoryColors.footPanda, IntroStoryColors.footFox, IntroStoryColors.footLion];

  final IntroTaxiDrawer _taxi = IntroTaxiDrawer();
  final IntroCampfireDrawer _campfire = IntroCampfireDrawer();
  final IntroSelfieDrawer _selfie = IntroSelfieDrawer();
  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _image = Paint()..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(geo.ox, geo.oy);
    canvas.scale(geo.k);
    canvas.clipRect(Rect.fromLTRB(geo.vx0, geo.vy0, geo.vx1, IntroStory.sceneH));
    _taxi.paint(canvas, state);
    final cast = state.cast;
    final t = state.time;
    final q = state.q;
    for (final i in cast.order) {
      if (i == CastFrame.fire) {
        _campfire.paint(canvas, IntroStory.fireWorldX - state.s, q, t, geo);
        continue;
      }
      _actor(canvas, i, cast.actors[i]);
    }
    if (cast.hasPandaPose) _selfie.paint(canvas, cast, q, t, state.artIn);
    if (cast.canopy > IntroGlider.minCanopy) IntroGlider.paint(canvas, cast);
    final cb = state.reduce ? 0.0 : confettiOf(q);
    if (cb > 0) _confetti(canvas, cb, t);
    canvas.restore();
  }

  void _actor(Canvas canvas, int i, CastActor a) {
    if (a.alpha <= 0) return;
    canvas.save();
    canvas.translate(a.x, a.y);
    final sh = a.shadow;
    if (sh > 0) {
      final shA = IntroStoryColors.shadow28.a * a.alpha * a.alpha;
      _fill.color = IntroStoryColors.shadow28.withValues(alpha: shA);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 34 * sh, height: 8.4 * sh), _fill);
    }
    canvas.translate(0, -a.hop);
    canvas.rotate(a.tilt * math.pi / 180);
    canvas.scale(a.sx * a.sc, a.sy * a.sc);
    final footA = a.alpha;
    _fill.color = _feet[i].withValues(alpha: footA);
    canvas.drawOval(Rect.fromCenter(center: Offset(-9, -4 - a.footL), width: 14, height: 9.2), _fill);
    canvas.drawOval(Rect.fromCenter(center: Offset(9, -4 - a.footR), width: 14, height: 9.2), _fill);
    final img = IntroStoryArt.instance[_art[i]];
    final ia = a.alpha * state.artIn;
    if (img != null && ia > 0) _drawImage(canvas, img, const Rect.fromLTWH(-24, -54, 48, 48), ia);
    canvas.restore();
  }

  void _confetti(Canvas canvas, double cb, double t) {
    const colors = IntroStoryColors.confetti;
    for (var i = 0; i < 16; i++) {
      final f = (t * .16 + i * .0625) % 1;
      final a = cb * math.min(1.0, f * 5) * (1 - math.max(0.0, (f - .6) / .4)) * .9;
      if (a <= 0) continue;
      final cx = 262 + (i - 8) * 11 + math.sin(t * 1.3 + i) * 7, cy = 270 + f * 150;
      canvas.save();
      canvas.translate(cx + 3, cy + 3);
      canvas.rotate((t * 90 + i * 40) * math.pi / 180);
      _fill.color = colors[i % colors.length].withValues(alpha: a);
      canvas.drawRRect(IntroSelfieDrawer.confettiPiece, _fill);
      canvas.restore();
    }
  }

  void _drawImage(Canvas canvas, ui.Image img, Rect dst, double alpha) {
    _image.color = IntroStoryColors.white.withValues(alpha: alpha);
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, _image);
  }

  @override
  bool shouldRepaint(covariant IntroActorsPainter old) => old.geo != geo || old.state != state;
}

abstract final class IntroGlider {
  static const double minCanopy = .02, minScale = .01, size = 1.15, lift = 8;

  static final Path dome = Path()
    ..moveTo(-46, -74)
    ..quadraticBezierTo(0, -128, 46, -74)
    ..quadraticBezierTo(31, -81, 15, -74)
    ..quadraticBezierTo(0, -81, -15, -74)
    ..quadraticBezierTo(-31, -81, -46, -74)
    ..close();

  static ui.Picture? _picture;

  static void paint(Canvas canvas, CastFrame cast) {
    canvas.save();
    canvas.translate(cast.canopyX, cast.canopyY - lift);
    canvas.rotate(cast.canopyTilt * math.pi / 180);
    final k = math.max(minScale, cast.canopy) * size;
    canvas.scale(k, k);
    canvas.drawPicture(_picture ??= _record());
    canvas.restore();
  }

  static ui.Picture _record() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final p = Paint()..isAntiAlias = true;
    const colors = IntroStoryColors.canopy;
    for (var k = 0; k < colors.length; k++) {
      p.color = colors[k];
      final stripe = Path()..addRect(Rect.fromLTWH(-46 + k * 15.34, -130, 15.4, 60));
      c.drawPath(Path.combine(PathOperation.intersect, stripe, dome), p);
    }
    p.shader = ui.Gradient.linear(
      const Offset(0, -130),
      const Offset(0, -70),
      const [IntroStoryColors.domeLight, IntroStoryColors.clear, IntroStoryColors.clearBlack, IntroStoryColors.domeDark],
      const [0, .5, .5, 1],
    );
    c.drawPath(dome, p);
    final line = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = IntroStoryColors.canopyLine;
    c.drawLine(const Offset(-44, -74), const Offset(-7, -50), line);
    c.drawLine(const Offset(-22, -74), const Offset(-4, -52), line);
    c.drawLine(const Offset(0, -76), const Offset(0, -54), line);
    c.drawLine(const Offset(22, -74), const Offset(4, -52), line);
    c.drawLine(const Offset(44, -74), const Offset(7, -50), line);
    return rec.endRecording();
  }
}

class IntroCampfireDrawer {
  static const double halfSpan = 160, flameScale = 1.7;
  static const List<Offset> stones = [Offset(-24, -1), Offset(-16, 3), Offset(-6, 5), Offset(6, 5), Offset(16, 3), Offset(24, -1)];
  static final RRect _log = RRect.fromLTRBR(-22, -7, 22, 1, const Radius.circular(4));
  static final Path outer = Path()
    ..moveTo(-10, -2)
    ..quadraticBezierTo(-15, -20, -3, -34)
    ..quadraticBezierTo(1, -18, 10, -4)
    ..close();
  static final Path inner = Path()
    ..moveTo(-5, -2)
    ..quadraticBezierTo(-8, -14, 2, -24)
    ..quadraticBezierTo(5, -12, 7, -2)
    ..close();
  static final ui.Gradient _flame = ui.Gradient.linear(const Offset(0, -2), const Offset(0, -34), const [IntroStoryColors.flameBottom, IntroStoryColors.flameTop]);

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _flamePaint = Paint()
    ..isAntiAlias = true
    ..shader = _flame;

  void paint(Canvas canvas, double x, double q, double t, IntroStoryGeo geo) {
    if (x + halfSpan < geo.vx0 || x - halfSpan > geo.vx1) return;
    final on = fireOnOf(q);
    canvas.save();
    canvas.translate(x, IntroStory.groundY);
    _fill.color = IntroStoryColors.shadow30;
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 3), width: 60, height: 10), _fill);
    _fill.color = IntroStoryColors.stone;
    for (final o in stones) {
      canvas.drawCircle(o, 4, _fill);
    }
    _logAt(canvas, -12, IntroStoryColors.logDark);
    _logAt(canvas, 12, IntroStoryColors.logLight);
    if (on > 0) {
      canvas.save();
      canvas.scale(flameScale, flameScale);
      _flamePaint.color = IntroStoryColors.white.withValues(alpha: on);
      _flameAt(canvas, outer, 1 + .14 * math.sin(t * 11), on * (1 + .2 * math.sin(t * 13 + 1)), _flamePaint);
      _fill.color = IntroStoryColors.flameInner.withValues(alpha: on);
      _flameAt(canvas, inner, 1 + .1 * math.sin(t * 14), on * (1 + .25 * math.sin(t * 17)), _fill);
      canvas.restore();
      for (var i = 0; i < 14; i++) {
        final ph = (t * .55 + i / 14) % 1;
        final a = on * (1 - ph) * .95;
        _fill.color = IntroStoryColors.spark.withValues(alpha: a);
        canvas.drawCircle(Offset(math.sin(ph * 8 + i * 2) * 12 + (i % 3 - 1) * 5, -24 - ph * 78), 1 + 1.6 * (1 - ph), _fill);
      }
    }
    canvas.restore();
  }

  void _logAt(Canvas canvas, double deg, Color c) {
    canvas.save();
    canvas.rotate(deg * math.pi / 180);
    _fill.color = c;
    canvas.drawRRect(_log, _fill);
    canvas.restore();
  }

  void _flameAt(Canvas canvas, Path path, double sx, double sy, Paint paint) {
    if (sy <= 0) return;
    canvas.save();
    canvas.scale(sx, sy);
    canvas.drawPath(path, paint);
    canvas.restore();
  }
}

class IntroSelfieDrawer {
  static const double cycle = 3.4, flashStart = 2.4, flashLength = .4, popStart = 2.55;
  static final RRect confettiPiece = RRect.fromLTRBR(-3, -3, 3, 3, const Radius.circular(1.5));
  static final RRect _body = RRect.fromLTRBR(-10.5, -17, 10.5, 17, const Radius.circular(4.5));
  static final RRect _screen = RRect.fromLTRBR(-8.5, -14.5, 8.5, 14.5, const Radius.circular(3));
  static final RRect _gloss = RRect.fromLTRBR(-8.5, -14.5, 8.5, -4.5, const Radius.circular(3));

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _image = Paint()..filterQuality = FilterQuality.medium;

  static double rigAlpha(double q) => smooth((q - 2.95) / .04) * (1 - smooth((q - 3.08) / .04));

  static double cycleTime(double t) => ((t % cycle) + cycle) % cycle;

  static double popScale(double pp) => backOut(pp / .35) * (pp > 1.1 ? 1 - (pp - 1.1) / .4 : 1);

  void paint(Canvas canvas, CastFrame cast, double q, double t, double art) {
    final ps = rigAlpha(q);
    if (ps <= .02) return;
    final selC = cycleTime(t);
    final ex = smooth((q - 2.95) / .05);
    canvas.save();
    canvas.translate(cast.pandaX, cast.pandaY);
    canvas.translate(-17, -26);
    canvas.rotate(math.sin(t * 2.2) * 1.6 * math.pi / 180);
    canvas.translate(17, 26);
    _stroke
      ..color = IntroStoryColors.selfieArm.withValues(alpha: ps)
      ..strokeWidth = 7;
    canvas.drawLine(const Offset(-17, -26), const Offset(-30, -40), _stroke);
    _stroke
      ..color = IntroStoryColors.selfieStick.withValues(alpha: ps)
      ..strokeWidth = 2.6;
    canvas.drawLine(const Offset(-30, -40), Offset(-30 - 18 * ex, -40 - 56 * ex), _stroke);
    _stroke
      ..color = IntroStoryColors.selfieGrip.withValues(alpha: ps)
      ..strokeWidth = 5.2;
    canvas.drawLine(const Offset(-30, -40), const Offset(-34, -53), _stroke);
    _fill.color = IntroStoryColors.selfieArm.withValues(alpha: ps);
    canvas.drawCircle(const Offset(-30, -40), 5.2, _fill);
    canvas.translate(-30 - 18 * ex, -42 - 56 * ex);
    canvas.rotate((22 - (1 - ex) * 20 + math.sin(t * 2.6) * 2) * math.pi / 180);
    _fill.color = IntroStoryColors.phoneBody.withValues(alpha: ps);
    canvas.drawRRect(_body, _fill);
    _fill.color = IntroStoryColors.phoneScreen.withValues(alpha: ps);
    canvas.drawRRect(_screen, _fill);
    _fill.color = IntroStoryColors.white35.withValues(alpha: IntroStoryColors.white35.a * ps);
    canvas.drawRRect(_gloss, _fill);
    _fill.color = IntroStoryColors.phoneLens.withValues(alpha: ps);
    canvas.drawCircle(const Offset(0, -15.6), 1.1, _fill);
    final fc = selC - flashStart;
    if (fc > 0 && fc < flashLength) {
      final fa = (1 - fc / flashLength) * .9 * ps;
      _fill.color = IntroStoryColors.white.withValues(alpha: fa);
      canvas.drawCircle(Offset.zero, 10 + fc / flashLength * 70, _fill);
    }
    canvas.restore();
    final pp = selC - popStart;
    final img = IntroStoryArt.instance[IntroArt.framedPicture];
    if (pp > 0 && pp < 1.5 && ps > .5 && img != null && art > 0) {
      final sc = math.max(.01, popScale(pp));
      canvas.save();
      canvas.translate(IntroStory.poseX[1] - 4, 340 - pp * 18);
      canvas.rotate((-7 + pp * 4) * math.pi / 180);
      canvas.scale(sc, sc);
      _image.color = IntroStoryColors.white.withValues(alpha: art);
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), const Rect.fromLTWH(-24, -24, 48, 48), _image);
      canvas.restore();
    }
  }
}
