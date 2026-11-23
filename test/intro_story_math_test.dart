import 'package:bakhli/design/tokens/intro_story_colors.dart';
import 'package:bakhli/screens/intro/intro_widgets.dart';
import 'package:bakhli/screens/intro/story/intro_story_cast.dart';
import 'package:bakhli/screens/intro/story/intro_story_math.dart';
import 'package:bakhli/screens/intro/story/intro_story_state.dart';
import 'package:bakhli/screens/intro/story/paint_cast.dart';
import 'package:bakhli/screens/intro/story/paint_table.dart';
import 'package:bakhli/screens/intro/story/paint_world.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

CastFrame _cast(double q, {double t = 1.0, double excited = 0}) {
  final f = CastFrame();
  solveCast(f, q: q, t: t, s: storyS(q), tl: List<double>.of(IntroStory.trailRestart), excited: excited);
  return f;
}

void main() {
  group('world scroll S(q)', () {
    test('keyframes', () {
      expect(storyS(0), 0);
      expect(storyS(.4), 0);
      expect(storyS(1), closeTo(450, 1e-9));
      expect(storyS(1.6), closeTo(900, 1e-9));
      expect(storyS(2), 900);
      expect(storyS(2.72), closeTo(1900, 1e-9));
      expect(storyS(3), 1900);
      expect(storyS(3.78), closeTo(3000, 1e-9));
      expect(storyS(4), 3000);
    });

    test('monotonic', () {
      var last = -1.0;
      for (var q = 0.0; q <= 4.0; q += .005) {
        final s = storyS(q);
        expect(s, greaterThanOrEqualTo(last), reason: 'q $q');
        last = s;
      }
    });

    test('q is P minus one, never below zero', () {
      expect(storyQ(0), 0);
      expect(storyQ(.6), 0);
      expect(storyQ(2.5), 1.5);
    });
  });

  group('palette', () {
    test('ends and clamp', () {
      final m = IntroPaletteMix()..update(0);
      expect(m.t, IntroStoryColors.palettes[0].t);
      expect(m.r, IntroStoryColors.palettes[0].r);
      m.update(4);
      expect(m.t, IntroStoryColors.palettes[4].t);
      m.update(5);
      expect(m.b, IntroStoryColors.palettes[4].b);
      expect(m.update(5), isFalse);
      m.update(1);
      expect(m.g, IntroStoryColors.palettes[1].g);
    });

    test('derived light curves', () {
      expect(nightOf(3.3), 0);
      expect(nightOf(4), 1);
      expect(idleWeightOf(1), 1);
      expect(idleWeightOf(1.4), closeTo(0, 1e-9));
      expect(confettiOf(3.9), 0);
      expect(confettiOf(4), closeTo(1, 1e-9));
      expect(beamOf(4), closeTo(0, 1e-9));
      expect(sunX(0), 30);
      expect(sunY(2), closeTo(90, 1e-9));
    });
  });

  group('table loop (chapter 1)', () {
    test('loop time wraps every 7.6 s', () {
      expect(IntroTablePainter.loopTime(8.6), closeTo(1.0, 1e-9));
      expect(IntroTablePainter.loopTime(-1), closeTo(6.6, 1e-9));
    });

    test('places drop at .5 / 1.7 / 2.9 s', () {
      expect(IntroTablePainter.dropOf(1.0, 0), closeTo(.5 / .55, 1e-9));
      expect(IntroTablePainter.dropOf(1.0, 1), 0);
      expect(IntroTablePainter.dropOf(1.0, 2), 0);
      expect([for (var i = 0; i < 3; i++) IntroTablePainter.dropOf(4.5, i)], [1, 1, 1]);
    });

    test('route draws 3.5..5.5 s, mini taxi rides it until 6.9 s, all fades 6.5..7.3 s', () {
      expect(IntroTablePainter.routeOf(3.5), 0);
      expect(IntroTablePainter.routeOf(4.5), closeTo(.5, 1e-9));
      expect(IntroTablePainter.routeOf(6.0), 1);
      expect(IntroTablePainter.miniTaxiOn(1.0), isFalse);
      expect(IntroTablePainter.miniTaxiOn(6.0), isTrue);
      expect(IntroTablePainter.miniTaxiOn(7.0), isFalse);
      expect(IntroTablePainter.fadeOf(6.0), 1);
      expect(IntroTablePainter.fadeOf(7.3), 0);
    });
  });

  group('pickup and boarding (chapter 2)', () {
    test('waiting friends glance left before the taxi, cheer after it parks', () {
      final calm = _cast(0, t: 2.0);
      expect(calm.actors.every((a) => a.tilt < 0), isTrue);
      final cheer = _cast(0, t: 2.0, excited: 1);
      expect(cheer.actors.any((a) => a.hop > 0), isTrue);
      expect(cheer.actors.every((a) => a.waiting), isTrue);
    });

    test('board stagger: panda in at q .25, fox at .33, lion at .37', () {
      expect([for (final a in _cast(.25).actors) a.inside], [true, false, false]);
      expect([for (final a in _cast(.33).actors) a.inside], [true, true, false]);
      expect([for (final a in _cast(.37).actors) a.inside], [true, true, true]);
    });

    test('frame 8 (P 1.2): panda in the air, fox and lion walking to the door', () {
      final f = _cast(.2);
      expect(f.actors[0].airborne, isTrue);
      expect(f.actors[0].sc, lessThan(1));
      expect(f.actors[1].walking, isTrue);
      expect(f.actors[1].x, lessThan(IntroStory.startX[1]));
      expect(f.actors[2].walking, isTrue);
      expect(f.actors[2].x, greaterThan(f.actors[1].x));
    });

    test('arrival: speed and lean while moving, parked and still at 3.6 s, slides off after P 1.05', () {
      final mid = IntroArrival.at(2.7, 1);
      expect(mid.speed, greaterThan(0));
      expect(mid.lean, greaterThan(0));
      final parked = IntroArrival.at(3.6, 1);
      expect(parked.dx, 0);
      expect(parked.lean, 0);
      expect(parked.excited, 1);
      expect(IntroArrival.at(0, 1.2).dx, 0);
      expect(IntroArrival.at(0, 1.2).excited, 0);
    });

    test('state: window heads follow the inside flags', () {
      final s = IntroStoryState()..setProgress(1.5);
      expect(s.cast.actors.every((a) => a.inside), isTrue);
      s.setProgress(1.0);
      expect(s.cast.actors.any((a) => a.inside), isFalse);
      s.dispose();
    });
  });

  group('cast phases', () {
    test('q .2 boarding: panda jumping in, lion walking, nobody inside', () {
      final f = _cast(.2);
      expect(f.actors[0].airborne, isTrue);
      expect(f.actors[2].walking, isTrue);
      expect(f.actors.any((a) => a.inside), isFalse);
    });

    test('q .5 all three inside the taxi', () {
      final f = _cast(.5);
      expect(f.actors.every((a) => a.inside), isTrue);
      expect(f.actors.every((a) => a.alpha == 0), isTrue);
    });

    test('q 0 waiting at the stop', () {
      final f = _cast(0);
      expect(f.actors.every((a) => a.waiting), isTrue);
      expect([for (final a in f.actors) a.x], IntroStory.startX);
    });

    test('q 1.8 panda takes off, trekkers walk to the trail', () {
      final f = _cast(1.8);
      expect(f.actors[0].fly, isTrue);
      expect(f.canopy, inExclusiveRange(0, .2));
      expect(f.actors[1].walking, isTrue);
      expect(f.actors.any((a) => a.inside), isFalse);
    });

    test('q 2.2 return: canopy almost closed, nobody inside', () {
      final f = _cast(2.2);
      expect(f.canopy, lessThan(.01));
      expect(f.actors.any((a) => a.inside), isFalse);
      expect(_cast(2.36).actors.every((a) => a.inside), isTrue);
    });

    test('q 3.0 selfie pose for all three', () {
      final f = _cast(3.0);
      expect(f.actors.every((a) => a.pose), isTrue);
      expect(f.hasPandaPose, isTrue);
      expect(_cast(3.32).actors.every((a) => a.inside), isTrue);
    });

    test('q 3.9 walking to the fire, no dance yet; q 4 front two dance', () {
      final f = _cast(3.9);
      expect(f.actors.any((a) => a.cel), isFalse);
      expect(f.actors[0].walking, isTrue);
      final g = _cast(4);
      expect(g.actors[0].cel, isTrue);
      expect(g.actors[1].cel, isTrue);
    });

    test('depth order puts the fire between back and front dancers', () {
      final f = _cast(4, t: 0);
      expect(f.order.toSet(), {0, 1, 2, CastFrame.fire});
    });
  });

  group('drive and adventure (chapters 3 and 4)', () {
    CastFrame cast(double q, double t, List<double> tl) {
      final f = CastFrame();
      solveCast(f, q: q, t: t, s: storyS(q), tl: tl, excited: 0);
      return f;
    }

    test('drive 1 (q .4..1.6) keeps all three inside, world scrolls to the mountain', () {
      for (final q in [.4, 1.0, 1.6]) {
        expect(_cast(q).actors.every((a) => a.inside && a.alpha == 0), isTrue);
      }
      expect(storyS(1.6), 900);
      expect(storyS(1.62), 900);
    });

    test('leave boundary q 1.62: all jump out of the window slots', () {
      final f = _cast(1.62);
      for (var i = 0; i < 3; i++) {
        final a = f.actors[i];
        expect(a.inside, isFalse);
        expect(a.airborne, isTrue);
        expect(a.x, closeTo(IntroStory.slotX[i], 1e-9));
        expect(a.sc, closeTo(.6, 1e-9));
      }
    });

    test('frame 11 (q 1.8): canopy opening over the panda, trekkers on the way', () {
      final f = _cast(1.8, t: 2);
      expect(f.canopy, greaterThan(IntroGlider.minCanopy));
      expect(f.canopyX, f.actors[0].x);
      expect(f.actors[0].shadow, 0);
      expect(f.actors[1].walking && f.actors[2].walking, isTrue);
    });

    test('frame 12 (q 2): panda at the glide point, fox and lion on the trail at .1 / .42', () {
      const t = 2.0;
      final f = cast(2, t, List<double>.of(IntroStory.trailRestart));
      final p = f.actors[0];
      expect(p.fly, isTrue);
      expect(f.canopy, 1);
      expect(p.x, closeTo(190 + 70 * 0.7833269096274834, 1e-9));
      expect(p.y, closeTo(208 + 14 * 0.9995736030415051 + 8, 1e-9));
      expect(f.canopyX, p.x);
      expect(f.canopyY, p.y);
      for (final i in [1, 2]) {
        final tu = IntroStory.trailRestart[i];
        final pt = IntroTrail.instance.at(tu);
        expect(f.actors[i].x, closeTo(pt.dx - 900, 1e-9));
        expect(f.actors[i].y, closeTo(pt.dy, 1e-9));
        expect(f.actors[i].sc, closeTo(.62 + (.42 - .62) * tu, 1e-9));
      }
      expect(f.actors.any((a) => a.inside), isFalse);
    });

    test('trail loop: trekkers fade near the top and wrap', () {
      final f = cast(2, 1, [0, .95, 1.2]);
      expect(f.actors[1].alpha, closeTo(.5, 1e-9));
      expect(f.actors[2].y, closeTo(IntroTrail.instance.at(.2).dy, 1e-9));
    });

    test('return: panda glides down, trekkers walk back, then all jump in by q 2.36', () {
      final f = _cast(2.05, t: 2);
      expect(f.actors[0].fly, isTrue);
      expect(f.canopy, 1);
      final g = _cast(2.2, t: 2);
      expect(g.actors[0].y, greaterThan(f.actors[0].y));
      expect(g.actors[1].y, IntroStory.groundY);
      expect(g.actors[1].sc, inExclusiveRange(.62, 1));
      expect(g.canopy, lessThan(IntroGlider.minCanopy));
      final h = _cast(2.36);
      expect(h.actors.every((a) => a.inside && a.alpha == 0), isTrue);
      expect(h.canopy, 0);
    });

    test('state: trail loop advances .07 per second on the adventure chapter only', () {
      final s = IntroStoryState()..setProgress(3);
      s.tick(.05);
      s.tick(.05);
      expect(s.tl[1], closeTo(.1 + .007, 1e-9));
      expect(s.tl[2], closeTo(.42 + .007, 1e-9));
      s.setProgress(3.2);
      final before = s.tl[1];
      s.tick(.05);
      expect(s.tl[1], before);
      s.dispose();
    });

    test('state: pitch stays within 3.5 deg while the world speeds up and settles at rest', () {
      final s = IntroStoryState()..setProgress(1.4);
      for (var i = 0; i < 4; i++) {
        s.setProgress(1.4 + i * .05);
        s.tick(.016);
        expect(s.pitch - s.arrival.lean, closeTo(s.pit.clamp(-3.5, 3.5), 1e-9));
        expect((s.pitch - s.arrival.lean).abs(), lessThanOrEqualTo(3.5));
      }
      s.setProgress(2);
      for (var i = 0; i < 200; i++) {
        s.tick(.016);
      }
      expect(s.pit.abs(), lessThan(.01));
      s.dispose();
    });

    test('mountain is in view only around the adventure chapter', () {
      bool inView(double s) => IntroMountain.x1 - s >= 0 && IntroMountain.x0 - s <= IntroStory.sceneW;
      expect(inView(storyS(1)), isFalse);
      expect(inView(storyS(2)), isTrue);
      expect(IntroMountain.cx - storyS(2), 300);
      expect(inView(storyS(2.72)), isFalse);
    });

    test('trail dots follow the dotted trail', () {
      final b = IntroMountain.trailDots().getBounds();
      expect(b.left, greaterThanOrEqualTo(1128 - 1));
      expect(b.right, lessThanOrEqualTo(1206 + 1));
      expect(b.top, greaterThanOrEqualTo(244 - 1));
      expect(b.bottom, lessThanOrEqualTo(390 + 1));
    });
  });

  group('taxi arrival', () {
    test('dx at 0 / 1.8 / 3.6 s', () {
      expect(IntroArrival.at(0, 1).dx, -320);
      expect(IntroArrival.at(1.8, 1).dx, closeTo(-40, 1e-9));
      expect(IntroArrival.at(3.6, 1).dx, 0);
      expect(IntroArrival.at(3.6, 1).excited, 1);
      expect(IntroArrival.at(-1, 1).speed, 0);
    });
  });

  group('state', () {
    test('arrival resets below P .6 and starts at P .9', () {
      final s = IntroStoryState()..setProgress(1);
      s.tick(.05);
      s.tick(.05);
      expect(s.arrT, greaterThan(0));
      s.setProgress(.5);
      expect(s.arrT, -1);
      s.dispose();
    });

    test('idle scroll only near chapter 2', () {
      final s = IntroStoryState()..setProgress(2);
      s.tick(.05);
      expect(s.idle, closeTo(85 * .05, 1e-9));
      s.setProgress(4);
      final before = s.idle;
      s.tick(.05);
      expect(s.idle, before);
      s.dispose();
    });

    test('trail loop runs only on the adventure chapter and restarts before it', () {
      final s = IntroStoryState()..setProgress(3);
      s.tick(.05);
      expect(s.tl[1], greaterThan(.1));
      s.setProgress(2.5);
      expect(s.tl, IntroStory.trailRestart);
      s.dispose();
    });

    test('freeze stops the clock', () {
      final s = IntroStoryState()..setProgress(2);
      s.debugFreeze(1.3);
      s.tick(.05);
      expect(s.time, 1.3);
      expect(s.idle, 0);
      expect(s.arrT, 0);
      s.dispose();
    });

    test('reduce motion: parked taxi and fixed time per chapter', () {
      final s = IntroStoryState()
        ..reduce = true
        ..setProgress(0);
      expect(s.time, 6);
      s.setProgress(1);
      expect(s.time, 3);
      expect(s.arrival.dx, 0);
      s.dispose();
    });
  });

  group('geometry', () {
    test('360 wide fills the width with the panel top at scene 460', () {
      final g = IntroStoryGeo.of(const Size(360, 760), 460);
      expect(g.k, 1);
      expect(g.ox, 0);
      expect(g.oy, 0);
      expect(g.slideUnits, 380);
    });

    test('short screen keeps 404 units of sky and centres the stage', () {
      final g = IntroStoryGeo.of(const Size(320, 568), 268);
      expect(g.k, closeTo(268 / 404, 1e-9));
      expect(g.ox, greaterThan(0));
      expect(g.vx0, lessThan(0));
      expect(g.slideUnits, greaterThan(380));
    });
  });

  group('trail and map', () {
    test('trail ends', () {
      expect(IntroTrail.instance.at(0), const Offset(1128, 390));
      expect(IntroTrail.instance.at(1), const Offset(1196, 244));
    });

    test('map corners', () {
      expect(IntroMapQuad.project(0, 0), IntroMapQuad.tl);
      expect(IntroMapQuad.project(1, 1), IntroMapQuad.br);
    });
  });

  test('spring curve ends at 0 and 1 and is mostly there by half time', () {
    const c = IntroSpringCurve();
    expect(c.transform(0), 0);
    expect(c.transform(1), 1);
    expect(c.transform(.5), greaterThan(.8));
  });
}
