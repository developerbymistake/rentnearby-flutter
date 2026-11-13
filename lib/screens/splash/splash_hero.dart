import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/design.dart';

const double _artW = 360;
const double _artH = 780;
const double _contentTop = 36;
const double _contentBottom = 766;
const double _introMs = 2400;
const Duration _introDuration = Duration(milliseconds: 2400);
const Duration _ambientPeriod = Duration(hours: 1);
const Duration _warmUpCap = Duration(milliseconds: 150);
// Phones show the portrait art only; main.dart allows every orientation again after the splash.
const double _phoneMaxSide = 600;
const List<DeviceOrientation> _portrait = [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];

const double _driveStart = 200;
const double _driveMs = 1900;
const double _popMs = 450;
const double _ringMs = 800;
const double _stepMs = 400;
const double _treeMs = 400;
const double _titleStart = 1800;
const double _titleMs = 600;
const double _planeStart = 100;
const double _planeMs = 2150;

const String _brand = 'Bakhli';
const String _tagline = 'Plan your next trip';
const List<String> _steps = ['Pick places', 'Find a stay', 'Book a taxi', 'Go and enjoy'];
const List<Offset> _stepAt = [Offset(152, 700), Offset(104, 578), Offset(130, 470), Offset(96, 356)];
const List<String> _assets = [ListingArt.mountain, ListingArt.luggage, ListingArt.beach, ListingArt.pushpin];

const Cubic _popCurve = Cubic(0.3, 1.4, 0.5, 1.0);
const Cubic _flyCurve = Cubic(0.35, 0.1, 0.7, 0.9);

double _mockToApp(double sec) => _driveStart + (sec - 0.5) * 1000 * _driveMs / 3000;

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

double _easeQuad(double t) => t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;

double _easeQuadInv(double k) {
  final v = _clamp01(k);
  return v < 0.5 ? math.sqrt(v / 2) : 1 - math.sqrt((1 - v) * 2) / 2;
}

class SplashHero extends StatefulWidget {
  const SplashHero({super.key});

  static const Key titleKey = ValueKey('splash_title');

  @override
  State<SplashHero> createState() => _SplashHeroState();
}

class _SplashHeroState extends State<SplashHero> with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _ambient;
  final ValueNotifier<int> _imageTick = ValueNotifier<int>(0);
  final Map<String, ImageInfo> _images = {};
  final List<(ImageStream, ImageStreamListener)> _streams = [];
  bool _reduceMotion = false;
  bool _started = false;
  bool _hapticDone = false;
  bool _lockedPortrait = false;
  _Geo? _geo;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: _introDuration);
    _ambient = AnimationController(vsync: this, duration: _ambientPeriod);
    _intro.addListener(_onIntroTick);
    _intro.addStatusListener(_onIntroStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      if (MediaQuery.sizeOf(context).shortestSide < _phoneMaxSide) {
        _lockedPortrait = true;
        SystemChrome.setPreferredOrientations(_portrait);
      }
      _resolveImages();
      if (_reduceMotion) {
        _intro.value = 1.0;
      } else {
        _warmUp();
      }
    } else if (_reduceMotion) {
      _ambient.stop();
      _ambient.value = 0;
      if (!_intro.isCompleted) _intro.value = 1.0;
    } else if (_intro.isCompleted && !_ambient.isAnimating) {
      _ambient.repeat();
    }
  }

  void _resolveImages() {
    final config = createLocalImageConfiguration(context);
    for (final asset in _assets) {
      final stream = AssetImage(asset).resolve(config);
      final listener = ImageStreamListener(
        (info, _) {
          _images.remove(asset)?.dispose();
          _images[asset] = info;
          _imageTick.value++;
        },
        onError: (_, _) {},
      );
      stream.addListener(listener);
      _streams.add((stream, listener));
    }
  }

  Future<void> _warmUp() async {
    try {
      await Future.wait([for (final a in _assets) precacheImage(AssetImage(a), context)]).timeout(_warmUpCap);
    } catch (_) {}
    if (!mounted || _intro.isAnimating || _intro.isCompleted) return;
    if (_reduceMotion) {
      _intro.value = 1.0;
    } else {
      _intro.forward();
      _ambient.repeat();
    }
  }

  void _onIntroTick() {
    if (_hapticDone || _reduceMotion || _intro.value * _introMs < _road.showAt[4]) return;
    _hapticDone = true;
    HapticFeedback.lightImpact();
  }

  void _onIntroStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && !_reduceMotion && !_ambient.isAnimating) {
      _ambient.repeat();
    }
  }

  _Geo _geoFor(Size size, EdgeInsets pad, double dpr) {
    final cached = _geo;
    if (cached != null && cached.size == size && cached.pad == pad && cached.dpr == dpr) return cached;
    cached?.dispose();
    return _geo = _Geo(size, pad, dpr);
  }

  @override
  void dispose() {
    for (final (stream, listener) in _streams) {
      stream.removeListener(listener);
    }
    _streams.clear();
    for (final info in _images.values) {
      info.dispose();
    }
    _images.clear();
    _intro.removeListener(_onIntroTick);
    _intro.removeStatusListener(_onIntroStatus);
    _intro.dispose();
    _ambient.dispose();
    _imageTick.dispose();
    _geo?.dispose();
    _geo = null;
    if (_lockedPortrait) SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewPaddingOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return MediaQuery.withNoTextScaling(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (size.isEmpty || !size.isFinite) {
            return const ColoredBox(color: DesignColors.dinnerEnd);
          }
          final g = _geoFor(size, pad, dpr);
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: DesignColors.dinnerEnd),
              RepaintBoundary(child: CustomPaint(painter: _SkyPainter(g, _intro, _ambient))),
              RepaintBoundary(child: CustomPaint(painter: _LandPainter(g, _intro, _imageTick, _images))),
              RepaintBoundary(child: CustomPaint(painter: _MarkPainter(g, _intro, _imageTick, _images))),
              BackdropGroup(
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (context, _) => Stack(children: _pills(g)),
                ),
              ),
              RepaintBoundary(child: CustomPaint(painter: _TopPainter(g, _intro))),
              Positioned.fromRect(
                rect: g.toScreen(g.titleRect),
                child: Semantics(
                  key: SplashHero.titleKey,
                  header: true,
                  label: '$_brand. $_tagline',
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _pills(_Geo g) {
    final ms = _intro.value * _introMs;
    final s = g.s;
    return [
      for (var i = 0; i < _steps.length; i++)
        Positioned(
          left: g.ox + _stepAt[i].dx * s,
          top: g.oy + _stepAt[i].dy * s,
          child: _StepPill(
            index: i,
            scale: s,
            progress: Curves.ease.transform(_clamp01((ms - _road.showAt[i]) / _stepMs)),
            done: ms >= _road.showAt[i + 1],
          ),
        ),
    ];
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.index, required this.scale, required this.progress, required this.done});

  final int index;
  final double scale;
  final double progress;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final badge = 23 * s;
    final radius = BorderRadius.circular(20 * s);
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, 8 * s * (1 - progress)),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter.grouped(
            filter: ui.ImageFilter.blur(sigmaX: 5 * s, sigmaY: 5 * s),
            child: Container(
              padding: EdgeInsets.fromLTRB(5 * s, 5 * s, 13 * s, 5 * s),
              decoration: BoxDecoration(
                color: SplashInk.pillFill,
                borderRadius: radius,
                border: Border.all(color: SplashInk.pillBorder, width: s),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: badge,
                    height: badge,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? SplashInk.badgeDone : null,
                      gradient: done
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [SplashInk.badgeStart, SplashInk.badgeEnd],
                            ),
                    ),
                    child: done
                        ? CustomPaint(key: ValueKey('splash_done_$index'), size: Size.square(badge), painter: const _TickPainter())
                        : Text(
                            '${index + 1}',
                            style: TextStyle(fontFamily: TypeTokens.family, fontSize: 11 * s, fontWeight: FontWeight.w600, color: SplashInk.white, height: 1.0, letterSpacing: 0, inherit: false),
                          ),
                  ),
                  SizedBox(width: 8 * s),
                  Text(
                    _steps[index],
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontFamily: TypeTokens.family, fontSize: 12 * s, fontWeight: FontWeight.w600, color: SplashInk.white, letterSpacing: 0, inherit: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  const _TickPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 23;
    canvas.drawPath(
      Path()
        ..moveTo(7.2 * k, 11.9 * k)
        ..lineTo(10.2 * k, 14.9 * k)
        ..lineTo(15.9 * k, 8.4 * k),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1 * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = SplashInk.white,
    );
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) => false;
}

// Road timeline shared by every painter; geometry is in mock canvas units.
class _Road {
  _Road() {
    metric = _svgPath('M180 730 C40 660 60 580 180 540 S320 450 200 400 S160 350 182 316').computeMetrics().first;
    length = metric.length;
    const anchors = [Offset(100, 742), Offset(288, 584), Offset(70, 470), Offset(292, 400), Offset(184, 320)];
    final th = [for (final a in anchors) _nearest(a)];
    th[0] = 0;
    th[4] = 0.9;
    showAt = [for (var i = 0; i < 5; i++) i == 0 ? 0.0 : _driveStart + _driveMs * _easeQuadInv(th[i] - 0.02)];
  }

  late final ui.PathMetric metric;
  late final double length;
  late final List<double> showAt;

  Offset at(double l) => metric.getTangentForOffset(l.clamp(0.0, length))!.position;

  static double depth(double y) => _clamp01((y - 316) / (730 - 316));

  double _nearest(Offset p) {
    var best = 0.0, dist = double.infinity;
    for (var l = 0.0; l <= length; l += 4) {
      final d = (at(l) - p).distanceSquared;
      if (d < dist) {
        dist = d;
        best = l;
      }
    }
    return best / length;
  }
}

final _Road _road = _Road();

class _Fx {
  const _Fx(this.dx, this.dy, this.sigma, [this.color]);
  final double dx, dy, sigma;
  final Color? color;
}

class _Sprite {
  _Sprite(this.image, this.rect);
  final ui.Image image;
  final Rect rect;

  void draw(Canvas c, Paint p) =>
      c.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), rect, p);
}

ui.Image _record(int w, int h, void Function(Canvas c) draw) {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec));
  final pic = rec.endRecording();
  final img = pic.toImageSync(w, h);
  pic.dispose();
  return img;
}

// Renders [paint] (local units) at [res] px per unit, then applies CSS-like shadows in pixel space.
_Sprite _bake(Rect content, double res, void Function(Canvas c) paint, {List<_Fx> fx = const [], bool keepSource = true}) {
  var pad = 1.0;
  for (final f in fx) {
    pad += 3 * f.sigma + math.max(f.dx.abs(), f.dy.abs());
  }
  final r = content.inflate(pad);
  final w = math.max(1, (r.width * res).ceil());
  final h = math.max(1, (r.height * res).ceil());
  var img = _record(w, h, (c) {
    c.scale(res);
    c.translate(-r.left, -r.top);
    paint(c);
  });
  if (fx.isNotEmpty) {
    final src = img;
    img = _record(w, h, (c) {
      for (final f in fx.reversed) {
        final p = Paint()..filterQuality = FilterQuality.medium;
        if (f.sigma > 0) {
          p.imageFilter = ui.ImageFilter.blur(sigmaX: f.sigma * res, sigmaY: f.sigma * res, tileMode: TileMode.decal);
        }
        if (f.color != null) p.colorFilter = ColorFilter.mode(f.color!, BlendMode.srcIn);
        c.drawImage(src, Offset(f.dx * res, f.dy * res), p);
      }
      if (keepSource) c.drawImage(src, Offset.zero, Paint());
    });
    src.dispose();
  }
  return _Sprite(img, Rect.fromLTWH(r.left, r.top, w / res, h / res));
}

typedef _Pop =({double scale, double dy, double alpha});

_Pop _pop(double u) {
  if (u <= 0) return (scale: 0, dy: 20, alpha: 0);
  if (u >= 1) return (scale: 1, dy: 0, alpha: 1);
  final alpha = _clamp01(_popCurve.transform(u));
  if (u < 0.7) {
    final p = _popCurve.transform(u / 0.7);
    return (scale: 1.15 * p, dy: 20 * (1 - p), alpha: alpha);
  }
  final p = _popCurve.transform((u - 0.7) / 0.3);
  return (scale: 1.15 - 0.15 * p, dy: 0, alpha: alpha);
}

class _Tree {
  const _Tree(this.x, this.y, this.w, this.h, this.delay);
  final double x, y, w, h, delay;
}

const List<_Tree> _trees = [
  _Tree(22, 352, 18, 28, 1.0),
  _Tree(44, 371, 14, 22, 1.05),
  _Tree(8, 564, 34, 54, 1.1),
  _Tree(38, 590, 26, 41, 1.15),
  _Tree(116, 308, 10, 16, 1.2),
  _Tree(129, 311, 8, 13, 1.25),
  _Tree(230, 309, 9, 15, 1.2),
  _Tree(244, 311, 11, 17, 1.25),
  _Tree(262, 310, 8, 13, 1.3),
  _Tree(334, 454, 22, 34, 1.35),
  _Tree(326, 660, 32, 51, 1.4),
  _Tree(302, 682, 24, 38, 1.45),
];

const List<Rect> _mountains = [
  Rect.fromLTWH(-52, 196, 200, 200),
  Rect.fromLTWH(34, 246, 118, 118),
  Rect.fromLTWH(226, 206, 196, 196),
  Rect.fromLTWH(196, 250, 116, 116),
];
const List<double> _mountainStart = [40, 100, 80, 140];
// mountain.png has shaded vertical sides (cols 16-25 and 231-240 of 256); the big outer ones repeat mirrored outward past the 0..360 canvas.
const List<int> _mountainExtend = [-1, 0, 1, 0];

const List<Rect> _shadows = [
  Rect.fromLTWH(62, 746, 108, 12),
  Rect.fromLTWH(250, 638, 92, 12),
  Rect.fromLTWH(32, 526, 74, 12),
  Rect.fromLTWH(292, 446, 56, 12),
];

const List<Rect> _rings = [
  Rect.fromLTWH(68, 692, 104, 104),
  Rect.fromLTWH(252, 602, 86, 86),
  Rect.fromLTWH(30, 500, 72, 72),
  Rect.fromLTWH(290, 420, 56, 56),
];

const List<Rect> _icons = [
  Rect.fromLTWH(60, 640, 112, 112),
  Rect.fromLTWH(244, 556, 102, 85),
  Rect.fromLTWH(22, 452, 94, 66),
  Rect.fromLTWH(292, 384, 60, 60),
  Rect.fromLTWH(164, 284, 34, 34),
];

const List<(double, double, double, double, double, double, double)> _birds = [
  (150, 150, 26, 12, 2.2, 0, 0),
  (184, 170, 20, 10, 2.4, 0.2, 0.6),
  (128, 178, 16, 8, 2.6, 0.4, 1.1),
];

const List<(double, double, double)> _stars = [(40, 96, 0), (120, 70, 0.7), (330, 300, 1.1)];

class _Geo {
  _Geo(this.size, this.pad, this.dpr) {
    final aw = math.max(1.0, size.width - pad.left - pad.right);
    final ah = math.max(1.0, size.height - pad.top - pad.bottom);
    s = math.min(aw / _artW, ah / (_contentBottom - _contentTop));
    ox = pad.left + (aw - _artW * s) / 2;
    final lo = pad.top - _contentTop * s;
    final hi = size.height - pad.bottom - _contentBottom * s;
    oy = ((size.height - _artH * s) / 2).clamp(math.min(lo, hi), math.max(lo, hi));
    vis = Rect.fromLTRB(-ox / s, -oy / s, (size.width - ox) / s, (size.height - oy) / s);
    res = s * dpr;
    _buildStatic();
  }

  final Size size;
  final EdgeInsets pad;
  final double dpr;
  late final double s, ox, oy, res;
  late final Rect vis;

  late final Paint skyPaint, rayPaint, hazePaint, groundPaint, edgePaint, fillPaint, scrimPaint, vignettePaint, trailPaint;
  late final Path rays, rangeFar, rangeMid, ground, roadEdge, roadFill, bird;
  late final Rect hazeRect, scrimRect;
  late final List<(Offset, double, double)> dots;
  late final ui.Picture treePicture;
  late final Rect titleRect;
  final Map<String, _Sprite> _sprites = {};
  bool _disposed = false;

  Rect toScreen(Rect r) => Rect.fromLTWH(ox + r.left * s, oy + r.top * s, r.width * s, r.height * s);

  void enter(Canvas c) {
    c.save();
    c.translate(ox, oy);
    c.scale(s);
  }

  void _buildStatic() {
    skyPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(273.6, 163.8),
        674.2,
        const [SplashInk.skyCore, SplashInk.skyPeach, SplashInk.skyPink, SplashInk.skyViolet, SplashInk.skyIndigo, SplashInk.night],
        const [0, 0.13, 0.26, 0.44, 0.64, 1],
      );
    rayPaint = Paint()
      ..shader = ui.Gradient.radial(Offset.zero, 212.13, const [SplashInk.ray, SplashInk.ray, SplashInk.clearWhite], const [0, 0.08, 0.68]);
    rays = Path();
    final wedge = Rect.fromCircle(center: Offset.zero, radius: 150);
    for (var a = 0.0; a < 360; a += 22) {
      final sweep = math.min(7.0, 360 - a);
      rays
        ..moveTo(0, 0)
        ..arcTo(wedge, (a - 90) * math.pi / 180, sweep * math.pi / 180, false)
        ..close();
    }

    rangeFar = _range(const [0, 38, 9, 14, 19, 44, 29, 26, 40, 66, 50, 88, 60, 66, 70, 22, 81, 46, 91, 12, 100, 40], 196, 130);
    rangeMid = _range(const [0, 30, 13, 8, 26, 46, 38, 30, 46, 74, 50, 90, 54, 74, 64, 24, 77, 50, 88, 16, 100, 44], 226, 100);

    hazeRect = Rect.fromLTRB(vis.left - 1, 268, vis.right + 1, 345);
    hazePaint = Paint()..shader = ui.Gradient.linear(const Offset(0, 268), const Offset(0, 328), const [SplashInk.hazeClear, SplashInk.haze]);

    ground = _ground();
    groundPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 312),
        const Offset(0, 780),
        const [SplashInk.groundTeal, SplashInk.groundBlue, SplashInk.groundIndigo, SplashInk.night],
        const [0, 0.08, 0.44, 1],
      );

    roadEdge = _band(4);
    roadFill = _band(0);
    edgePaint = Paint()..color = SplashInk.roadEdge.withValues(alpha: 0.5);
    fillPaint = Paint()..color = SplashInk.roadFill;
    dots = [
      for (var d = 10.0; d < _road.length - 4; d += 15)
        (_road.at(d), 0.5 + 1.7 * _Road.depth(_road.at(d).dy), d),
    ];

    final rec = ui.PictureRecorder();
    _drawTree(Canvas(rec));
    treePicture = rec.endRecording();

    bird = _svgPath('M1 8Q7 0 13 7Q19 0 25 8');
    trailPaint = Paint()..shader = ui.Gradient.linear(const Offset(-140, 0), Offset.zero, const [SplashInk.clearWhite, SplashInk.trail]);

    scrimRect = Rect.fromLTRB(vis.left - 1, math.min(vis.top - 1, 0), vis.right + 1, 190);
    scrimPaint = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, 190), const [SplashInk.scrimTop, SplashInk.scrimMid, SplashInk.scrimClear], const [0, 0.45, 1]);

    final w = size.width, h = size.height;
    final ry = h * math.sqrt(0.45 * 0.45 + 0.55 * 0.55);
    final rx = ry * (w / 2) / (0.45 * h);
    final cx = w / 2, cy = 0.45 * h;
    vignettePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        ry,
        const [SplashInk.vignetteClear, SplashInk.vignetteClear, SplashInk.vignette],
        const [0, 0.55, 1],
        TileMode.clamp,
        Float64List.fromList([rx / ry, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, cx - cx * rx / ry, 0, 0, 1]),
      );

    final layout = _TitleLayout();
    titleRect = layout.bounds;
    layout.dispose();
  }

  Path _range(List<double> pts, double top, double height) {
    final p = Path();
    final k0 = (vis.left / _artW).floor() - 1;
    final k1 = (vis.right / _artW).floor() + 1;
    var first = true;
    for (var k = k0; k <= k1; k++) {
      final mirror = k.isOdd;
      final n = pts.length ~/ 2;
      for (var j = 0; j < n; j++) {
        final idx = mirror ? n - 1 - j : j;
        if (!first && j == 0) continue;
        final px = mirror ? 100 - pts[idx * 2] : pts[idx * 2];
        final o = Offset(k * _artW + px * _artW / 100, top + pts[idx * 2 + 1] * height / 100);
        if (first) {
          p.moveTo(o.dx, o.dy);
          first = false;
        } else {
          p.lineTo(o.dx, o.dy);
        }
      }
    }
    p
      ..lineTo((k1 + 1) * _artW, 345)
      ..lineTo(k0 * _artW, 345)
      ..close();
    return p;
  }

  Path _ground() {
    double top(double x) {
      final u = (x - 180) / 230.4;
      return 338 - 26 * math.sqrt(math.max(0, 1 - u * u));
    }

    final y0 = top(0);
    const flat = 333.05;
    final xl = math.min(vis.left, -160.0) - 1;
    final xr = math.max(vis.right, 520.0) + 1;
    final yb = math.max(vis.bottom, _artH) + 1;
    final p = Path()
      ..moveTo(xl, flat)
      ..lineTo(-160, flat)
      ..cubicTo(-106.7, flat, -53.3, 329.28, 0, y0);
    for (var x = 3.0; x < 360; x += 3) {
      p.lineTo(x, top(x));
    }
    p
      ..lineTo(360, y0)
      ..cubicTo(413.3, 329.28, 466.7, flat, 520, flat)
      ..lineTo(xr, flat)
      ..lineTo(xr, yb)
      ..lineTo(xl, yb)
      ..close();
    return p;
  }

  Path _band(double extra) {
    const n = 160;
    final a = <Offset>[], b = <Offset>[];
    final len = _road.length;
    for (var i = 0; i <= n; i++) {
      final l = i / n * len;
      final p = _road.at(l), q = _road.at(math.min(len, l + 1)), r = _road.at(math.max(0, l - 1));
      final dx = q.dx - r.dx, dy = q.dy - r.dy;
      final m = math.sqrt(dx * dx + dy * dy);
      final mm = m == 0 ? 1 : m;
      final nx = -dy / mm, ny = dx / mm;
      final h = (3 + 43 * math.pow(_Road.depth(p.dy), 1.15)) / 2 + extra;
      a.add(Offset(p.dx + nx * h, p.dy + ny * h));
      b.add(Offset(p.dx - nx * h, p.dy - ny * h));
    }
    return Path()..addPolygon([...a, ...b.reversed], true);
  }

  _Sprite? sprite(String key, _Sprite Function() make) {
    if (_disposed) return null;
    return _sprites[key] ??= make();
  }

  _Sprite? imageSprite(String key, ui.Image? image, Rect box, List<_Fx> fx) {
    if (image == null) return null;
    return sprite(
      key,
      () => _bake(Rect.fromLTWH(0, 0, box.width, box.height), res, (c) {
        c.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(0, 0, box.width, box.height),
          Paint()..filterQuality = FilterQuality.high,
        );
      }, fx: fx),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final sp in _sprites.values) {
      sp.image.dispose();
    }
    _sprites.clear();
    treePicture.dispose();
  }
}

Paint _imgPaint([double alpha = 1]) => Paint()
  ..filterQuality = FilterQuality.medium
  ..color = SplashInk.white.withValues(alpha: _clamp01(alpha));

void _popDraw(Canvas c, Rect box, double u, void Function(Paint p) draw) {
  final p = _pop(u);
  if (p.scale <= 0.001 || p.alpha <= 0) return;
  final cx = box.center.dx, cy = box.center.dy;
  c.save();
  c.translate(cx, cy);
  c.scale(p.scale);
  c.translate(-cx, p.dy - cy);
  draw(_imgPaint(p.alpha));
  c.restore();
}

double _alt(double a, double period, double delay, {bool reverse = false}) {
  final t = math.max(0.0, a - delay) / period;
  final n = t.floor();
  var p = t - n;
  if (n.isOdd != reverse) p = 1 - p;
  return Curves.easeInOut.transform(p);
}

double _twinkle(double a, double delay) {
  if (a < delay) return 0.5;
  final p = ((a - delay) % 2.4) / 2.4;
  return p < 0.5 ? 0.5 - 0.4 * Curves.ease.transform(p * 2) : 0.1 + 0.4 * Curves.ease.transform(p * 2 - 1);
}

double _float(double a) {
  final p = (a % 4) / 4;
  return p < 0.5 ? -7 * Curves.ease.transform(p * 2) : -7 * (1 - Curves.ease.transform(p * 2 - 1));
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.g, this.intro, this.ambient) : super(repaint: Listenable.merge([intro, ambient]));

  final _Geo g;
  final Animation<double> intro;
  final Animation<double> ambient;

  @override
  void paint(Canvas canvas, Size size) {
    final a = ambient.value * _ambientPeriod.inMilliseconds / 1000;
    final ms = intro.value * _introMs;
    final c = canvas;
    g.enter(c);
    c.drawRect(g.vis.inflate(1), g.skyPaint);

    c.save();
    c.translate(290, 194);
    c.rotate(2 * math.pi * ((a / 50) % 1));
    c.drawPath(g.rays, g.rayPaint);
    c.restore();

    final star = Paint();
    for (final (x, y, d) in _stars) {
      star.color = SplashInk.white.withValues(alpha: _twinkle(a, d));
      c.drawCircle(Offset(x + 1.5, y + 1.5), 1.5, star);
    }

    final cloud = g.sprite('cloud', () => _bakeCloud(g.res));
    if (cloud != null) {
      c.save();
      c.translate(96 - 18 + 48 * _alt(a, 11, 0), 190);
      cloud.draw(c, _imgPaint(0.9));
      c.restore();
      c.save();
      c.translate(196 - 18 + 48 * _alt(a, 14, 0, reverse: true) + 32, 262 + 11);
      c.scale(0.7);
      c.translate(-32, -11);
      cloud.draw(c, _imgPaint(0.7));
      c.restore();
    }

    final birdPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = SplashInk.bird.withValues(alpha: 0.85);
    for (final (x, y, w, h, stroke, flapDelay, flyDelay) in _birds) {
      final f = _alt(a, 9, flyDelay);
      final sy = 1 - 0.45 * _alt(a, 0.9, flapDelay);
      final k = math.min(w / 26, h / 12);
      c.save();
      c.translate(x - 14 + 48 * f + w / 2, y + 6 - 14 * f + h / 2);
      c.scale(1, sy);
      c.translate(-w / 2 + (w - 26 * k) / 2, -h / 2 + (h - 12 * k) / 2);
      c.scale(k);
      birdPaint.strokeWidth = stroke;
      c.drawPath(g.bird, birdPaint);
      c.restore();
    }

    final sun = g.sprite('sun', () => _bakeSun(g.res));
    if (sun != null) {
      c.save();
      c.translate(236, 136 + _float(a));
      sun.draw(c, _imgPaint());
      c.restore();
    }

    final f = (ms - _planeStart) / _planeMs;
    if (f > 0 && f < 1) {
      final e = _flyCurve.transform(f);
      final x0 = math.min(-110.0, g.vis.left - 110);
      final x1 = math.max(450.0, g.vis.right + 4);
      final left = x0 + (x1 - x0) * e;
      final top = 214 + (left + 110) * (-90 / 560);
      final rot = (-3 - 5 * e) * math.pi / 180;
      final dx = left + 110, dy = top - 214;
      c.save();
      c.translate(-100 + dx, 232.5 + dy);
      c.rotate(rot);
      c.drawRRect(RRect.fromLTRBR(-140, -1.5, 0, 1.5, const Radius.circular(1.5)), g.trailPaint);
      c.restore();
      final plane = g.sprite('plane', () => _bakeVector(const Size(104, 38), const Size(120, 44), g.res, _drawPlane, const [_Fx(0, 6, 3, SplashInk.planeShadow)]));
      if (plane != null) {
        c.save();
        c.translate(left + 52, top + 19);
        c.rotate(rot);
        c.translate(-52, -19);
        plane.draw(c, _imgPaint());
        c.restore();
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.g != g;
}

class _LandPainter extends CustomPainter {
  _LandPainter(this.g, this.intro, this.tick, this.images) : super(repaint: Listenable.merge([intro, tick]));

  final _Geo g;
  final Animation<double> intro;
  final Listenable tick;
  final Map<String, ImageInfo> images;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = intro.value * _introMs;
    final c = canvas;
    g.enter(c);
    c.drawPath(g.rangeFar, Paint()..color = SplashInk.rangeFar.withValues(alpha: 0.5));
    c.drawPath(g.rangeMid, Paint()..color = SplashInk.rangeMid.withValues(alpha: 0.85));

    final mountain = images[ListingArt.mountain]?.image;
    for (var i = 0; i < _mountains.length; i++) {
      final box = _mountains[i];
      final sp = g.imageSprite('mountain$i', mountain, box, const [_Fx(0, 8, 5, SplashInk.mountainShadow)]);
      if (sp == null) continue;
      final dir = _mountainExtend[i];
      final a = box.width * 25 / 256, b = box.width * 231 / 256;
      final step = b - a - 1;
      _popDraw(c, box, (ms - _mountainStart[i]) / _popMs, (p) {
        if (dir != 0) {
          for (var k = 1;; k++) {
            final left = box.left + dir * step * k;
            if (dir < 0 ? left + b < g.vis.left : left + a > g.vis.right) break;
            c.save();
            if (k.isOdd) {
              c.translate(left + box.width, box.top);
              c.scale(-1, 1);
            } else {
              c.translate(left, box.top);
            }
            c.clipRect(Rect.fromLTRB(a, sp.rect.top, b, sp.rect.bottom));
            sp.draw(c, p);
            c.restore();
          }
        }
        c.save();
        c.translate(box.left, box.top);
        if (dir != 0) {
          c.clipRect(Rect.fromLTRB(dir < 0 ? a : sp.rect.left, sp.rect.top, dir < 0 ? sp.rect.right : b, sp.rect.bottom));
        }
        sp.draw(c, p);
        c.restore();
      });
    }

    c.drawRect(g.hazeRect, g.hazePaint);
    c.drawPath(g.ground, g.groundPaint);

    for (final t in _trees) {
      final u = Curves.ease.transform(_clamp01((ms - _mockToApp(t.delay)) / _treeMs));
      if (u <= 0) continue;
      final k = math.min(t.w / 30, t.h / 48);
      c.save();
      c.translate(t.x + (t.w - 30 * k) / 2, t.y + (t.h - 48 * k) / 2 + 14 * (1 - u));
      c.scale(k);
      if (u < 1) c.saveLayer(const Rect.fromLTWH(-2, -2, 34, 52), _imgPaint(u));
      c.drawPicture(g.treePicture);
      if (u < 1) c.restore();
      c.restore();
    }

    c.drawPath(g.roadEdge, g.edgePaint);
    c.drawPath(g.roadFill, g.fillPaint);
    if (ms >= _driveStart) {
      final l = _easeQuad(_clamp01((ms - _driveStart) / _driveMs)) * _road.length;
      final dot = Paint()..color = SplashInk.white;
      for (final (pos, r, d) in g.dots) {
        if (d > l) break;
        c.drawCircle(pos, r, dot);
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_LandPainter old) => old.g != g;
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.g, this.intro, this.tick, this.images) : super(repaint: Listenable.merge([intro, tick]));

  final _Geo g;
  final Animation<double> intro;
  final Listenable tick;
  final Map<String, ImageInfo> images;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = intro.value * _introMs;
    final c = canvas;
    g.enter(c);

    for (var i = 0; i < _shadows.length; i++) {
      final box = _shadows[i];
      final sp = g.sprite('sh$i', () => _bake(Rect.fromLTWH(0, 0, box.width, box.height), g.res, (cc) {
            cc.drawOval(Rect.fromLTWH(0, 0, box.width, box.height), Paint()..color = SplashInk.shade);
          }, fx: const [_Fx(0, 0, 4)], keepSource: false));
      if (sp == null) continue;
      c.save();
      c.translate(box.left, box.top);
      sp.draw(c, _imgPaint(0.45));
      c.restore();
    }

    final ring = Paint()..style = PaintingStyle.stroke;
    for (var i = 0; i < _rings.length; i++) {
      final u = (ms - _road.showAt[i]) / _ringMs;
      if (u <= 0 || u >= 1) continue;
      final e = Curves.easeOut.transform(u);
      final sc = 0.4 + 1.1 * e;
      final box = _rings[i];
      ring
        ..strokeWidth = 3 * sc
        ..color = SplashInk.ring.withValues(alpha: SplashInk.ring.a * 0.9 * (1 - e));
      c.drawCircle(box.center, (box.width / 2 - 1.5) * sc, ring);
    }

    const iconShadow = [_Fx(0, 8, 4, SplashInk.iconShadow)];
    final sprites = <_Sprite?>[
      g.imageSprite('luggage', images[ListingArt.luggage]?.image, _icons[0], iconShadow),
      g.sprite('homestay', () => _bakeVector(const Size(102, 85), const Size(120, 100), g.res, _drawHomestay, iconShadow)),
      g.sprite('booking', () => _bakeVector(const Size(94, 66), const Size(120, 84), g.res, _drawBooking, iconShadow)),
      g.imageSprite('beach', images[ListingArt.beach]?.image, _icons[3], iconShadow),
      g.imageSprite('pushpin', images[ListingArt.pushpin]?.image, _icons[4], iconShadow),
    ];
    for (var i = 0; i < _icons.length; i++) {
      final sp = sprites[i];
      if (sp == null) continue;
      final box = _icons[i];
      _popDraw(c, box, (ms - _road.showAt[i]) / _popMs, (p) {
        c.save();
        c.translate(box.left, box.top);
        sp.draw(c, p);
        c.restore();
      });
    }

    if (ms >= _driveStart) {
      final k = _easeQuad(_clamp01((ms - _driveStart) / _driveMs));
      final alpha = k > 0.93 ? math.max(0.0, (1 - k) / 0.07) : 1.0;
      final car = alpha > 0 ? g.sprite('car', () => _bakeVector(const Size(66, 35), const Size(120, 64), g.res, _drawCar, const [_Fx(0, 6, 2.5, SplashInk.carShadow)])) : null;
      if (car != null) {
        final l = k * _road.length;
        final p = _road.at(l), q = _road.at(math.min(_road.length, l + 3));
        final sc = 0.4 + 0.6 * _Road.depth(p.dy);
        final face = (q.dx - p.dx) > 0 ? 1.0 : -1.0;
        c.save();
        c.translate(p.dx, p.dy - 12.5);
        c.scale(face * sc, sc);
        c.translate(-33, -17.5);
        car.draw(c, _imgPaint(alpha));
        c.restore();
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.g != g;
}

class _TopPainter extends CustomPainter {
  _TopPainter(this.g, this.intro) : super(repaint: intro);

  final _Geo g;
  final Animation<double> intro;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = intro.value * _introMs;
    final c = canvas;
    g.enter(c);
    c.drawRect(g.scrimRect, g.scrimPaint);
    final u = Curves.ease.transform(_clamp01((ms - _titleStart) / _titleMs));
    if (u > 0) {
      final title = g.sprite('title', () => _bakeTitle(g.res));
      if (title != null) {
        c.save();
        c.translate(0, 14 * (1 - u));
        title.draw(c, _imgPaint(u));
        c.restore();
      }
    }
    c.restore();
    c.drawRect(Offset.zero & size, g.vignettePaint);
  }

  @override
  bool shouldRepaint(_TopPainter old) => old.g != g;
}

// Title block in mock units: "Bakhli" line box at top 40, tagline pill 8 below it.
class _TitleLayout {
  _TitleLayout() {
    title = TextPainter(
      text: const TextSpan(
        text: _brand,
        style: TextStyle(
          fontFamily: TypeTokens.family,
          fontSize: 56,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          height: 1.1,
          leadingDistribution: TextLeadingDistribution.even,
          color: SplashInk.white,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    tag = TextPainter(
      text: const TextSpan(
        text: _tagline,
        style: TextStyle(
          fontFamily: TypeTokens.family,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          height: 1.4,
          leadingDistribution: TextLeadingDistribution.even,
          color: SplashInk.white,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    titleAt = Offset(_artW / 2 - title.width / 2, 40);
    final pw = tag.width + 36 + 2, ph = tag.height + 10 + 2;
    pill = Rect.fromLTWH(_artW / 2 - pw / 2, 40 + title.height + 8, pw, ph);
    tagAt = Offset(pill.left + 19, pill.top + 6);
    bounds = (titleAt & title.size).expandToInclude(pill);
  }

  late final TextPainter title, tag;
  late final Offset titleAt, tagAt;
  late final Rect pill, bounds;

  void dispose() {
    title.dispose();
    tag.dispose();
  }
}

_Sprite _bakeTitle(double res) {
  final l = _TitleLayout();
  final region = l.bounds.inflate(4);
  final text = _bake(region, res, (c) => l.title.paint(c, l.titleAt), fx: const [
    _Fx(0, 2, 0, SplashInk.titleEdge),
    _Fx(0, 5, 0, SplashInk.titleDrop),
    _Fx(0, 10, 13, SplashInk.titleGlow),
  ]);
  final tag = _bake(region, res, (c) => l.tag.paint(c, l.tagAt), fx: const [_Fx(0, 1, 1.5, SplashInk.taglineShadow)]);
  final pill = RRect.fromRectAndRadius(l.pill, const Radius.circular(18));
  final out = _bake(text.rect.expandToInclude(tag.rect), res, (c) {
    text.draw(c, Paint());
    c.drawRRect(pill, Paint()..color = SplashInk.taglineFill);
    c.drawRRect(
      pill.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = SplashInk.taglineBorder,
    );
    tag.draw(c, Paint());
  });
  text.image.dispose();
  tag.image.dispose();
  l.dispose();
  return out;
}

_Sprite _bakeCloud(double res) {
  const box = Rect.fromLTWH(0, 0, 64, 22);
  final rr = RRect.fromRectAndRadius(box, const Radius.circular(11));
  final base = _bake(box, res, (c) => c.drawRRect(rr, Paint()..color = SplashInk.white), fx: const [_Fx(0, 4, 5, SplashInk.cloudGlow)]);
  final out = _bake(const Rect.fromLTRB(0, -22, 64, 22).expandToInclude(base.rect), res, (c) {
    base.draw(c, Paint());
    final p = Paint()..color = SplashInk.white;
    c.drawCircle(const Offset(25, 0), 15, p);
    c.drawCircle(const Offset(45, -3), 19, p);
  });
  base.image.dispose();
  return out;
}

_Sprite _bakeSun(double res) {
  final core = _bake(const Rect.fromLTWH(0, 0, 112, 112), res, (c) {
    c.scale(1.12);
    _drawSun(c);
  }, fx: const [_Fx(0, 0, 10, SplashInk.sunGlow)]);
  final out = _bake(core.rect, res, (c) => core.draw(c, Paint()), fx: const [_Fx(0, 0, 23, SplashInk.sunGlowOuter)]);
  core.image.dispose();
  return out;
}

// SVG element of [box] px showing a [view] viewBox with preserveAspectRatio meet.
_Sprite _bakeVector(Size box, Size view, double res, void Function(Canvas c) draw, List<_Fx> fx) {
  final k = math.min(box.width / view.width, box.height / view.height);
  return _bake(Offset.zero & box, res, (c) {
    c.translate((box.width - view.width * k) / 2, (box.height - view.height * k) / 2);
    c.scale(k);
    draw(c);
  }, fx: fx);
}

// Minimal SVG path-data reader: M L H V C S Q T A Z, absolute and relative.
Path _svgPath(String d) {
  final tokens = RegExp(r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?').allMatches(d).map((m) => m.group(0)!).toList();
  final path = Path();
  var i = 0;
  var cmd = 'M';
  var x = 0.0, y = 0.0, sx = 0.0, sy = 0.0, cx = 0.0, cy = 0.0;
  var last = '';
  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
    switch (cmd.toUpperCase()) {
      case 'M':
        x = ox + n();
        y = oy + n();
        path.moveTo(x, y);
        sx = x;
        sy = y;
        cmd = rel ? 'l' : 'L';
      case 'L':
        x = ox + n();
        y = oy + n();
        path.lineTo(x, y);
      case 'H':
        x = ox + n();
        path.lineTo(x, y);
      case 'V':
        y = oy + n();
        path.lineTo(x, y);
      case 'C':
        final x1 = ox + n(), y1 = oy + n();
        cx = ox + n();
        cy = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, cx, cy, x, y);
      case 'S':
        final rx = (last == 'C' || last == 'S') ? 2 * x - cx : x;
        final ry = (last == 'C' || last == 'S') ? 2 * y - cy : y;
        cx = ox + n();
        cy = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(rx, ry, cx, cy, x, y);
      case 'Q':
        cx = ox + n();
        cy = oy + n();
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(cx, cy, x, y);
      case 'T':
        cx = (last == 'Q' || last == 'T') ? 2 * x - cx : x;
        cy = (last == 'Q' || last == 'T') ? 2 * y - cy : y;
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(cx, cy, x, y);
      case 'A':
        final rx = n(), ry = n(), rot = n(), large = n() != 0, sweep = n() != 0;
        x = ox + n();
        y = oy + n();
        path.arcToPoint(Offset(x, y), radius: Radius.elliptical(rx, ry), rotation: rot, largeArc: large, clockwise: sweep);
      case 'Z':
        path.close();
        x = sx;
        y = sy;
    }
    last = cmd.toUpperCase();
  }
  return path;
}

Float64List _bbMatrix(Rect bb) => Float64List.fromList([bb.width, 0, 0, 0, 0, bb.height, 0, 0, 0, 0, 1, 0, bb.left, bb.top, 0, 1]);

Paint _vert(Rect bb, List<Color> colors, [List<double>? stops]) =>
    Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, 1), colors, stops, TileMode.clamp, _bbMatrix(bb));

Paint _diag(Rect bb, List<Color> colors) =>
    Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(1, 1), colors, null, TileMode.clamp, _bbMatrix(bb));

Paint _fill(Color c, [double opacity = 1]) => Paint()..color = c.withValues(alpha: c.a * opacity);

Paint _stroke(Color c, double w, {double opacity = 1, StrokeCap cap = StrokeCap.butt, StrokeJoin join = StrokeJoin.miter}) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = cap
  ..strokeJoin = join
  ..color = c.withValues(alpha: c.a * opacity);

Path _poly(List<double> v) {
  final p = Path()..moveTo(v[0], v[1]);
  for (var i = 2; i < v.length; i += 2) {
    p.lineTo(v[i], v[i + 1]);
  }
  return p..close();
}

void _oval(Canvas c, double cx, double cy, double rx, double ry, Paint p) =>
    c.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), p);

RRect _rr(double x, double y, double w, double h, double r) => RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

void _drawSun(Canvas c) {
  c.drawCircle(
    const Offset(50, 50),
    50,
    Paint()..shader = ui.Gradient.radial(const Offset(50, 50), 50, const [SplashInk.sunHalo, SplashInk.sunHalo, SplashInk.sunHaloEdge], const [0, 0.55, 1]),
  );
  c.drawCircle(
    const Offset(50, 50),
    38,
    Paint()
      ..shader = ui.Gradient.radial(
        const Offset(0.38, 0.34),
        0.78,
        const [SplashInk.sunCore, SplashInk.sunYellow, SplashInk.sunOrange, SplashInk.sunRed, SplashInk.sunRim],
        const [0, 0.28, 0.6, 0.86, 1],
        TileMode.clamp,
        _bbMatrix(const Rect.fromLTWH(12, 12, 76, 76)),
      ),
  );
  c.save();
  c.translate(38, 35);
  c.rotate(-28 * math.pi / 180);
  _oval(c, 0, 0, 14, 8, _fill(SplashInk.white, 0.4));
  c.restore();
}

void _drawPlane(Canvas c) {
  final tail = _svgPath('M12 22 L5 3 L23 3 L36 18 Z');
  c.drawPath(tail, _vert(tail.getBounds(), const [SplashInk.planeTailTop, SplashInk.planeTailLow]));
  c.drawPath(_svgPath('M16 27 L3 31 L20 33 Z'), _fill(SplashInk.planeTailTop));
  final body = _svgPath('M8 24 C8 17 24 14 58 14 L96 14 C110 14 118 20 118 24 C118 28 110 32 96 32 L24 32 C14 32 8 29 8 24 Z');
  c.drawPath(body, _vert(const Rect.fromLTRB(8, 14, 118, 32), const [SplashInk.planeBody, SplashInk.planeBodyMid, SplashInk.planeBodyLow], const [0, 0.55, 1]));
  c.drawPath(_svgPath('M10 27.5 L116 27.5 L116 29 C112 31.4 104 32 96 32 L24 32 C16 32 11 30.5 10 28.5 Z'), _fill(SplashInk.planeStripe, 0.85));
  c.drawPath(_svgPath('M100 17.2 L109 19.6 C111 20.4 112 22 111.5 23 L100 23 Z'), _fill(SplashInk.planeCockpit));
  final win = _fill(SplashInk.planeWindow);
  for (var x = 30.0; x <= 84; x += 9) {
    c.drawCircle(Offset(x, 21.5), 2, win);
  }
  final wing = _svgPath('M50 27 L88 27 L62 43 L40 43 Z');
  c.drawPath(wing, _diag(wing.getBounds(), const [SplashInk.planeWingTop, SplashInk.planeWingLow]));
  _oval(c, 66, 34, 9, 4.6, _fill(SplashInk.planeEngine));
  _oval(c, 72, 34, 3, 3.6, _fill(SplashInk.planeEngineCore));
  _oval(c, 62, 16.5, 26, 2.6, _fill(SplashInk.white, 0.7));
}

void _drawTree(Canvas c) {
  _oval(c, 15, 46.5, 11, 2.4, _fill(SplashInk.shade, 0.35));
  c.drawRRect(_rr(13, 37, 4, 9, 1), _fill(SplashInk.treeTrunk));
  c.drawPath(_poly(const [15, 0, 26, 16, 4, 16]), _fill(SplashInk.treeTop));
  c.drawPath(_poly(const [15, 0, 15, 16, 4, 16]), _fill(SplashInk.treeTopLit, 0.6));
  c.drawPath(_poly(const [15, 9, 28, 29, 2, 29]), _fill(SplashInk.treeMid));
  c.drawPath(_poly(const [15, 9, 15, 29, 2, 29]), _fill(SplashInk.treeMidLit, 0.55));
  c.drawPath(_poly(const [15, 19, 30, 40, 0, 40]), _fill(SplashInk.treeLow));
  c.drawPath(_poly(const [15, 19, 15, 40, 0, 40]), _fill(SplashInk.treeLowLit, 0.5));
}

void _drawHomestay(Canvas c) {
  _oval(c, 60, 95, 52, 4, _fill(SplashInk.shade, 0.35));
  c.drawRRect(_rr(82, 12, 11, 26, 1.5), _fill(SplashInk.timber));
  c.drawCircle(const Offset(88, 8), 4, _fill(SplashInk.white, 0.6));
  c.drawCircle(const Offset(93, 2), 3, _fill(SplashInk.white, 0.4));
  c.drawRRect(_rr(18, 46, 84, 46, 4), _vert(const Rect.fromLTWH(18, 46, 84, 46), const [SplashInk.wallTop, SplashInk.wallLow]));
  final line = _stroke(SplashInk.wallLine, 1, opacity: 0.55);
  for (final y in const [56.0, 66.0, 76.0, 86.0]) {
    c.drawLine(Offset(18, y), Offset(102, y), line);
  }
  final roof = _poly(const [6, 50, 60, 10, 114, 50, 106, 54, 60, 20, 14, 54]);
  c.drawPath(roof, _vert(const Rect.fromLTRB(6, 10, 114, 54), const [SplashInk.roofTop, SplashInk.roofLow]));
  c.drawPath(_poly(const [6, 50, 60, 10, 60, 20, 14, 54]), _fill(SplashInk.roofLit, 0.35));
  final frame = _stroke(SplashInk.timber, 1.6);
  for (final wx in const [28.0, 74.0]) {
    final r = _rr(wx, 58, 20, 18, 2.5);
    c.drawRRect(r, _vert(Rect.fromLTWH(wx, 58, 20, 18), const [SplashInk.windowTop, SplashInk.windowLow]));
    c.drawRRect(r, _stroke(SplashInk.timber, 2));
    c.drawLine(Offset(wx + 10, 58), Offset(wx + 10, 76), frame);
    c.drawLine(Offset(wx, 67), Offset(wx + 20, 67), frame);
  }
  c.drawPath(_svgPath('M52 92 L52 72 Q52 64 60 64 Q68 64 68 72 L68 92 Z'), _fill(SplashInk.door));
  c.drawCircle(const Offset(64, 79), 1.5, _fill(SplashInk.knob));
  final grass = _stroke(SplashInk.grass, 2.4, cap: StrokeCap.round);
  c.drawPath(_svgPath('M4 94 q4 -7 8 0 q4 -8 8 0'), grass);
  c.drawPath(_svgPath('M96 94 q4 -7 8 0 q4 -8 8 0'), grass);
}

void _drawTaxiShapes(Canvas c, {required bool car}) {
  const yellow = [SplashInk.taxiTop, SplashInk.taxiMid, SplashInk.taxiLow];
  const yellowStops = [0.0, 0.6, 1.0];
  const glass = [SplashInk.glassTop, SplashInk.glassLow];
  final cabin = _svgPath('M26 28 L38 9 Q40 7 44 7 L84 7 Q88 7 90 10 L102 28 Z');
  c.drawPath(cabin, _vert(const Rect.fromLTRB(26, 7, 102, 28), yellow, yellowStops));
  final w1 = _svgPath('M32 26 L41 12 L58 12 L58 26 Z');
  c.drawPath(w1, _diag(w1.getBounds(), glass));
  final w2 = _svgPath('M63 26 L63 12 L82 12 L92 26 Z');
  c.drawPath(w2, _diag(w2.getBounds(), glass));
  c.drawRRect(_rr(52, 1, 18, 7, 2.5), _fill(SplashInk.white));
  if (car) {
    final tp = TextPainter(
      text: const TextSpan(
        text: 'TAXI',
        style: TextStyle(fontFamily: TypeTokens.family, fontSize: 5.2, fontWeight: FontWeight.w700, color: SplashInk.taxiText),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(c, Offset(61 - tp.width / 2, 6.6 - base));
    tp.dispose();
  }
  final body = _svgPath('M6 36 Q6 27 18 27 L104 27 Q116 27 116 36 L116 47 Q116 50 112 50 L10 50 Q6 50 6 47 Z');
  c.drawPath(body, _vert(const Rect.fromLTRB(6, 27, 116, 50), yellow, yellowStops));
  final check = _fill(SplashInk.checker);
  for (var x = 24.0; x <= 84; x += 10) {
    c.drawRect(Rect.fromLTWH(x, 34, 5, 5), check);
  }
  for (var x = 29.0; x <= 79; x += 10) {
    c.drawRect(Rect.fromLTWH(x, 39, 5, 5), check);
  }
  if (car) c.drawRect(const Rect.fromLTWH(60, 27, 1.4, 22), _fill(SplashInk.taxiSeam, 0.7));
  _oval(c, 113, 36, 4.5, 4, _fill(SplashInk.headlight));
  c.drawRRect(_rr(5, 33, 5, 8, 2), _fill(SplashInk.tailLight));
  if (car) c.drawPath(_svgPath('M12 28 Q60 24 108 28'), _stroke(SplashInk.white, 2, opacity: 0.5));
  for (final wx in const [32.0, 90.0]) {
    c.drawCircle(Offset(wx, 50), 10.5, _fill(SplashInk.wheel));
    c.drawCircle(Offset(wx, 50), 5, _fill(SplashInk.hub));
  }
}

void _drawCar(Canvas c) {
  _oval(c, 60, 60, 50, 3.4, _fill(SplashInk.shade, 0.35));
  _drawTaxiShapes(c, car: true);
}

void _drawBooking(Canvas c) {
  _oval(c, 60, 81, 50, 3.4, _fill(SplashInk.shade, 0.35));
  c.save();
  c.translate(120, 20);
  c.scale(-1, 1);
  _drawTaxiShapes(c, car: false);
  c.restore();
  c.save();
  c.translate(44, 0);
  c.drawRRect(_rr(0, 0, 46, 22, 11), _fill(SplashInk.white));
  c.drawPath(_svgPath('M18 21 L23 28 L28 21 Z'), _fill(SplashInk.white));
  c.drawPath(_svgPath('M13 11 m-5 0 a5 5 0 1 1 10 0 q0 5 -5 9 q-5 -4 -5 -9 z'), _fill(SplashInk.pinPink));
  c.drawCircle(const Offset(13, 10), 1.9, _fill(SplashInk.white));
  c.drawPath(_svgPath('M26 11.5 L31 16 L40 6'), _stroke(SplashInk.tickGreen, 3, cap: StrokeCap.round, join: StrokeJoin.round));
  c.restore();
}
