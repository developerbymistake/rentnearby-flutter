import 'dart:io';
import 'dart:ui' as ui;

import 'package:bakhli/screens/intro/intro_scaffold.dart';
import 'package:bakhli/screens/intro/story/intro_story_art.dart';
import 'package:bakhli/screens/intro/story/intro_story_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden_support.dart';

const _mode = String.fromEnvironment('UI_SCALE', defaultValue: 'identity');
const _dir = 'F:\\Dhasu\\Buddy_resume\\wgw\\shots\\welcome_fidelity\\flutter_$_mode';
const _root = ValueKey('fidelity_root');

class _Frame {
  const _Frame(this.name, this.p, this.t, {this.arr});

  final String name;
  final double p, t;
  final double? arr;
}

const _frames = [
  _Frame('p0_t1.0', 0, 1.0),
  _Frame('p0_t4.5', 0, 4.5),
  _Frame('p0.5_t1.3', .5, 1.3),
  _Frame('p1_arr0', 1, 1.0, arr: 0),
  _Frame('p1_arr1.2', 1, 1.0, arr: 1.2),
  _Frame('p1_arr3.6', 1, 4.0, arr: 3.6),
  _Frame('p1.5_t1.0', 1.5, 1.0),
  _Frame('p2_t1.3', 2, 1.3),
  _Frame('p3_t2.0', 3, 2.0),
  _Frame('p4_t1.0', 4, 1.0),
  _Frame('p4_t2.55', 4, 2.55),
  _Frame('p4_t3.0', 4, 3.0),
  _Frame('p4.9_t1.0', 4.9, 1.0),
  _Frame('p5_t3.0', 5, 3.0),
];

void main() {
  setUpAll(loadGoldenFonts);

  for (final size in const [Size(360, 760), Size(320, 568)]) {
    for (final scale in [1.0, 1.3]) {
      for (final f in _frames) {
        final name = '${f.name}_${size.width.toInt()}_$scale';
        testWidgets('welcome fidelity shot $name', (t) async {
          setGoldenView(t, size);
          debugDisableShadows = false;
          try {
            await t.runAsync(() => IntroStoryArt.instance.load(size.width / 360, 1));
            await t.pumpWidget(MaterialApp(
              debugShowCheckedModeBanner: false,
              home: MediaQuery(
                data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(key: _root, child: IntroScaffold(onFinish: () {}, autoplay: false)),
              ),
            ));
            await t.pump();
            final position = t.widget<PageView>(find.byType(PageView)).controller!.position as ScrollPositionWithSingleContext;
            position.jumpTo(f.p * size.width);
            position.goIdle();
            await t.pump();
            t.widget<IntroStoryScene>(find.byType(IntroStoryScene)).state.debugFreeze(f.t, arrT: f.arr);
            await t.pump();
            await t.pump(const Duration(milliseconds: 50));
            expect(t.takeException(), isNull);
            final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(_root));
            await t.runAsync(() async {
              final image = await boundary.toImage();
              final data = await image.toByteData(format: ui.ImageByteFormat.png);
              final file = File('$_dir\\$name.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
            await t.pumpWidget(const SizedBox());
          } finally {
            debugDisableShadows = true;
          }
        });
      }
    }
  }
}
