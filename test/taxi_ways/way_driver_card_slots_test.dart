import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/taxi/ways/widgets/way_driver_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/real_phone.dart';

WayDriver _d({
  String id = 'a',
  bool basedHere = false,
  int? seats = 4,
  String? meetAt,
  String section = 'direct',
  String? city = 'Haldwani',
  String from = 'Haldwani',
  String to = 'Nainital',
  String? routeFrom,
  String? routeTo,
}) =>
    WayDriver.fromJson({
      'taxiId': id,
      'driverName': 'Ramesh Negi',
      'vehicleTypeName': 'Sedan',
      'seats': seats,
      'cityName': city,
      'basedHere': basedHere,
      'fromName': from,
      'toName': to,
      'listedFare': 1500,
      'section': section,
      'routeFromName': routeFrom,
      'routeToName': routeTo,
      'meetAtName': meetAt,
    });

Future<double> _height(WidgetTester t, WayDriver d, {int people = 1, bool noReply = false, double scale = 1.0}) async {
  await pumpPhone(
    t,
    Scaffold(
      body: SingleChildScrollView(
        child: WayDriverRow(key: UniqueKey(), driver: d, people: people, noReply: noReply, startName: 'Kamalwaganja', onTap: () {}, onShortlist: () {}),
      ),
    ),
    textScale: scale,
  );
  return t.getSize(find.byType(WayDriverRow)).height;
}

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('every driver type renders the same card height at text scale $scale', (t) async {
      final heights = <String, double>{
        'one car, not based': await _height(t, _d(), scale: scale),
        'based here': await _height(t, _d(basedHere: true, id: 'b'), scale: scale),
        'multi-car': await _height(t, _d(id: 'c'), people: 8, scale: scale),
        'meet at': await _height(t, _d(id: 'd', meetAt: 'Kathgodam station'), scale: scale),
        'no reply': await _height(t, _d(id: 'e'), noReply: true, scale: scale),
        'on the way': await _height(t, _d(id: 'f', section: 'onTheWay', routeFrom: 'Delhi', routeTo: 'Nainital'), scale: scale),
      };
      final first = heights.values.first;
      heights.forEach((k, v) => expect(v, closeTo(first, 1.0), reason: '$k height $v differs from $first: $heights'));
    });
  }

  testWidgets('card has no chip row and no final-fare pill', (t) async {
    await _height(t, _d(basedHere: true));
    expect(find.text('Driver confirms the final fare'), findsNothing);
    expect(find.textContaining('Based here'), findsOneWidget);
  });

  testWidgets('based-in, cars count, no reply and on-the-way text sit in the shared slots', (t) async {
    await _height(t, _d(), people: 8);
    expect(find.textContaining('Based in Haldwani'), findsOneWidget);
    expect(find.textContaining('to Nainital · 2 cars'), findsOneWidget);
    await _height(t, _d(), noReply: true);
    expect(find.textContaining('NO REPLY', findRichText: true), findsOneWidget);
    await _height(t, _d(section: 'onTheWay', routeFrom: 'Delhi', routeTo: 'Nainital'));
    expect(find.textContaining('Going Delhi to Nainital, passes through your stretch'), findsOneWidget);
  });

  testWidgets('based-in falls back to the route start when the city is missing', (t) async {
    await _height(t, _d(city: null, routeFrom: 'Bhimtal'));
    expect(find.textContaining('Based in Bhimtal'), findsOneWidget);
  });

  testWidgets('ridden stretch is shown as sent by the server', (t) async {
    await _height(t, _d(from: 'Haldwani', to: 'Nainital'));
    expect(find.textContaining('Kamalwaganja to Nainital'), findsOneWidget);
  });
}
