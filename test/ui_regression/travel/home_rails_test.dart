import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/stay_grid_card.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/models/card_fact.dart';
import 'package:bakhli/widgets/home_stay_rail_card.dart';
import 'package:bakhli/widgets/home_taxi_rail_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TaxiBrowseItem _taxi({bool featured = true, int? fare = 1800}) => TaxiBrowseItem(
      id: 't1',
      driverName: 'Ramesh Kumar Negi',
      vehicleTypeName: 'Innova Crysta',
      seats: 7,
      plateDisplay: 'UK07',
      cityName: 'Dehradun',
      minFare: fare,
      routeCount: 2,
      matchReversed: false,
      createdAt: DateTime(2026, 1, 1),
      isFeatured: featured,
    );

Widget _host(Widget child, {double scale = 1, double? height}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: height == null
                ? MealsRail(children: [child])
                : SizedBox(height: height, child: ListView(scrollDirection: Axis.horizontal, children: [child])),
          ),
        ),
      ),
    );

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('taxi rail card shows all details at scale $scale', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(HomeTaxiRailCard(taxi: _taxi(), onOpen: () => taps++), scale: scale));
      expect(find.textContaining('Featured'), findsOneWidget);
      expect(find.text('Innova Crysta'), findsOneWidget);
      expect(find.text('7 seats'), findsOneWidget);
      expect(find.textContaining('1,800'), findsOneWidget);
      expect(find.text('FARE FROM'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(HomeTaxiRailCard));
      expect(taps, 1);
    });
  }

  testWidgets('taxi rail card without fare shows local taxi', (tester) async {
    await tester.pumpWidget(_host(HomeTaxiRailCard(taxi: _taxi(featured: false, fare: null))));
    expect(find.textContaining('Local taxi'), findsOneWidget);
    expect(find.textContaining('Featured'), findsNothing);
    expect(find.text('FARE FROM'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stay grid card in the rail cell shows facts and price', (tester) async {
    await tester.pumpWidget(_host(Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      child: SizedBox(
        width: HomeStayRailCard.cellWidth,
        child: StayGridCard(
          thumbnailUrl: null,
          tagLabel: 'HOMESTAY',
          title: 'Himalayan View',
          locationLabel: 'Mussoorie',
          facts: const [
            CardFact('Breakfast', tone: FactTone.accent),
            CardFact('Wifi', tone: FactTone.cyan),
            CardFact('Parking', tone: FactTone.slate),
          ],
          priceCaption: 'FROM',
          priceValue: 'Rs 1,200',
          priceUnit: '/night',
          isFeatured: true,
          onViewDetails: () {},
        ),
      ),
    ), height: StayGridCard.height + 24));
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Parking'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
