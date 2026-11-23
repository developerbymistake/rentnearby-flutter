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
