import 'package:bakhli/design/tokens/intro_story_colors.dart';
import 'package:bakhli/screens/intro/intro_widgets.dart';
import 'package:bakhli/screens/intro/story/intro_story_cast.dart';
import 'package:bakhli/screens/intro/story/intro_story_math.dart';
import 'package:bakhli/screens/intro/story/intro_story_state.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

CastFrame _cast(double q, {double t = 1.0}) {
  final f = CastFrame();
  solveCast(f, q: q, t: t, s: storyS(q), tl: List<double>.of(IntroStory.trailRestart), excited: 0);
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
