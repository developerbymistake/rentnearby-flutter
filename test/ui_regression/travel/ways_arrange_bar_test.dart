import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/features/taxi/ways/widgets/ways_arrange_bar.dart';

void main() {
  testWidgets('arrange bar does not swallow the body', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var arranged = 0, skipped = 0;
    const bodyKey = Key('body');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: WaysArrangeBar(
          arrangeLabel: 'Arrange it myself',
          skipLabel: 'Skip',
          onArrange: () => arranged++,
          onSkip: () => skipped++,
        ),
        body: const SizedBox.expand(key: bodyKey),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(bodyKey)).height, greaterThan(0));
    expect(tester.getSize(find.byType(WaysArrangeBar)).height, lessThan(100));
    await tester.tap(find.text('Arrange it myself'));
    await tester.tap(find.text('Skip'));
    expect(arranged, 1);
    expect(skipped, 1);
  });
}
