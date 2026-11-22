import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'real_phone.dart';

const List<Size> ownerSizes = [Size(320, 568), Size(360, 800), Size(411, 891)];
const List<double> ownerTextScales = [1.0, 1.3];

String ownerSizeLabel(Size s, double scale) => '${s.width.toInt()}x${s.height.toInt()} @$scale';

/// One testWidgets per width x text scale, through pumpPhone (real fonts). Fails on any overflow or exception.
void testOwnerSizes(
  String name,
  Widget Function() builder, {
  Future<void> Function(WidgetTester tester, Size size, double scale)? check,
  Future<void> Function(WidgetTester tester)? arrange,
  void Function()? setUpEach,
}) {
  for (final size in ownerSizes) {
    for (final scale in ownerTextScales) {
      testWidgets('$name at ${ownerSizeLabel(size, scale)}', (tester) async {
        setUpEach?.call();
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpPhone(tester, builder(), size: size, textScale: scale);
        if (arrange != null) await arrange(tester);
        expect(tester.takeException(), isNull);
        if (check != null) await check(tester, size, scale);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

// FX-34: the full device matrix (phones, a short landscape window, small tablet, tablet) and a keyboard variant.
// ownerSizes stays the fast default of the per-screen tests; journeys and sheets run this matrix.
const List<Size> ownerMatrixSizes = [
  Size(320, 568),
  Size(360, 640),
  Size(360, 800),
  Size(411, 891),
  Size(430, 932),
  Size(600, 960),
  Size(820, 1180),
  Size(800, 360),
];

/// Share of the screen height a soft keyboard takes in the keyboard variant.
const double ownerKeyboardShare = 0.42;

String ownerMatrixLabel(Size s, double scale, bool keyboard) => '${ownerSizeLabel(s, scale)}${keyboard ? ' keyboard' : ''}';

/// Opens a soft keyboard of [ownerKeyboardShare] of the height (logical px) on the test view.
void openOwnerKeyboard(WidgetTester tester, Size size) {
  final dpr = tester.view.devicePixelRatio;
  tester.view.viewInsets = FakeViewPadding(bottom: size.height * ownerKeyboardShare * dpr);
  addTearDown(tester.view.resetViewInsets);
}

/// One testWidgets per matrix size x text scale x keyboard (when [keyboard] is true). Fails on any overflow or exception.
void testOwnerMatrix(
  String name,
  Widget Function() builder, {
  bool keyboard = false,
  List<Size> sizes = ownerMatrixSizes,
  Future<void> Function(WidgetTester tester, Size size, double scale, bool keyboard)? check,
  Future<void> Function(WidgetTester tester)? arrange,
  void Function()? setUpEach,
}) {
  for (final size in sizes) {
    for (final scale in ownerTextScales) {
      for (final kb in keyboard ? const [false, true] : const [false]) {
        testWidgets('$name at ${ownerMatrixLabel(size, scale, kb)}', (tester) async {
          setUpEach?.call();
          await tester.pumpWidget(const SizedBox.shrink());
          await pumpPhone(tester, builder(), size: size, textScale: scale);
          if (arrange != null) await arrange(tester);
          if (kb) {
            openOwnerKeyboard(tester, size);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          }
          expect(tester.takeException(), isNull);
          if (check != null) await check(tester, size, scale, kb);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
