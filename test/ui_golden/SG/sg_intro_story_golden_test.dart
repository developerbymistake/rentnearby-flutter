import 'package:bakhli/screens/intro/intro_scaffold.dart';
import 'package:bakhli/screens/intro/story/intro_story_art.dart';
import 'package:bakhli/screens/intro/story/intro_story_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden_support.dart';

class _Frame {
  const _Frame(this.name, this.p, this.t, {this.arr});

  final String name;
  final double p, t;
  final double? arr;
}

const _frames = [
  _Frame('f01_p0_t1.0', 0, 1.0),
  _Frame('f02_p0_t4.5', 0, 4.5),
  _Frame('f03_p0_t6.0', 0, 6.0),
  _Frame('f04_p0.5_t1.3', .5, 1.3),
  _Frame('f05_p1_arr0', 1, 1.0, arr: 0),
  _Frame('f06_p1_arr1.8', 1, 1.0, arr: 1.8),
  _Frame('f07_p1_arr3.6', 1, 4.0, arr: 3.6),
  _Frame('f08_p1.2_t1.0', 1.2, 1.0),
  _Frame('f09_p1.5_t1.0', 1.5, 1.0),
  _Frame('f10_p2_t1.3', 2, 1.3),
  _Frame('f11_p2.8_t2.0', 2.8, 2.0),
  _Frame('f12_p3_t2.0', 3, 2.0),
  _Frame('f13_p3.2_t2.0', 3.2, 2.0),
  _Frame('f14_p3.5_t1.0', 3.5, 1.0),
  _Frame('f15_p4_t1.0', 4, 1.0),
  _Frame('f19_p4.6_t1.0', 4.6, 1.0),
  _Frame('f21_p5_t1.0', 5, 1.0),
];

Future<void> _pumpFrame(WidgetTester t, _Frame f, double scale) async {
  setGoldenView(t);
  debugDisableShadows = false;
  await t.runAsync(() => IntroStoryArt.instance.load(1, 1));
  await t.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MediaQuery(
      data: MediaQueryData(size: goldenSize, textScaler: TextScaler.linear(scale)),
      child: RepaintBoundary(key: const ValueKey('golden_root'), child: IntroScaffold(onFinish: () {}, autoplay: false)),
    ),
  ));
  await t.pump();
  final position = t.widget<PageView>(find.byType(PageView)).controller!.position as ScrollPositionWithSingleContext;
  position.jumpTo(f.p * goldenSize.width);
  position.goIdle();
  await t.pump();
  t.widget<IntroStoryScene>(find.byType(IntroStoryScene)).state.debugFreeze(f.t, arrT: f.arr);
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(loadGoldenFonts);

  for (final f in _frames) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('intro story ${f.name} scale $scale', (t) async {
        try {
          await _pumpFrame(t, f, scale);
          expect(t.takeException(), isNull);
          await expectLater(find.byKey(const ValueKey('golden_root')), matchesGoldenFile('goldens/intro_story_${f.name}_$scale.png'));
          await t.pumpWidget(const SizedBox());
        } finally {
          debugDisableShadows = true;
        }
      });
    }
  }
}
