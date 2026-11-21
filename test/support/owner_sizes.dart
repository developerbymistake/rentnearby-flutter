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
