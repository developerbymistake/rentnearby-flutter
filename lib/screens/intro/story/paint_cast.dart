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
    for (final i in cast.order) {
      if (i == CastFrame.fire) continue;
      _actor(canvas, i, cast.actors[i]);
    }
    if (cast.canopy > IntroGlider.minCanopy) IntroGlider.paint(canvas, cast);
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
