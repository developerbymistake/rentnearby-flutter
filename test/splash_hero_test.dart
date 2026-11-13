import 'dart:io';
import 'dart:ui' as ui;

import 'package:bakhli/design/design.dart';
import 'package:bakhli/screens/splash/splash_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/real_phone.dart' show loadRealFonts;

const _outDir = r'C:\Users\deven\AppData\Local\Temp\claude\ccafaf5a958b4225\b0a9900f-9e15-495d-b8d6-355005e1d3cf\scratchpad\splash_simple';
const _rootKey = ValueKey('splash_root');

Widget _host({double scale = 1.0, bool reduce = false}) {
  return RepaintBoundary(
    key: _rootKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (c) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: reduce),
          child: const Scaffold(backgroundColor: DesignColors.dinnerEnd, body: SplashHero()),
        ),
      ),
    ),
  );
}

void _setView(WidgetTester t, Size size, {double dpr = 1.0}) {
  t.view.devicePixelRatio = dpr;
  t.view.physicalSize = size * dpr;
  t.view.padding = FakeViewPadding(top: 28 * dpr, bottom: 24 * dpr);
  t.view.viewPadding = t.view.padding;
  addTearDown(t.view.reset);
}

Future<void> _shot(WidgetTester t, String name) async {
  final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(_rootKey));
  await t.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: t.view.devicePixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir\\$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void _expectLayout(WidgetTester t, Size size) {
  final screen = Offset.zero & size;
  final word = t.getRect(find.byKey(SplashHero.titleKey));
  final tag = t.getRect(find.text(SplashHero.tagline));
  for (final r in [word, tag]) {
    expect(screen.contains(r.topLeft) && screen.contains(r.bottomRight), isTrue, reason: 'inside screen $r');
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(size.width));
    expect((r.center.dx - size.width / 2).abs(), lessThan(1.0), reason: 'horizontally centred');
  }
  expect(word.overlaps(tag), isFalse);
  final mid = (word.top + tag.bottom) / 2;
  expect((mid - size.height / 2).abs(), lessThan(size.height * 0.1), reason: 'near vertical centre');
  expect(word.height, greaterThan(tag.height));
}

void main() {
  const sizes = <String, Size>{
    '300x640': Size(300, 640),
    '360x780': Size(360, 780),
    '412x915': Size(412, 915),
    '768x1024': Size(768, 1024),
  };

  for (final entry in sizes.entries) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      for (final reduce in const [false, true]) {
        testWidgets('SplashHero ${entry.key} scale $scale reduce $reduce', (t) async {
          _setView(t, entry.value);
          await t.pumpWidget(_host(scale: scale, reduce: reduce));
          await t.pump();
          expect(find.text('Bakhli'), findsOneWidget);
          expect(find.text('Plan your next trip'), findsOneWidget);
          expect(
            find.descendant(of: find.byType(SplashHero), matching: find.byType(ColoredBox)).evaluate().any(
                (e) => (e.widget as ColoredBox).color == DesignColors.dinnerEnd),
            isTrue,
          );
          await t.pump(const Duration(milliseconds: 2600));
          _expectLayout(t, entry.value);
          expect(t.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('first frame is hidden, final frame is visible', (t) async {
    _setView(t, const Size(360, 780));
    await t.pumpWidget(_host());
    await t.pump();
    double opacityOf(Finder f) => t.widget<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity)).first).opacity;
    expect(opacityOf(find.byKey(SplashHero.titleKey)), 0);
    expect(opacityOf(find.text(SplashHero.tagline)), 0);
    await t.pump(const Duration(milliseconds: 2000));
    expect(opacityOf(find.byKey(SplashHero.titleKey)), 1);
    expect(opacityOf(find.text(SplashHero.tagline)), 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion fades in at once and stops', (t) async {
    _setView(t, const Size(360, 780));
    await t.pumpWidget(_host(reduce: true));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(t.widget<Opacity>(find.ancestor(of: find.text(SplashHero.tagline), matching: find.byType(Opacity)).first).opacity, 1);
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('idle motion runs normally and disposal is clean mid-animation', (t) async {
    _setView(t, const Size(360, 780));
    await t.pumpWidget(_host());
    await t.pump(const Duration(milliseconds: 700));
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);

    await t.pumpWidget(_host());
    await t.pump(const Duration(milliseconds: 3000));
    expect(t.binding.hasScheduledFrame, isTrue);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 100));
    expect(t.binding.hasScheduledFrame, isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets('shots', (t) async {
    await loadRealFonts();
    _setView(t, const Size(360, 780), dpr: 2);
    await t.pumpWidget(_host());
    await t.pump();
    var at = 0;
    for (final ms in const [0, 500, 1000, 1500, 2400]) {
      await t.pump(Duration(milliseconds: ms - at));
      at = ms;
      await _shot(t, 't$ms');
    }
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(_host(reduce: true));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    await _shot(t, 'reduced');
    await t.pumpWidget(const SizedBox());
  });
}
