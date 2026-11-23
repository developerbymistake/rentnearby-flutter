import 'package:bakhli/screens/intro/intro_scaffold.dart';
import 'package:bakhli/screens/intro/story/intro_story_art.dart';
import 'package:bakhli/screens/intro/story/intro_story_math.dart';
import 'package:bakhli/screens/intro/story/intro_story_scene.dart';
import 'package:bakhli/screens/intro/story/intro_story_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(360, 760);
const _layerNames = ['sky', 'hills', 'trees', 'world', 'fx', 'road', 'actors', 'table'];

Widget _app(Widget home, {bool reduce = false}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduce), child: child!),
      home: home,
    );

Future<void> _pumpIntro(WidgetTester tester, {bool reduce = false, bool autoplay = false, VoidCallback? onFinish}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(IntroScaffold(onFinish: onFinish ?? () {}, autoplay: autoplay), reduce: reduce));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

PageController _controller(WidgetTester tester) => tester.widget<PageView>(find.byType(PageView)).controller!;

IntroStoryState _story(WidgetTester tester) => tester.widget<IntroStoryScene>(find.byType(IntroStoryScene)).state;

Future<void> _jump(WidgetTester tester, int page) async {
  _controller(tester).jumpToPage(page);
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Map<String, int> _paintCounts(WidgetTester tester) {
  final boundaries = tester
      .renderObjectList<RenderRepaintBoundary>(find.descendant(of: find.byType(IntroStoryScene), matching: find.byType(RepaintBoundary, skipOffstage: false), skipOffstage: false))
      .toList();
  return {
    for (var i = 0; i < boundaries.length; i++) _layerNames[i]: boundaries[i].debugSymmetricPaintCount + boundaries[i].debugAsymmetricPaintCount,
  };
}

Future<Map<String, int>> _repaintsOver(WidgetTester tester, int frames) async {
  final before = _paintCounts(tester);
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final after = _paintCounts(tester);
  return {for (final k in after.keys) k: after[k]! - (before[k] ?? 0)};
}

void main() {
  group('repaints per layer', () {
    const frames = 20;

    testWidgets('chapter 1 at rest: sky and table animate, the hidden world does not paint', (tester) async {
      await _pumpIntro(tester);
      final r = await _repaintsOver(tester, frames);
      expect(r['sky'], frames);
      expect(r['table'], frames);
      for (final k in ['hills', 'trees', 'world', 'fx', 'road', 'actors']) {
        expect(r[k], 0, reason: k);
      }
    });

    testWidgets('chapter 3 at rest (idle drive): every world layer moves', (tester) async {
      await _pumpIntro(tester);
      await _jump(tester, 2);
      final r = await _repaintsOver(tester, frames);
      expect(r.containsKey('table'), isFalse);
      for (final k in ['sky', 'hills', 'trees', 'world', 'fx', 'road', 'actors']) {
        expect(r[k], frames, reason: k);
      }
    });

    for (final page in const [1, 3, 4, 5]) {
      testWidgets('chapter ${page + 1} at rest: scroll layers stay still, only time layers repaint', (tester) async {
        await _pumpIntro(tester);
        await _jump(tester, page);
        final r = await _repaintsOver(tester, frames);
        for (final k in ['hills', 'trees', 'world', 'road']) {
          expect(r[k], 0, reason: k);
        }
        for (final k in ['sky', 'fx', 'actors']) {
          expect(r[k], frames, reason: k);
        }
      });
    }

    testWidgets('reduce motion: nothing repaints at rest on any chapter', (tester) async {
      await _pumpIntro(tester, reduce: true);
      for (var page = 0; page < 6; page++) {
        await _jump(tester, page);
        final r = await _repaintsOver(tester, frames);
        expect(r.values.every((v) => v == 0), isTrue, reason: 'page $page $r');
        expect(tester.binding.transientCallbackCount, 0);
      }
    });

    testWidgets('ticks never rebuild the scaffold, a page change does not rebuild the scene', (tester) async {
      await _pumpIntro(tester);
      final scene = tester.widget<IntroStoryScene>(find.byType(IntroStoryScene));
      final dots = tester.widget(find.byKey(const Key('intro_dots')));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(identical(tester.widget(find.byKey(const Key('intro_dots'))), dots), isTrue);
      await _jump(tester, 1);
      expect(identical(tester.widget<IntroStoryScene>(find.byType(IntroStoryScene)), scene), isTrue);
    });
  });

  group('swipe drives the story', () {
    testWidgets('half a swipe is half a chapter, swiping back rewinds', (tester) async {
      await _pumpIntro(tester);
      final story = _story(tester);
      final g = await tester.startGesture(const Offset(300, 300));
      await g.moveBy(const Offset(-30, 0));
      await tester.pump();
      final start = _controller(tester).page!;
      await g.moveBy(const Offset(-180, 0));
      await tester.pump();
      expect(story.p, closeTo(start + .5, .01));
      expect(story.p, _controller(tester).page);
      expect(story.e0, closeTo(smooth(story.p), 1e-9));
      await g.moveBy(const Offset(180, 0));
      await tester.pump();
      expect(story.p, closeTo(start, .01));
      await g.up();
      await _settle(tester);
      expect(story.p, 0);
    });

    testWidgets('trail loop and taxi arrival restart after swiping back', (tester) async {
      await _pumpIntro(tester);
      final story = _story(tester);
      await _jump(tester, 3);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(story.tl[1], greaterThan(IntroStory.trailRestart[1]));
      _controller(tester).jumpTo(_controller(tester).position.viewportDimension * 2.5);
      await tester.pump();
      expect(story.tl, IntroStory.trailRestart);
      _controller(tester).jumpTo(_controller(tester).position.viewportDimension * .5);
      await tester.pump();
      expect(story.arrT, -1);
      await _jump(tester, 1);
      expect(story.arrival.dx, lessThan(-150));
    });
  });

  group('haptics', () {
    late List<String> log;

    setUp(() => log = []);

    Future<void> mockHaptics(WidgetTester tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') log.add(call.arguments as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    }

    testWidgets('selection click once when a swipe snaps to the next chapter', (tester) async {
      await mockHaptics(tester);
      await _pumpIntro(tester);
      await tester.fling(find.byType(PageView), const Offset(-200, 0), 1500);
      await _settle(tester);
      expect(_controller(tester).page, 1);
      expect(log, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('no click when the swipe falls back to the same chapter', (tester) async {
      await mockHaptics(tester);
      await _pumpIntro(tester);
      await tester.drag(find.byType(PageView), const Offset(-60, 0));
      await _settle(tester);
      expect(_controller(tester).page, 0);
      expect(log, isEmpty);
    });

    testWidgets('autoplay moves silently', (tester) async {
      await mockHaptics(tester);
      await _pumpIntro(tester, autoplay: true);
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_controller(tester).page!.round(), 1);
      expect(log, isEmpty);
    });

    testWidgets('Skip finishes once with no haptic', (tester) async {
      await mockHaptics(tester);
      var finished = 0;
      await _pumpIntro(tester, onFinish: () => finished++);
      await tester.tap(find.byKey(const Key('intro_skip')));
      await tester.pump();
      expect(finished, 1);
      expect(log, isEmpty);
    });

    testWidgets('medium impact on Start planning', (tester) async {
      await mockHaptics(tester);
      var finished = 0;
      await _pumpIntro(tester, onFinish: () => finished++);
      await _jump(tester, 5);
      log.clear();
      await tester.tap(find.byKey(const Key('intro_cta')));
      await tester.tap(find.byKey(const Key('intro_cta')));
      await tester.pump();
      expect(finished, 1);
      expect(log, ['HapticFeedbackType.mediumImpact']);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('ticker life cycle', () {
    testWidgets('stops when the app goes to the background, resumes after', (tester) async {
      await _pumpIntro(tester);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('muted by TickerMode when the route is covered', (tester) async {
      tester.view.physicalSize = _size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final enabled = ValueNotifier<bool>(true);
      await tester.pumpWidget(_app(ValueListenableBuilder<bool>(
        valueListenable: enabled,
        builder: (context, on, _) => TickerMode(enabled: on, child: IntroScaffold(onFinish: () {}, autoplay: false)),
      )));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      enabled.value = false;
      await tester.pump();
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('image cache', () {
    tearDown(IntroStoryArt.instance.release);

    testWidgets('decodes each picture at its drawn size, never above the 256 px source', (tester) async {
      await tester.runAsync(() => IntroStoryArt.instance.load(1, 2));
      final art = IntroStoryArt.instance;
      expect(art.ready.value, isTrue);
      const drawn = {
        IntroArt.panda: 48 * 1.24,
        IntroArt.taxi: 150.0,
        IntroArt.tree: 84.0,
        IntroArt.house: 74.0,
        IntroArt.canoe: 72.0,
        IntroArt.camping: 92.0,
        IntroArt.framedPicture: 48.0,
        IntroArt.mountain: 40.0,
      };
      for (final e in drawn.entries) {
        final want = (e.value * 2).ceil().clamp(0, 256);
        expect(art[e.key]!.width, want, reason: e.key.name);
      }
    });

    testWidgets('a release during loading keeps nothing decoded', (tester) async {
      final art = IntroStoryArt.instance;
      PaintingBinding.instance.imageCache.clear();
      await tester.runAsync(() async {
        final pending = art.load(1, 3);
        art.release();
        await pending;
      });
      expect(art.ready.value, isFalse);
      for (final a in IntroArt.values) {
        expect(art[a], isNull, reason: a.name);
      }
    });
  });
}
