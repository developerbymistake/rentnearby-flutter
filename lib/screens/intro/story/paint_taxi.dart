import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../../design/tokens/intro_story_colors.dart';
import 'intro_story_art.dart';
import 'intro_story_math.dart';
import 'intro_story_state.dart';

class IntroTaxiDrawer {
  static const List<double> hubX = [99.5, 171];
  static const double hubY = 412.5;
  static const List<IntroArt> _heads = [IntroArt.panda, IntroArt.fox, IntroArt.lion];
  static const List<double> _headX = [84, 106, 139];
  static final Path _beam = Path()..addPolygon(const [Offset(206, 396), Offset(330, 368), Offset(330, 430), Offset(206, 404)], true);
  static final ui.Gradient _beamShader = ui.Gradient.linear(const Offset(206, 0), const Offset(330, 0), const [IntroStoryColors.beamCore, IntroStoryColors.beamEdge]);
  static final Path _windows = Path()
    ..addRRect(RRect.fromLTRBR(81, 347, 127, 367.5, const Radius.circular(3)))
    ..addRRect(RRect.fromLTRBR(137, 347, 166, 367.5, const Radius.circular(3)));
  static const List<Offset> _hubDots = [Offset(0, -4), Offset(3.8, 1.2), Offset(-3.8, 1.2)];

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _beamPaint = Paint()..shader = _beamShader;
  final Paint _image = Paint()..filterQuality = FilterQuality.medium;

  void paint(Canvas canvas, IntroStoryState state) {
    final q = state.q;
    final t = state.time;
    final arr = state.arrival;
    final dx = arr.dx;
    final v = (storyS(q + .01) - storyS(q - .01)) / .02;
    final mv = clamp01(v.abs() / 700 + idleWeightOf(q) + arr.speed / 520);
    final bob = math.sin(t * 15) * .9 * mv + math.sin(t * 23) * .4 * mv;
    final art = state.artIn;
    canvas.save();
    canvas.translate(dx, 0);
    _fill.color = IntroStoryColors.shadow32;
    canvas.drawOval(Rect.fromCenter(center: const Offset(135, 424), width: 152, height: 12), _fill);
    final beam = beamOf(q);
    if (beam > 0) {
      _beamPaint.color = IntroStoryColors.white.withValues(alpha: beam);
      canvas.drawPath(_beam, _beamPaint);
    }
    if (mv > 0) {
      for (var i = 0; i < 4; i++) {
        final ph = (t * 1.5 + i / 4) % 1;
        final a = (1 - ph) * .45 * mv;
        _fill.color = IntroStoryColors.puff.withValues(alpha: a);
        canvas.drawCircle(Offset(70 - ph * 46, 420 - ph * 12), 3 + ph * 8, _fill);
      }
    }
    canvas.translate(0, bob);
    canvas.translate(135, 420);
    canvas.rotate(state.pitch * math.pi / 180);
    canvas.translate(-135, -420);
    final taxi = IntroStoryArt.instance[IntroArt.taxi];
    if (taxi != null && art > 0) {
      canvas.save();
      canvas.scale(-1, 1);
      _drawImage(canvas, taxi, const Rect.fromLTWH(-210, 290, 150, 150), art);
      canvas.restore();
    }
    final rot = (state.d / 7.2 + dx / 7.2) * 57.3 * math.pi / 180;
    for (final hx in hubX) {
      canvas.save();
      canvas.translate(hx, hubY);
      _fill.color = IntroStoryColors.hub;
      canvas.drawCircle(Offset.zero, 7.2, _fill);
      canvas.rotate(rot);
      _fill.color = IntroStoryColors.hubDot;
      for (final o in _hubDots) {
        canvas.drawCircle(o, 1.5, _fill);
      }
      canvas.restore();
    }
    _windowHeads(canvas, state, art);
    canvas.restore();
  }

  void _windowHeads(Canvas canvas, IntroStoryState state, double art) {
    canvas.save();
    canvas.clipPath(_windows);
    for (var i = 0; i < 3; i++) {
      if (!state.cast.actors[i].inside) continue;
      final img = IntroStoryArt.instance[_heads[i]];
      if (img != null && art > 0) _drawImage(canvas, img, Rect.fromLTWH(_headX[i], 344, 26, 26), art);
    }
    _fill.color = IntroStoryColors.glass20;
    canvas.drawRect(const Rect.fromLTWH(80, 346, 90, 22), _fill);
    canvas.restore();
  }

  void _drawImage(Canvas canvas, ui.Image img, Rect dst, double alpha) {
    _image.color = IntroStoryColors.white.withValues(alpha: alpha);
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, _image);
  }
}
