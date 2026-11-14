import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/taxi/guest/taxi_card.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/real_phone.dart';

TaxiBrowseItem _taxi({required bool featured}) => TaxiBrowseItem(
      id: 't1',
      driverName: 'Ramesh Negi',
      vehicleTypeName: 'Sedan',
      seats: 4,
      plateDisplay: 'UK 04 AB 1234',
      routeCount: 3,
      matchReversed: false,
      isFeatured: featured,
      createdAt: DateTime(2030, 1, 1),
    );

Future<void> _pump(WidgetTester t, bool featured) async {
  await pumpPhone(
    t,
    Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: SafeArea(child: SingleChildScrollView(child: TaxiCard(item: _taxi(featured: featured), onOpen: () {}))),
    ),
  );
  await settlePhone(t);
}

void main() {
  testWidgets('a featured taxi shows only a star badge, the tag stays plain Taxi', (t) async {
    await _pump(t, true);
    expect(find.byKey(const ValueKey('meals-star-badge')), findsOneWidget);
    expect(find.textContaining('Featured'), findsNothing);
    expect(find.text('TAXI'), findsOneWidget);
  });

  testWidgets('a taxi that is not featured has no star badge', (t) async {
    await _pump(t, false);
    expect(find.byKey(const ValueKey('meals-star-badge')), findsNothing);
    expect(find.text('TAXI'), findsOneWidget);
  });
}
