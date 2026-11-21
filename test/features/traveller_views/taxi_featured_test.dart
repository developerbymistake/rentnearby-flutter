import 'package:bakhli/features/trip/models/taxi_request_models.dart';
import 'package:bakhli/features/trip/widgets/taxi_status/taxi_driver_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/owner_sizes.dart';

Map<String, dynamic> _driver({Object? featured}) => {
      'offerId': 'o1',
      'state': 'Accepted',
      'name': 'Ramesh Negi',
      'phone': '9876543210',
      'vehicle': 'Sedan',
      'seats': 4,
      'ratingAverage': 4.6,
      'ratingCount': 12,
      'ridesCompleted': 40,
      'canSelect': true,
      'isFeatured': ?featured,
    };

Widget _card(TaxiDriverCard d) => Scaffold(
      body: ListView(children: [
        TaxiDriverCardView(
          driver: d,
          mode: TaxiDriverMode.choose,
          showSelect: true,
          calling: false,
          enabled: true,
          onCall: () {},
          onSelect: () {},
          onNotAgreed: () {},
        ),
      ]),
    );

void main() {
  test('T9 accepted driver isFeatured is read tolerantly', () {
    expect(TaxiDriverCard.fromJson(_driver(featured: true)).isFeatured, isTrue);
    for (final v in <Object?>[null, false, 'true', 1, [], {}]) {
      expect(TaxiDriverCard.fromJson(_driver(featured: v)).isFeatured, isFalse, reason: '$v');
    }
    expect(TaxiDriverCard.fromJson(_driver(featured: true)).toJson()['isFeatured'], isTrue);
  });

  testWidgets('T9 Featured tag shows only for a featured driver', (t) async {
    await t.pumpWidget(MaterialApp(home: _card(TaxiDriverCard.fromJson(_driver(featured: true)))));
    expect(find.text('Featured'), findsOneWidget);
    await t.pumpWidget(MaterialApp(home: _card(TaxiDriverCard.fromJson(_driver()))));
    expect(find.text('Featured'), findsNothing);
  });

  testOwnerSizes('T9 featured driver card', () => _card(TaxiDriverCard.fromJson(_driver(featured: true))));
}
