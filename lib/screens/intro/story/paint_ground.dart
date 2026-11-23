import 'package:flutter/rendering.dart';

import '../../../design/tokens/intro_story_colors.dart';
import 'intro_story_art.dart';
import 'intro_story_math.dart';
import 'intro_story_state.dart';

enum IntroGroundPart { trees, road }

class IntroGroundPainter extends CustomPainter {
  IntroGroundPainter(this.state, this.geo, this.part) : super(repaint: state.scroll);

  final IntroStoryState state;
  final IntroStoryGeo geo;
  final IntroGroundPart part;

  static const double _treeTile = 540;
  static const double _treeBase = 396;
  static const List<double> _trees = [30, 64, 0, 104, 52, 1, 176, 84, 0, 262, 58, 1, 330, 72, 0, 412, 50, 1, 470, 78, 0];
  static const double _dashPeriod = 42;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _image = Paint()..filterQuality = FilterQuality.medium;
  final Paint _dash = Paint()
    ..color = IntroStoryColors.white85
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  Path? _dashPath;
  IntroStoryGeo? _dashGeo;

  Path _dashes() {
    if (_dashPath != null && _dashGeo == geo) return _dashPath!;
    final p = Path();
    final x0 = (geo.vx0 / _dashPeriod).floor() * _dashPeriod - _dashPeriod;
    for (var x = x0; x < geo.vx1 + _dashPeriod * 2; x += _dashPeriod) {
      p
        ..moveTo(x, 417)
        ..lineTo(x + 22, 417);
    }
    _dashGeo = geo;
    return _dashPath = p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pal = state.palette;
    final d = state.d;
    final x0 = geo.vx0, x1 = geo.vx1;
    canvas.save();
    canvas.translate(geo.ox, geo.oy);
    canvas.scale(geo.k);
    if (part == IntroGroundPart.trees) {
      _treesLayer(canvas, d);
      canvas.restore();
      return;
    }
    _fill.color = IntroStoryColors.curb;
    canvas.drawRect(Rect.fromLTRB(x0, 392, x1, 397), _fill);
    _fill.color = pal.r;
    canvas.drawRect(Rect.fromLTRB(x0, 397, x1, 437), _fill);
    _fill.color = IntroStoryColors.shadow18;
    canvas.drawRect(Rect.fromLTRB(x0, 397, x1, 400), _fill);
    canvas.save();
    canvas.translate(-(d % _dashPeriod), 0);
    canvas.drawPath(_dashes(), _dash);
    canvas.restore();
    _fill.color = pal.g;
    canvas.drawRect(Rect.fromLTRB(x0, 437, x1, 482), _fill);
    canvas.restore();
  }

  void _treesLayer(Canvas canvas, double d) {
    final img = IntroStoryArt.instance[IntroArt.tree];
    final a = state.artIn;
    if (img == null || a <= 0) return;
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    _image.color = IntroStoryColors.white.withValues(alpha: a);
    var tile = -((d * .9) % _treeTile);
    while (tile > geo.vx0 - 50) {
      tile -= _treeTile;
    }
    for (; tile < geo.vx1 + 50; tile += _treeTile) {
      for (var j = 0; j < _trees.length; j += 3) {
        final x = tile + _trees[j], h = _trees[j + 1];
        if (x + h / 2 < geo.vx0 || x - h / 2 > geo.vx1) continue;
        canvas.save();
        canvas.translate(x, _treeBase);
        _fill.color = IntroStoryColors.shadow18.withValues(alpha: IntroStoryColors.shadow18.a * a);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: h * .68, height: 8), _fill);
        if (_trees[j + 2] == 1) canvas.scale(-1, 1);
        canvas.drawImageRect(img, src, Rect.fromLTWH(-h / 2, -h * .94, h, h), _image);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant IntroGroundPainter old) => old.geo != geo || old.state != state || old.part != part;
}
