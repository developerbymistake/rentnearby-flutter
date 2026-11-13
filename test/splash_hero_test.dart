import 'dart:io';
import 'dart:ui' as ui;

import 'package:bakhli/design/design.dart';
import 'package:bakhli/screens/splash/splash_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/real_phone.dart' show loadRealFonts;

const _outDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\splash_E';
const _rootKey = ValueKey('splash_root');
const _assets = [ListingArt.mountain, ListingArt.luggage, ListingArt.beach, ListingArt.pushpin];
const _steps = ['Pick places', 'Find a stay', 'Book a taxi', 'Go and enjoy'];

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

EdgeInsets _insetFor(Size size) =>
    size.width > size.height ? const EdgeInsets.only(left: 32) : const EdgeInsets.only(top: 28, bottom: 24);

void _setView(WidgetTester t, Size size, {double dpr = 1.0}) {
  final inset = _insetFor(size);
  t.view.devicePixelRatio = dpr;
  t.view.physicalSize = size * dpr;
  t.view.padding = FakeViewPadding(left: inset.left * dpr, top: inset.top * dpr, bottom: inset.bottom * dpr);
  t.view.viewPadding = t.view.padding;
  addTearDown(t.view.reset);
}

void _mockHaptics(WidgetTester t, void Function() onHit) {
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') onHit();
    return null;
  });
  addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

double _pillOpacity(WidgetTester t, String label) =>
    t.widget<Opacity>(find.ancestor(of: find.text(label), matching: find.byType(Opacity)).first).opacity;

Future<void> _warmImages(WidgetTester t) async {
  await t.pumpWidget(const MaterialApp(home: SizedBox()));
  final ctx = t.element(find.byType(SizedBox));
  await t.runAsync(() async {
    for (final a in _assets) {
      await precacheImage(AssetImage(a), ctx);
    }
  });
}

Future<void> _shot(WidgetTester t, String name) async {
  final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(_rootKey));
  final file = File('$_outDir\\$name.png');
  await t.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: t.view.devicePixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void _expectFits(WidgetTester t, Size size) {
  final inset = _insetFor(size);
  final screen = Offset.zero & size;
  final title = t.getRect(find.byKey(SplashHero.titleKey));
  expect(title.top, greaterThanOrEqualTo(inset.top - 0.5), reason: 'title clears the top inset');
  expect(title.left, greaterThanOrEqualTo(inset.left - 0.5));
  expect(screen.contains(title.topLeft) && screen.contains(title.bottomRight), isTrue);
  final pills = [for (final s in _steps) t.getRect(find.ancestor(of: find.text(s), matching: find.byType(ClipRRect)).first)];
  for (var i = 0; i < pills.length; i++) {
    final r = pills[i];
    expect(r.left >= inset.left - 0.5 && r.right <= size.width + 0.5, isTrue, reason: '${_steps[i]} inside width');
    expect(r.bottom <= size.height - inset.bottom + 0.5, isTrue, reason: '${_steps[i]} above the bottom inset');
    expect(r.overlaps(title), isFalse);
    for (var j = i + 1; j < pills.length; j++) {
      expect(r.overlaps(pills[j]), isFalse, reason: '${_steps[i]} vs ${_steps[j]}');
    }
  }
}

void main() {
  const sizes = <String, Size>{
    '320x568': Size(320, 568),
    '360x780': Size(360, 780),
    '412x915': Size(412, 915),
    '768x1024': Size(768, 1024),
    '800x360': Size(800, 360),
  };

  for (final entry in sizes.entries) {
    for (final scale in const [1.0, 2.0]) {
      for (final reduce in const [false, true]) {
        testWidgets('SplashHero ${entry.key} scale $scale reduce $reduce', (t) async {
          _setView(t, entry.value);
          var hits = 0;
          _mockHaptics(t, () => hits++);

          await t.pumpWidget(_host(scale: scale, reduce: reduce));
          expect(t.takeException(), isNull);
          expect(
            find.descendant(of: find.byType(SplashHero), matching: find.byWidgetPredicate((w) => w is ColoredBox && w.color == DesignColors.dinnerEnd)),
            findsOneWidget,
          );
          expect(find.byKey(SplashHero.titleKey), findsOneWidget);
          for (final s in _steps) {
            expect(find.text(s), findsOneWidget);
          }
          expect(_pillOpacity(t, 'Pick places'), reduce ? 1.0 : 0.0);
          expect(_pillOpacity(t, 'Go and enjoy'), reduce ? 1.0 : 0.0);
          expect(find.byKey(const ValueKey('splash_done_3')), reduce ? findsOneWidget : findsNothing);

          for (var i = 0; i < 28; i++) {
            await t.pump(const Duration(milliseconds: 100));
            expect(t.takeException(), isNull);
          }
          for (final s in _steps) {
            expect(_pillOpacity(t, s), 1.0);
          }
          for (var i = 0; i < 4; i++) {
            expect(find.byKey(ValueKey('splash_done_$i')), findsOneWidget);
          }
          expect(hits, reduce ? 0 : 1);
          _expectFits(t, entry.value);

          await t.pump(const Duration(milliseconds: 3000));
          expect(t.takeException(), isNull);
          expect(hits, reduce ? 0 : 1);
          expect(t.hasRunningAnimations, !reduce);

          await t.pumpWidget(const SizedBox());
          expect(t.takeException(), isNull);
          expect(t.hasRunningAnimations, isFalse);
        });
      }
    }
  }

  for (final (size, phone) in const [(Size(360, 780), true), (Size(800, 360), true), (Size(768, 1024), false), (Size(1180, 820), false)]) {
    testWidgets('orientation lock ${size.width.toInt()}x${size.height.toInt()} phone $phone', (t) async {
      _setView(t, size);
      final calls = <List<dynamic>>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') calls.add(call.arguments as List<dynamic>);
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await t.pumpWidget(_host());
      expect(calls, phone ? [['DeviceOrientation.portraitUp', 'DeviceOrientation.portraitDown']] : isEmpty);
      await t.pump(const Duration(milliseconds: 2800));
      await t.pumpWidget(const SizedBox());
      expect(calls, phone ? [['DeviceOrientation.portraitUp', 'DeviceOrientation.portraitDown'], <dynamic>[]] : isEmpty);
    });
  }

  group('shots', () {
    const shotSizes = <Size>[
      Size(320, 480), Size(320, 568), Size(360, 640), Size(360, 780), Size(375, 667), Size(390, 844),
      Size(412, 915), Size(430, 932), Size(600, 960), Size(768, 1024), Size(820, 1180), Size(800, 360), Size(915, 412),
    ];
    const bigText = <Size>[Size(320, 480), Size(360, 780), Size(915, 412)];
    const times = [0, 600, 1200, 1800, 2400];

    for (final size in shotSizes) {
      for (final scale in [1.0, if (bigText.contains(size)) 2.0]) {
        final tag = 'f${size.width.toInt()}x${size.height.toInt()}${scale == 1.0 ? '' : '_x2'}';
        testWidgets('shots $tag', (t) async {
          await loadRealFonts();
          _setView(t, size, dpr: 2);
          _mockHaptics(t, () {});
          await _warmImages(t);
          await t.pumpWidget(_host(scale: scale));
          await t.pump();
          var at = 0;
          for (final ms in times) {
            await t.pump(Duration(milliseconds: ms - at));
            at = ms;
            await _shot(t, '${tag}_t$ms');
          }
          await t.pump(const Duration(milliseconds: 3700));
          await _shot(t, '${tag}_idle');
          _expectFits(t, size);
          await t.pumpWidget(const SizedBox());
        });
      }
    }

    testWidgets('shots reduced motion', (t) async {
      await loadRealFonts();
      _setView(t, const Size(360, 780), dpr: 2);
      await _warmImages(t);
      await t.pumpWidget(_host(reduce: true));
      await t.pump();
      await _shot(t, 'f360x780_reduce');
      await t.pumpWidget(const SizedBox());
    });
  });
}
