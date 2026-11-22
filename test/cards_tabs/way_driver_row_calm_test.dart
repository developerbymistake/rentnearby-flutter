import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/taxi_calm_card.dart';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_strings.dart';
import 'package:bakhli/features/taxi/ways/widgets/way_driver_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/real_phone.dart';

WayDriver _d({bool featured = false, String? photo, String vehicle = 'Sedan'}) => WayDriver.fromJson({
      'taxiId': 'a',
      'driverName': 'Ramesh Negi',
      'vehicleTypeName': vehicle,
      'seats': 4,
      'cityName': 'Haldwani',
      'basedHere': false,
      'fromName': 'Haldwani',
      'toName': 'Nainital',
      'listedFare': 1500,
      'section': 'direct',
      'isFeatured': featured,
      'displayPhotoUrl': ?photo,
    });

Future<void> _pump(WidgetTester t, Widget row, {double width = 360, double scale = 1.0}) async {
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, Scaffold(body: SingleChildScrollView(child: row)), size: Size(width, 1000), textScale: scale);
}

CalmAction _action(WidgetTester t, String label) =>
    t.widget<CalmPillButton>(find.ancestor(of: find.text(label), matching: find.byType(CalmPillButton))).action;

void main() {
  testWidgets('Shortlist and Shortlisted', (t) async {
    var taps = 0;
    await _pump(t, WayDriverRow(driver: _d(), onTap: () {}, onCall: () {}, onShortlist: () => taps++));
    expect(_action(t, 'Shortlist').selected, isFalse);
    await t.tap(find.text('Shortlist'));
    await t.pump(const Duration(milliseconds: 300));
    expect(taps, 1);
    await _pump(t, WayDriverRow(driver: _d(), onTap: () {}, onCall: () {}, onShortlist: () {}, shortlisted: true));
    expect(_action(t, 'Shortlisted').selected, isTrue);
    expect(t.widget<TaxiCalmCard>(find.byType(TaxiCalmCard)).picked, isTrue);
  });

  testWidgets('Use for my trip and busy Call', (t) async {
    await _pump(t, WayDriverRow(driver: _d(), onTap: () {}, onCall: () {}, callBusy: true, onUse: () {}));
    expect(find.text('Use for my trip'), findsOneWidget);
    expect(_action(t, 'Use for my trip').kind, CalmActionKind.plain);
    expect(_action(t, 'Call').busy, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('No reply and Best way are chips, tag stays TAXI', (t) async {
    await _pump(t, WayDriverRow(driver: _d(), onTap: () {}, onShortlist: () {}, noReply: true, bestReason: 'Cheapest for 2 people'));
    expect(find.descendant(of: find.byType(CalmChip), matching: find.text('No reply')), findsOneWidget);
    expect(find.descendant(of: find.byType(CalmChip), matching: find.text(TaxiWaysStrings.bestWay)), findsOneWidget);
    expect(find.text('TAXI'), findsOneWidget);
    expect(find.text('Cheapest for 2 people'), findsOneWidget);
  });

  testWidgets('featured star, photo vs art', (t) async {
    await _pump(t, WayDriverRow(driver: _d(featured: true, photo: 'https://example.com/p.jpg'), onTap: () {}));
    expect(find.byKey(PhotoCircle.starKey), findsOneWidget);
    expect(find.byKey(PhotoCircle.photoKey), findsOneWidget);
    expect(find.textContaining('Featured'), findsNothing);
    await _pump(t, WayDriverRow(driver: _d(), onTap: () {}));
    expect(find.byKey(PhotoCircle.starKey), findsNothing);
    expect(find.byKey(PhotoCircle.photoKey), findsNothing);
    expect(t.widget<PhotoCircle>(find.byType(PhotoCircle)).art, ListingArt.forVehicle('Sedan'));
  });

  testWidgets('group fare and unit text unchanged', (t) async {
    await _pump(t, WayDriverRow(driver: _d(), people: 8, onTap: () {}));
    expect(find.text('₹3,000'), findsOneWidget);
    expect(find.textContaining('to Nainital · 2 cars'), findsOneWidget);
  });

  for (final w in [320.0, 360.0, 411.0]) {
    for (final s in [1.0, 1.3]) {
      testWidgets('fits at ${w.toInt()} @$s', (t) async {
        await _pump(
          t,
          Column(children: [
            WayDriverRow(driver: _d(featured: true), people: 8, noReply: true, bestReason: 'Cheapest for 8 people', onTap: () {}, onCall: () {}, onShortlist: () {}, shortlisted: true),
            WayDriverRow(driver: _d(vehicle: 'Tempo Traveller'), onTap: () {}, onCall: () {}, onUse: () {}),
          ]),
          width: w,
          scale: s,
        );
        expect(t.takeException(), isNull);
      });
    }
  }
}
