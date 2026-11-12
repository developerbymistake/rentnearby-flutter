import 'package:flutter/material.dart';
import 'package:bakhli/design/tokens/design_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadGoldenFonts() async {
  const families = <String, List<String>>{
    'Roboto': ['Regular', 'Medium', 'Bold'],
    'WorkSans': ['Regular', 'Medium', 'SemiBold', 'Bold'],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final w in e.value) {
      loader.addFont(rootBundle.load('assets/fonts/${e.key}-$w.ttf'));
    }
    await loader.load();
  }
}

const Size goldenSize = Size(360, 760);
const Color goldenBg = DesignColors.scaffold;

void setGoldenView(WidgetTester t, [Size size = goldenSize]) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Widget goldenHost(Widget child, {required double scale, bool scroll = true}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(fontFamily: 'WorkSans'),
    home: MediaQuery(
      data: MediaQueryData(size: goldenSize, textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        backgroundColor: goldenBg,
        body: RepaintBoundary(
          key: const ValueKey('golden_root'),
          child: Container(
            color: goldenBg,
            padding: const EdgeInsets.all(16),
            alignment: Alignment.topCenter,
            child: scroll ? SingleChildScrollView(child: child) : child,
          ),
        ),
      ),
    ),
  );
}

Future<void> settleGolden(WidgetTester t) async {
  await t.pump();
  await t.runAsync(() async {
    for (final e in find.byType(Image).evaluate().toList()) {
      final img = e.widget as Image;
      try {
        await precacheImage(img.image, e);
      } catch (_) {}
    }
  });
  await t.pump(const Duration(milliseconds: 1500));
  await t.pump(const Duration(milliseconds: 1500));
}

final List<String> baselineIssues = <String>[];

void recordBaselineIssues(String test) {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString().split(RegExp(r'[\r\n]')).first;
    baselineIssues.add('$test: $msg');
  };
  addTearDown(() => FlutterError.onError = original);
}
