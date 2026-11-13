import 'package:bakhli/design/design.dart';
import 'package:bakhli/widgets/detail_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DetailActionBar in bottomNavigationBar keeps the body visible', (tester) async {
    var reported = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: const SizedBox.expand(key: Key('body')),
        bottomNavigationBar: DetailActionBar(
          ownerPhone: '9999999999',
          showDirections: false,
          callLabel: 'Call Driver',
          palette: templateTaxiPalette,
          onReport: () => reported++,
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const Key('body'))).height, greaterThan(200));
    expect(find.text('Call Driver'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    await tester.tap(find.text('Report this listing'));
    expect(reported, 1);
  });

  testWidgets('DetailActionBar works inside a Row and Stack without palette', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Stack(children: [SizedBox.expand(key: Key('body'))]),
        bottomNavigationBar: Row(children: [Expanded(child: DetailActionBar(ownerPhone: '9999999999'))]),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const Key('body'))).height, greaterThan(100));
  });

  test('vehicle icon follows the vehicle type', () {
    expect(TaxiVehicleIcon.assetFor('Tempo Traveller'), contains('bus'));
    expect(TaxiVehicleIcon.assetFor('Sedan'), contains('taxi'));
    expect(TaxiVehicleIcon.assetFor(null), contains('taxi'));
  });
}
