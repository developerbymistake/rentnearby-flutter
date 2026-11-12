import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bakhli/config/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const String shotsDir = r'F:\Dhasu\UI_Template_resume\Slice1\shots';
const Size phoneSize = Size(360, 800);
const double phoneTopInset = 28;
const double phoneBottomInset = 24;
const Key _rootKey = ValueKey('real_phone_root');

bool _fontsLoaded = false;

// Loads every font family declared in the built FontManifest (app, MaterialIcons, package icon fonts).
Future<void> loadRealFonts() async {
  if (_fontsLoaded) return;
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    for (final f in entry['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load(f['asset'] as String));
    }
    await loader.load();
  }
  _fontsLoaded = true;
}

// Platform is Android (the flutter_test default). Pumps [child] as the app does, on a 1080x2400 phone with real system insets.
Future<void> pumpPhone(
  WidgetTester tester,
  Widget child, {
  Size size = phoneSize,
  double devicePixelRatio = 3,
  double textScale = 1.0,
}) async {
  await loadRealFonts();
  final view = tester.view;
  view.devicePixelRatio = devicePixelRatio;
  view.physicalSize = Size(size.width * devicePixelRatio, size.height * devicePixelRatio);
  view.padding = FakeViewPadding(top: phoneTopInset * devicePixelRatio, bottom: phoneBottomInset * devicePixelRatio);
  view.viewPadding = view.padding;
  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    view.resetPadding();
    view.resetViewPadding();
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        scrollBehavior: const AppScrollBehavior(),
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: true),
          child: c!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

// Lets images decode and animations finish before a capture.
Future<void> settlePhone(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 500));
}

// Captures the whole phone at real pixel size to shotsDir/name.png and returns the file.
Future<File> shot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_rootKey));
  final ratio = tester.view.devicePixelRatio;
  final file = File('$shotsDir\\$name.png');
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
  return file;
}

// Scrolls the first Scrollable under [finder] to each offset and captures name_<i>.png.
Future<List<File>> scrollShots(WidgetTester tester, Finder finder, String name, List<double> offsets) async {
  final scrollable = find.descendant(of: finder, matching: find.byType(Scrollable)).first;
  final position = tester.state<ScrollableState>(scrollable).position;
  final files = <File>[];
  for (var i = 0; i < offsets.length; i++) {
    position.jumpTo(offsets[i].clamp(position.minScrollExtent, position.maxScrollExtent));
    await tester.pump(const Duration(milliseconds: 100));
    files.add(await shot(tester, '${name}_$i'));
  }
  return files;
}
