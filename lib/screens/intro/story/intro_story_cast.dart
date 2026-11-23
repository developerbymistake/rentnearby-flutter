import 'dart:math' as math;

import 'intro_story_math.dart';

class CastActor {
  double x = 0, y = 0, alpha = 1, sc = 1, tilt = 0, hop = 0, sx = 1, sy = 1, footL = 0, footR = 0, shadow = 1;
  bool walking = false, cel = false, fly = false, airborne = false, waiting = false, pose = false, inside = false;

  void reset() {
    x = IntroStory.door;
    y = IntroStory.groundY;
    alpha = 1;
    sc = 1;
    tilt = 0;
    hop = 0;
    sx = 1;
    sy = 1;
    footL = 0;
    footR = 0;
    shadow = 1;
    walking = cel = fly = airborne = waiting = pose = inside = false;
  }
}

class CastFrame {
  final List<CastActor> actors = [CastActor(), CastActor(), CastActor()];
  final List<int> order = [0, 1, 2, 3];
  final List<double> _depth = [0, 0, 0, 0];
  double canopy = 0, canopyX = 0, canopyY = 0, canopyTilt = 0;
  bool hasPandaPose = false;
  double pandaX = 0, pandaY = 0;

  static const int fire = 3;

  void _sortDepth() {
    for (var i = 0; i < 4; i++) {
      order[i] = i;
    }
    for (var i = 1; i < 4; i++) {
      final v = order[i];
      var j = i - 1;
      while (j >= 0 && _depth[order[j]] > _depth[v]) {
        order[j + 1] = order[j];
        j--;
      }
      order[j + 1] = v;
    }
  }
}

double _ease(double u) => u * u * (3 - 2 * u);

void _jumpIn(CastActor a, int i, double j, double fromX) {
  a.x = lerpD(fromX, IntroStory.slotX[i], _ease(j));
  a.y = lerpD(IntroStory.groundY, IntroStory.slotY + 14, j) - math.sin(j * math.pi) * 26;
  a.sc = lerpD(1, .6, j);
  a.alpha = 1 - clamp01((j - .7) * 3.3);
  a.tilt = lerpD(0, 8, j);
  a.airborne = true;
}

void _jumpOut(CastActor a, int i, double j, double toX) {
  a.x = lerpD(IntroStory.slotX[i], toX, _ease(j));
  a.y = lerpD(IntroStory.slotY + 14, IntroStory.groundY, j) - math.sin(j * math.pi) * 26;
  a.sc = lerpD(.6, 1, j);
  a.alpha = clamp01(j * 4);
  a.tilt = lerpD(-8, 0, j);
  a.airborne = true;
}

void solveCast(CastFrame out, {required double q, required double t, required double s, required List<double> tl, required double excited}) {
  const door = IntroStory.door;
  final trail = IntroTrail.instance;
  final glideX = 190 + math.sin(t * .45) * 70;
  final glideY = 208 + math.sin(t * .8) * 14;
  final boardT = clamp01((q - .02) / .36);
  final exitT = clamp01((q - 3.78) / .22);
  final selC = ((t % 3.4) + 3.4) % 3.4;
  out.canopy = 0;
  out.canopyTilt = 0;
  out.canopyX = 0;
  out.canopyY = 0;
  out.hasPandaPose = false;
  for (var i = 0; i < 3; i++) {
    final a = out.actors[i]..reset();
    final tb = clamp01((boardT - i * .18) / .6);
    if (q < 1.62) {
      if (tb >= .82) {
        _jumpIn(a, i, (tb - .82) / .18, door);
      } else {
        a.x = lerpD(IntroStory.startX[i], door, _ease(tb / .82));
        a.walking = tb > 0 && tb < .82;
        a.waiting = boardT == 0;
      }
      if (tb >= 1) a.alpha = 0;
      a.inside = tb >= 1;
    } else if (q < 2.05) {
      final l = clamp01((q - 1.62 - i * .04) / .30);
      if (l < .2) {
        _jumpOut(a, i, l / .2, door - 10 + i * 8);
      } else if (i == 0) {
        final u1 = clamp01((l - .2) / .35);
        if (l < .55) {
          a.x = lerpD(door - 10, IntroStory.launch, _ease(u1));
          a.walking = u1 < 1;
        } else {
          final f = clamp01((l - .55) / .45), ef = _ease(f);
          a.x = lerpD(IntroStory.launch, glideX, ef);
          a.y = lerpD(IntroStory.groundY, glideY + 8, ef);
          a.fly = true;
          out.canopy = smooth(f * 1.5);
          out.canopyTilt = math.cos(t * .45) * 7 * ef;
          a.tilt = out.canopyTilt;
        }
      } else {
        final u = clamp01((l - .2) / .8);
        double tu;
        if (u < .4) {
          a.x = lerpD(door - 10 + i * 8, IntroStory.trailX0, _ease(u / .4));
          a.walking = true;
          tu = 0;
        } else {
          tu = lerpD(0, i == 1 ? .1 : .42, _ease((u - .4) / .6));
          a.walking = true;
        }
        if (l >= .999 && q >= 1.98) {
          tu = tl[i] % 1;
          a.walking = true;
        }
        if (u >= .4 || l >= .999) {
          final pt = trail.at(tu);
          a.x = pt.dx - s;
          a.y = pt.dy;
          a.sc = lerpD(.62, .42, tu);
        }
        a.alpha *= 1 - clamp01((tu - .9) / .1);
      }
    } else if (q < 2.36) {
      final r = clamp01((q - 2.05 - i * .03) / .24);
      if (r < .75) {
        final u = r / .75;
        if (i == 0) {
          a.x = lerpD(glideX, door - 4, _ease(u));
          a.y = lerpD(glideY + 8, IntroStory.groundY, _ease(u));
          a.fly = u < .97;
          out.canopy = 1 - smooth(u / .85);
          out.canopyTilt = math.cos(t * .45) * 7 * (1 - u);
          a.tilt = out.canopyTilt;
        } else {
          final t0 = tl[i] % 1;
          if (u < .6) {
            final tu = t0 * (1 - _ease(u / .6));
            final pt = trail.at(tu);
            a.x = pt.dx - s;
            a.y = pt.dy;
            a.sc = lerpD(.62, .42, tu);
          } else {
            final w = _ease((u - .6) / .4);
            a.x = lerpD(IntroStory.trailX0, door - 6 + i * 6, w);
            a.y = IntroStory.groundY;
            a.sc = lerpD(.62, 1, w);
          }
          a.walking = true;
          a.alpha *= 1 - clamp01((t0 - .9) / .1) * (1 - clamp01(u / .3));
        }
      } else {
        _jumpIn(a, i, (r - .75) / .25, door - 6 + i * 6);
      }
      a.inside = r >= .97;
      if (i == 0 && r < .75) {
        out.canopyX = a.x;
        out.canopyY = a.y;
      }
    } else if (q < 3.78) {
      if (q < 2.74 || q >= 3.32) {
        a.alpha = 0;
        a.inside = true;
      } else if (q < 3.1) {
        final l = clamp01((q - 2.74 - i * .025) / .2);
        if (l < .25) {
          _jumpOut(a, i, l / .25, door - 10 + i * 8);
        } else {
          final u = (l - .25) / .75;
          a.x = lerpD(door - 2 + i * 8, IntroStory.poseX[i], _ease(u));
          a.walking = u < 1;
          a.pose = u >= 1;
        }
        a.inside = l < .1;
      } else {
        final b = clamp01((q - 3.1 - i * .025) / .16);
        if (b < .7) {
          a.x = lerpD(IntroStory.poseX[i], door - 6 + i * 6, _ease(b / .7));
          a.walking = true;
        } else {
          _jumpIn(a, i, (b - .7) / .3, door - 6 + i * 6);
        }
        a.inside = b >= .97;
      }
    } else {
      final te = clamp01((exitT - i * .2) / .62);
      if (te < .18) {
        _jumpOut(a, i, te / .18, door - 10 + i * 8);
      } else {
        final u = (te - .18) / .82;
        final ang = t * .8 + i * 2.094 + .3;
        final ox = 262 + math.cos(ang) * 62, oy = 432 + math.sin(ang) * 15;
        a.x = lerpD(door - 2 + i * 8, ox, _ease(u));
        a.y = lerpD(IntroStory.groundY, oy, _ease(u));
        a.walking = u < 1;
        a.cel = u >= 1;
        if (a.cel) a.sc = 1.12 + .12 * math.sin(ang);
      }
      a.inside = te < .12;
    }
    if (i == 0 && (a.fly || out.canopy > 0)) {
      out.canopyX = a.x;
      out.canopyY = a.y;
    }
    _motion(a, i, q, t, excited, selC);
    if (a.pose && i == 0) {
      out.hasPandaPose = true;
      out.pandaX = a.x;
      out.pandaY = a.y;
    }
    out._depth[i] = a.y + .2;
  }
  out._depth[CastFrame.fire] = IntroStory.groundY;
  out._sortDepth();
}

void _motion(CastActor a, int i, double q, double t, double excited, double selC) {
  final dir = q >= 3.78 ? 1.0 : (q < 1.62 ? -1.0 : (q < 2.05 ? 1.0 : -1.0));
  final ph = a.x * .115 + i * .7;
  var hop = 0.0, sx = 1.0, sy = 1.0;
  if (a.walking) {
    final s = math.sin(ph * math.pi).abs();
    final land = math.pow(1 - s, 3).toDouble();
    hop = s * 9 * a.sc;
    sy = 1 - .13 * land;
    sx = 1 + .10 * land;
    a.tilt = dir * 5 * math.sin(ph * math.pi * 2);
  }
  if (a.waiting) {
    final br = math.sin(t * 2.4 + i);
    sy = 1 + .025 * br;
    sx = 1 - .02 * br;
    final look = -7 * (1 - excited) + math.sin(t * 1.3 + i) * 2 * (1 - excited);
    final cheer = math.sin(t * 5 + i * 1.1).abs() * 8 * excited;
    a.tilt = look + (i == 0 ? math.sin(t * 7) * 10 * excited : math.sin(t * 6 + i) * 5 * excited);
    hop = cheer + (i == 0 && excited < .05 ? math.max(0, math.sin(t * 3.2)) * 4 : 0);
    if (excited > .05) {
      sy = 1 - .04 * math.sin(t * 5 + i * 1.1);
      sx = 1 + .03 * math.sin(t * 5 + i * 1.1);
    }
  }
  if (a.cel) {
    final s = math.sin(t * 5 + i * 1.4).abs();
    final land = math.pow(1 - s, 3).toDouble();
    hop = s * 16;
    sy = 1 - .14 * land;
    sx = 1 + .12 * land;
    a.tilt = math.sin(t * 5 + i * 1.4) * 12;
  }
  if (a.pose) {
    final sq = smooth((selC - 1.3) / .9) * (selC < 2.4 ? 1 : 0);
    final fh = selC > 2.4 && selC < 2.95 ? math.sin((selC - 2.4) / .55 * math.pi) * 9 : 0.0;
    final br = math.sin(t * 2.6 + i);
    a.x = IntroStory.poseX[i] + (i == 0 ? 1 : (i == 2 ? -1 : 0)) * (sq * 6);
    hop = fh;
    a.tilt = const [9.0, 0.0, -9.0][i] * (1 - sq * .3) + math.sin(t * 3 + i) * 1.5;
    sx = 1 + .025 * br + (fh > 0 ? .05 : 0);
    sy = 1 - .025 * br - (fh > 0 ? .05 : 0);
  }
  a.hop = hop;
  a.sx = sx;
  a.sy = sy;
  a.footL = a.walking ? math.max(0, math.sin(ph * math.pi * 2)) * 3.5 : (a.fly ? 2 + math.sin(t * 4) * 3 : 0);
  a.footR = a.walking ? math.max(0, -math.sin(ph * math.pi * 2)) * 3.5 : (a.fly ? 2 + math.sin(t * 4 + 1.5) * 3 : 0);
  a.shadow = a.fly ? 0 : (1 - hop / 36) * a.sc;
}
