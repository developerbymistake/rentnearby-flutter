import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../design/tokens/intro_story_colors.dart';

double clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

double lerpD(double a, double b, double t) => a + (b - a) * t;

double smooth(double t) {
  final c = clamp01(t);
  return c * c * (3 - 2 * c);
}

double easeE(double u) => .5 * u + .5 * smooth(u);

double backOut(double t) {
  final c = clamp01(t);
  const k = 1.70158;
  final m = c - 1;
  return 1 + (k + 1) * m * m * m + k * m * m;
}

abstract final class IntroStory {
  static const double sceneW = 360;
  static const double sceneH = 480;
  static const double panelTop = 460;
  static const double minSky = 56;
  static const double slideW = 380;
  static const double groundY = 426;
  static const double door = 146;
  static const double launch = 208;
  static const double trailX0 = 224;
  static const double arrivalSeconds = 3.6;
  static const double idleSpeed = 85;
  static const List<double> startX = [232, 266, 300];
  static const List<double> poseX = [238, 268, 298];
  static const List<double> slotX = [96, 118, 152];
  static const double slotY = 358;
  static const List<double> trailRestart = [0, .1, .42];
  static const double fireWorldX = 3262;
  static const double worldEnd = 3000;
}

double storyS(double q) {
  if (q < .4) return 0;
  if (q <= 1.6) return 900 * easeE((q - .4) / 1.2);
  if (q < 2.36) return 900;
  if (q <= 2.72) return 900 + 1000 * easeE((q - 2.36) / .36);
  if (q < 3.32) return 1900;
  if (q <= 3.78) return 1900 + 1100 * easeE((q - 3.32) / .46);
  return 3000;
}

double storyQ(double p) => math.max(0, p - 1);

double nightOf(double q) => smooth((q - 3.3) / .7);
double duskOf(double q) => smooth((q - 2.6) / .5);
double lampOf(double q) => smooth((q - 2.6) / .4);
double fireOnOf(double q) => smooth((q - 3.5) / .4);
double smokeGainOf(double q) => smooth((q - 2.3) / .5);
double confettiOf(double q) => clamp01((q - 3.93) / .07);
double idleWeightOf(double q) => clamp01(1 - (q - 1).abs() * 2.5);
double beamOf(double q) => clamp01(duskOf(q) * .85 + nightOf(q) * .3) * (1 - smooth((q - 3.74) / .06));
double sunX(double q) => 30 + q * 78;
double sunY(double q) => 300 - math.sin(clamp01(q / 4) * math.pi) * 210 + nightOf(q) * 20;

class IntroArrival {
  const IntroArrival(this.dx, this.lean, this.excited, this.speed);

  final double dx, lean, excited, speed;

  static IntroArrival at(double arrT, double p) {
    const ar = IntroStory.arrivalSeconds;
    final au = clamp01(arrT / ar);
    final ae = 1 - math.pow(1 - au, 3).toDouble();
    final keep = p < 1.05 ? 1.0 : 1 - smooth((p - 1.05) / .1);
    final dx = -320 * (1 - ae) * keep;
    final speed = arrT < 0 ? 0.0 : 3 * (1 - au) * (1 - au) * (320 / ar) * keep;
    final lean = au > 0 && au < 1 ? 2.8 * math.sin(clamp01((au - .5) / .5) * math.pi) : 0.0;
    final excited = clamp01((arrT - ar * .55) / .9) * (p < 1.05 ? 1 : 0);
    return IntroArrival(dx, lean, excited, speed);
  }
}

Color mixColor(Color a, Color b, double t) => Color.lerp(a, b, t)!;

class IntroPaletteMix {
  Color t = IntroStoryColors.palettes[0].t;
  Color b = IntroStoryColors.palettes[0].b;
  Color h1 = IntroStoryColors.palettes[0].h1;
  Color h1b = IntroStoryColors.palettes[0].h1b;
  Color h2 = IntroStoryColors.palettes[0].h2;
  Color h2b = IntroStoryColors.palettes[0].h2b;
  Color g = IntroStoryColors.palettes[0].g;
  Color r = IntroStoryColors.palettes[0].r;
  double _key = -1;

  bool update(double q) {
    const pal = IntroStoryColors.palettes;
    final i = q.floor().clamp(0, pal.length - 2);
    final k = clamp01(q - i);
    final e = smooth(k);
    final key = i + e;
    if (key == _key) return false;
    _key = key;
    final a = pal[i], c = pal[i + 1];
    t = mixColor(a.t, c.t, e);
    b = mixColor(a.b, c.b, e);
    h1 = mixColor(a.h1, c.h1, e);
    h1b = mixColor(a.h1b, c.h1b, e);
    h2 = mixColor(a.h2, c.h2, e);
    h2b = mixColor(a.h2b, c.h2b, e);
    g = mixColor(a.g, c.g, e);
    r = mixColor(a.r, c.r, e);
    return true;
  }
}

class IntroTrail {
  IntroTrail._(this.points, this.lengths);

  static const double cx = 1200, base = 396;
  static const List<List<double>> _rel = [[-72, -6], [-8, -24], [-60, -46], [2, -64], [-46, -86], [6, -104], [-28, -128], [-4, -152]];

  static final IntroTrail instance = _build();

  final List<Offset> points;
  final List<double> lengths;

  double get total => lengths.last;

  static IntroTrail _build() {
    final pts = [for (final r in _rel) Offset(cx + r[0], base + r[1])];
    final len = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      len.add(len[i - 1] + (pts[i] - pts[i - 1]).distance);
    }
    return IntroTrail._(pts, len);
  }

  Offset at(double u) {
    final l = clamp01(u) * total;
    var i = 1;
    while (i < lengths.length - 1 && lengths[i] < l) {
      i++;
    }
    final span = lengths[i] - lengths[i - 1];
    final k = span == 0 ? 0.0 : (l - lengths[i - 1]) / span;
    return Offset(lerpD(points[i - 1].dx, points[i].dx, k), lerpD(points[i - 1].dy, points[i].dy, k));
  }
}

abstract final class IntroMapQuad {
  static const Offset tl = Offset(72, 236), tr = Offset(288, 236), br = Offset(332, 338), bl = Offset(28, 338);

  static Offset project(double u, double v) {
    final a = Offset.lerp(tl, tr, u)!;
    final b = Offset.lerp(bl, br, u)!;
    return Offset.lerp(a, b, v)!;
  }
}

@immutable
class IntroStoryGeo {
  const IntroStoryGeo._(this.k, this.ox, this.oy, this.width, this.height);

  factory IntroStoryGeo.of(Size size, double panelTop) {
    var k = size.width / IntroStory.sceneW;
    var ox = 0.0;
    if (panelTop < (IntroStory.panelTop - IntroStory.minSky) * k) {
      k = panelTop / (IntroStory.panelTop - IntroStory.minSky);
      ox = (size.width - IntroStory.sceneW * k) / 2;
    }
    return IntroStoryGeo._(k, ox, panelTop - IntroStory.panelTop * k, size.width, size.height);
  }

  final double k, ox, oy, width, height;

  double get vx0 => -ox / k;
  double get vx1 => (width - ox) / k;
  double get vy0 => -oy / k;
  double get slideUnits => math.max(IntroStory.slideW, vx1 - vx0 + 20);
  double get slidePx => slideUnits * k;

  @override
  bool operator ==(Object other) =>
      other is IntroStoryGeo && other.k == k && other.ox == ox && other.oy == oy && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(k, ox, oy, width, height);
}
