import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/home/numbers_row.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/taxi/requests/widgets/driver_offer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/real_phone.dart';

Map<String, dynamic> _json(String state) => {
      'offerId': 'x_$state',
      'requestId': 'r1',
      'state': state,
      'bucket': 'Earlier',
      'routeLine': 'Jaipur to Agra',
      'dayCount': 2,
    };

Widget _card(String state, VoidCallback onOpen) => Material(
      child: DriverOfferCard(
        offer: DriverOffer.fromJson(_json(state)),
        timeLeft: null,
        expired: false,
        enabled: true,
        onOpen: onOpen,
        onAccept: () {},
        onDecline: () {},
      ),
    );

void main() {
  test('state Declined is parsed', () {
    expect(DriverOffer.fromJson(_json('Declined')).state, OfferState.declined);
  });

  test('home numbers parse missedRequests', () {
    expect(OwnerNumbers.fromJson({'taxi': {'missedRequests': 4}}).missedRequests, 4);
    expect(OwnerNumbers.fromJson({'taxi': {}}).missedRequests, isNull);
  });

  for (final c in const [('Missed', 'Missed'), ('Declined', 'You declined')]) {
    testWidgets('${c.$1} row shows pill and is not tappable', (tester) async {
      var opened = 0;
      await pumpPhone(tester, _card(c.$1, () => opened++));
      expect(find.text(c.$2), findsWidgets);
      await tester.tap(find.byKey(ValueKey('request_open_x_${c.$1}')), warnIfMissed: false);
      expect(opened, 0);
    });
  }

  testWidgets('a closed row still opens', (tester) async {
    var opened = 0;
    await pumpPhone(tester, _card('NotSelected', () => opened++));
    await tester.tap(find.byKey(const ValueKey('request_open_x_NotSelected')));
    expect(opened, 1);
  });

  for (final width in const [320.0, 430.0]) {
    testWidgets('four tiles fit at $width wide, text scale 1.3', (tester) async {
      await pumpPhone(
        tester,
        const Material(
          child: NumbersRow(tiles: [
            NumberTile(value: '12', label: 'New requests'),
            NumberTile(value: '3', label: 'Missed'),
            NumberTile(value: '25 Nov', label: 'Next booking'),
            NumberTile(value: '4.8', label: 'Rating'),
          ]),
        ),
        size: Size(width, 700),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Missed'), findsOneWidget);
    });
  }
}
