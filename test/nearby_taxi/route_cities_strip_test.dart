import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/features/taxi/guest/v2/route_cities_strip.dart';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';

Map<String, dynamic> stop(int i) => {'key': 'a$i', 'name': 'City $i', 'lat': 29.0 + i, 'lng': 79.0};

void main() {
  test('city key comes from an Atlas stop key only', () {
    expect(RouteCities.cityKeyOf('a123'), 123);
    expect(RouteCities.cityKeyOf('p9'), isNull);
    expect(RouteCities.cityKeyOf('a'), isNull);
  });

  test('stops are deduped and capped at 8', () {
    final leg = {
      'index': 1,
      'passStops': [for (var i = 1; i <= 12; i++) stop(i), stop(1)],
    };
    final r = TaxiWaysResult.fromJson({
      'plans': [
        {
          'planKey': 'p',
          'legs': [leg],
        },
      ],
    });
    final rows = RouteCities.fromResult(r);
    expect(rows.length, RouteCities.maxCities);
    expect(rows.first.cityKey, 1);
  });

  test('no plans gives no rows', () {
    expect(RouteCities.fromResult(TaxiWaysResult.fromJson(const {})), isEmpty);
  });

  test('supply text', () {
    expect(const RouteCityRow(name: 'A').supplyText, '');
    expect(const RouteCityRow(name: 'A', drivers: 0).supplyText, 'No taxi listed yet');
    expect(const RouteCityRow(name: 'A', drivers: 1).supplyText, '1 taxi listed');
    expect(const RouteCityRow(name: 'A', drivers: 4).supplyText, '4 taxis listed');
  });

  for (final w in [300.0, 560.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('strip fits at $w dp and scale $scale', (tester) async {
        tester.view.physicalSize = Size(w, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(w, 800), textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: RouteCitiesStripView(rows: [
                  for (var i = 0; i < 8; i++) RouteCityRow(name: 'A very long city name number $i on the way', drivers: i % 3),
                ]),
              ),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
        expect(find.text('Cities on the way'), findsOneWidget);
      });
    }
  }
}
