import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/taxi/ways/widgets/way_driver_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reversed driver shows the ridden stretch, not swapped again', (tester) async {
    final d = WayDriver.fromJson({
      'taxiId': 'a',
      'driverName': 'Driver A',
      'vehicleTypeName': 'Sedan',
      'seats': 4,
      'plateDisplay': 'UK04 AB 1234',
      'cityName': 'Nainital',
      'basedHere': false,
      'routeId': 'r',
      'fromName': 'Haldwani',
      'toName': 'Nainital',
      'listedFare': 1500,
      'tripType': 'OneWay',
      'partial': false,
      'reversed': true,
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: WayDriverRow(driver: d, startName: 'Kamalwaganja', onTap: () {}))),
    ));
    expect(find.textContaining('Kamalwaganja to Nainital'), findsOneWidget);
  });
}
