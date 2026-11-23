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
