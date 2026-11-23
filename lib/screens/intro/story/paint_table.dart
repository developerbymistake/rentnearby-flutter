import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../../design/tokens/intro_story_colors.dart';
import 'intro_story_art.dart';
import 'intro_story_math.dart';
import 'intro_story_state.dart';

class IntroTablePainter extends CustomPainter {
  IntroTablePainter(this.state, this.geo) : super(repaint: state.frame);

  final IntroStoryState state;
  final IntroStoryGeo geo;

  static const double loop = 7.6;
  static const List<double> dropAt = [.5, 1.7, 2.9];
  static const List<List<double>> _places = [[.22, .62, 40], [.55, .34, 38], [.82, .6, 40]];
  static const List<IntroArt> _placeArt = [IntroArt.mountain, IntroArt.canoe, IntroArt.camping];
  static const List<List<double>> _route = [[.22, .62], [.38, .5], [.55, .34], [.7, .5], [.82, .6]];
  static const List<List<double>> _friends = [[30, 404, 1.1, .5, 1], [180, 234, 1, 1.7, 0], [332, 404, 1.1, 2.9, -1]];
  static const List<IntroArt> _friendArt = [IntroArt.panda, IntroArt.fox, IntroArt.lion];
  static const List<Color> _feet = [IntroStoryColors.footPanda, IntroStoryColors.footFox, IntroStoryColors.footLion];

  static final Color _grassDeep = mixColor(IntroStoryColors.palettes[0].g, IntroStoryColors.tableGrassDeep, .5);
  static final ui.Gradient _grass = ui.Gradient.linear(const Offset(0, 390), const Offset(0, 490), [IntroStoryColors.palettes[0].g, _grassDeep]);
  static final ui.PathMetric _routeMetric = (Path()..addPolygon([for (final r in _route) IntroMapQuad.project(r[0], r[1])], false)).computeMetrics().first;
  static ui.Picture? _back, _front;

  static double loopTime(double t) => ((t % loop) + loop) % loop;
  static double dropOf(double c, int i) => clamp01((c - dropAt[i]) / .55);
  static double routeOf(double c) => clamp01((c - 3.5) / 2.0);
  static double fadeOf(double c) => 1 - smooth((c - 6.5) / .8);
  static bool miniTaxiOn(double c) => routeOf(c) > 0 && c < 6.9;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _image = Paint()..filterQuality = FilterQuality.medium;
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _routePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final t = state.time;
    final c = loopTime(t);
    final art = state.artIn;
    canvas.save();
    canvas.translate(geo.ox, geo.oy);
    canvas.scale(geo.k);
    _fill
      ..shader = _grass
      ..color = IntroStoryColors.white;
    canvas.drawRect(Rect.fromLTRB(geo.vx0, 390, geo.vx1, 490), _fill);
    _fill
      ..shader = null
      ..color = IntroStoryColors.white35;
    canvas.drawRect(Rect.fromLTRB(geo.vx0, 388, geo.vx1, 392), _fill);
    canvas.drawPicture(_back ??= _recordBack());
    _friend(canvas, 1, c, t, art);
    canvas.drawPicture(_front ??= _recordFront());
    final fade = fadeOf(c);
    _routeLayer(canvas, c, fade);
    for (var i = 0; i < 3; i++) {
      _drop(canvas, i, c, fade, art);
    }
    _miniTaxi(canvas, c, fade, art);
    _friend(canvas, 0, c, t, art);
    _friend(canvas, 2, c, t, art);
    canvas.restore();
  }

  void _drop(Canvas canvas, int i, double c, double fade, double art) {
    final pl = _places[i];
    final at = IntroMapQuad.project(pl[0], pl[1]);
    final sz = pl[2];
    final t0 = dropAt[i];
    final f = dropOf(c, i);
    final o = backOut(f);
    final r = clamp01((c - t0 - .45) / .6);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (f > 0) {
      final sa = clamp01(f * 1.6) * fade;
      _fill.color = IntroStoryColors.shadow28.withValues(alpha: IntroStoryColors.shadow28.a * sa);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: sz * .68, height: sz * .2), _fill);
    }
    if (r > 0 && r < 1) {
      final ra = (1 - r) * .9 * fade;
      _ring.color = IntroStoryColors.white.withValues(alpha: ra);
      canvas.drawCircle(Offset.zero, 3 + r * 26, _ring);
    }
    final img = IntroStoryArt.instance[_placeArt[i]];
    if (f > 0 && img != null) {
      final s = .6 + .4 * math.min(1, o);
      canvas.translate(0, -(1 - o) * 80);
      canvas.scale(s);
      _drawImage(canvas, img, Rect.fromLTWH(-sz / 2, -sz * .92, sz, sz), fade * art);
    }
    canvas.restore();
  }

  void _routeLayer(Canvas canvas, double c, double fade) {
    final rs = routeOf(c);
    if (rs <= 0) return;
    final ra = .9 * fade;
    _routePaint.color = IntroStoryColors.route.withValues(alpha: ra);
    canvas.drawPath(_routeMetric.extractPath(0, _routeMetric.length * rs), _routePaint);
  }

  void _miniTaxi(Canvas canvas, double c, double fade, double art) {
    if (!miniTaxiOn(c)) return;
    final rs = routeOf(c);
    final len = _routeMetric.length;
    final pt = _routeMetric.getTangentForOffset(len * rs)!.position;
    final pt2 = _routeMetric.getTangentForOffset(math.min(len, len * rs + 4))!.position;
    canvas.save();
    canvas.translate(pt.dx, pt.dy);
    _fill.color = IntroStoryColors.shadow25.withValues(alpha: IntroStoryColors.shadow25.a * fade);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 2), width: 24, height: 6), _fill);
    final img = IntroStoryArt.instance[IntroArt.taxi];
    if (img != null) {
      if (pt2.dx >= pt.dx) canvas.scale(-1, 1);
      _drawImage(canvas, img, const Rect.fromLTWH(-14, -24, 28, 28), fade * art);
    }
    canvas.restore();
  }

  void _friend(Canvas canvas, int i, double c, double t, double art) {
    final f = _friends[i];
    final sc = f[2], lean = f[4];
    final since = c - f[3];
    final hop = since > 0 && since < .6 ? math.sin(since / .6 * math.pi) * 16 : 0.0;
    final planning = c > 3.5 && c < 6.6 ? math.sin(t * 6 + i) * 2 : 0.0;
    final br = math.sin(t * 2.2 + i);
    final land = since > .5 && since < .8 ? math.sin((since - .5) / .3 * math.pi) * .12 : 0.0;
    canvas.save();
    canvas.translate(f[0], f[1]);
    final sh = (1 - hop / 60) * sc;
    _fill.color = IntroStoryColors.shadow28;
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 34 * sh, height: 8.4 * sh), _fill);
    canvas.translate(0, -hop - math.max(0, planning));
    canvas.rotate(lean * (7 + planning) * math.pi / 180);
    canvas.scale((1 + .02 * br + land * .6) * sc, (1 - .02 * br - land) * sc);
    _fill.color = _feet[i];
    canvas.drawOval(Rect.fromCenter(center: const Offset(-9, -4), width: 14, height: 9.2), _fill);
    canvas.drawOval(Rect.fromCenter(center: const Offset(9, -4), width: 14, height: 9.2), _fill);
    final img = IntroStoryArt.instance[_friendArt[i]];
    if (img != null) _drawImage(canvas, img, const Rect.fromLTWH(-24, -54, 48, 48), art);
    canvas.restore();
  }

  void _drawImage(Canvas canvas, ui.Image img, Rect dst, double alpha) {
    if (alpha <= 0) return;
    _image.color = IntroStoryColors.white.withValues(alpha: alpha);
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, _image);
  }

  static ui.Picture _recordBack() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawOval(Rect.fromCenter(center: const Offset(180, 410), width: 352, height: 24), Paint()..color = IntroStoryColors.shadow22);
    return rec.endRecording();
  }

  static Path _poly(List<List<double>> pts, {bool close = true}) =>
      Path()..addPolygon([for (final q in pts) IntroMapQuad.project(q[0], q[1])], close);

  static ui.Picture _recordFront() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final p = Paint()..isAntiAlias = true;
    void rrect(double x, double y, double w, double h, double r, Color color) =>
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)), p..color = color);
    rrect(34, 350, 11, 48, 4, IntroStoryColors.woodLeg);
    rrect(315, 350, 11, 48, 4, IntroStoryColors.woodLeg);
    rrect(62, 330, 9, 28, 3, IntroStoryColors.woodLegBack);
    rrect(290, 330, 9, 28, 3, IntroStoryColors.woodLegBack);
    c.drawPath(Path()..addPolygon(const [Offset(14, 346), Offset(346, 346), Offset(342, 358), Offset(18, 358)], true), p..color = IntroStoryColors.woodLeg);
    c.drawPath(Path()..addPolygon(const [Offset(62, 226), Offset(298, 226), Offset(346, 346), Offset(14, 346)], true), p..color = IntroStoryColors.wood);
    c.drawPath(Path()..addPolygon(const [Offset(62, 226), Offset(298, 226), Offset(292, 232), Offset(68, 232)], true), p..color = IntroStoryColors.white25);
    final quad = _poly(const [[0, 0], [1, 0], [1, 1], [0, 1]]);
    c.save();
    c.clipPath(quad);
    c.drawPath(
      quad,
      Paint()..shader = ui.Gradient.linear(const Offset(0, 236), const Offset(0, 338), const [IntroStoryColors.landTop, IntroStoryColors.landBottom]),
    );
    p.color = IntroStoryColors.park;
    c.drawPath(_poly(const [[.05, .55], [.2, .5], [.28, .65], [.12, .8], [.04, .72]]), p);
    c.drawPath(_poly(const [[.62, .7], [.8, .74], [.78, .92], [.6, .9]]), p);
    c.drawPath(_poly(const [[.38, .08], [.55, .06], [.58, .22], [.4, .24]]), p);
    c.drawPath(_poly(const [[.74, .12], [.9, .1], [.95, .26], [.8, .3]]), p..color = IntroStoryColors.water);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(_poly(const [[0, .2], [.2, .3], [.38, .36], [.5, .52], [.72, .6], [1, .8]], close: false), line
      ..color = IntroStoryColors.water
      ..strokeWidth = 9);
    p.color = IntroStoryColors.block;
    for (var i = 0; i < 5; i++) {
      for (var j = 0; j < 3; j++) {
        final u = .3 + i * .085, v = .5 + j * .14;
        c.drawPath(_poly([[u, v], [u + .06, v], [u + .06, v + .09], [u, v + .09]]), p);
      }
    }
    line.color = IntroStoryColors.white;
    const roads = [
      ([[0.0, .46], [.5, .4], [1.0, .32]], 4.0),
      ([[.44, 0.0], [.5, .5], [.56, 1.0]], 4.0),
      ([[0.0, .1], [.5, .5], [1.0, .92]], 3.0),
      ([[.2, 1.0], [.3, .5], [.2, 0.0]], 2.5),
      ([[.7, 1.0], [.68, .5], [.8, 0.0]], 2.5),
    ];
    for (final (pts, w) in roads) {
      c.drawPath(_poly(pts, close: false), line..strokeWidth = w);
    }
    line
      ..color = IntroStoryColors.mapLine35
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;
    c.drawPath(_poly(const [[.05, .9], [.2, .85], [.3, .95]], close: false), line);
    c.drawPath(_poly(const [[.6, .05], [.7, .2], [.9, .15]], close: false), line);
    c.restore();
    c.drawPath(
      quad,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = IntroStoryColors.white,
    );
    return rec.endRecording();
  }

  @override
  bool shouldRepaint(covariant IntroTablePainter old) => old.geo != geo || old.state != state;
}
