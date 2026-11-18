import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'real_phone.dart';

const List<Size> fiveSizes = [
  Size(320, 568),
  Size(360, 640),
  Size(360, 800),
  Size(411, 891),
  Size(600, 960),
];

String sizeLabel(Size size) => '${size.width.toInt()}x${size.height.toInt()}';

// Pumps [builder] through pumpPhone (real fonts, app scroll behaviour) at each of the five sizes.
// Normal and approved scale come from --dart-define=UI_SCALE.
Future<void> pumpAtFiveSizes(
  WidgetTester tester,
  Widget Function() builder, {
  bool expectNoOverflow = true,
  Future<void> Function(WidgetTester tester, Size size)? check,
  double textScale = 1.0,
}) async {
  for (final size in fiveSizes) {
    await pumpAtSize(tester, builder(), size, textScale: textScale);
    if (expectNoOverflow) expect(tester.takeException(), isNull, reason: 'at ${sizeLabel(size)}');
    if (check != null) await check(tester, size);
    if (expectNoOverflow) expect(tester.takeException(), isNull, reason: 'at ${sizeLabel(size)}');
  }
}

// One testWidgets per size, so a failure names the size.
void testFiveSizes(
  String name,
  Widget Function() builder, {
  Future<void> Function(WidgetTester tester, Size size)? check,
  double textScale = 1.0,
}) {
  for (final size in fiveSizes) {
    testWidgets('$name at ${sizeLabel(size)}', (tester) async {
      await pumpAtSize(tester, builder(), size, textScale: textScale);
      expect(tester.takeException(), isNull);
      if (check != null) await check(tester, size);
      expect(tester.takeException(), isNull);
    });
  }
}

// GetMaterialApp reads `home` only on its first build, so the old tree is dropped before each size.
Future<void> pumpAtSize(WidgetTester tester, Widget child, Size size, {double textScale = 1.0}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpPhone(tester, child, size: size, textScale: textScale);
}
