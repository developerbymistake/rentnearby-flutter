import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/taxi_calm_card.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/taxi/guest/taxi_card.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/real_phone.dart';

const _sizes = [320.0, 360.0, 411.0];
const _scales = [1.0, 1.3];

TaxiBrowseItem _taxi({
  String id = 't1',
  String vehicle = 'Innova',
  int? seats = 7,
  bool featured = false,
  String? photo,
  int? matchedFare,
  String? matchedTo,
  String? tripType,
  bool reversed = false,
  int? dayRate,
  int? dayKm,
}) =>
    TaxiBrowseItem.fromJson({
      'id': id,
      'driverName': 'Rakesh Singh',
      'vehicleTypeName': vehicle,
      'seats': seats,
      'plateDisplay': 'UK 04 AB 1234',
      'routeCount': 1,
      'cityName': 'Haldwani',
      'isFeatured': featured,
      'displayPhotoUrl': photo,
      'matchedFare': matchedFare,
      'matchedToName': matchedTo,
      'matchedTripType': tripType,
      'matchReversed': reversed,
      'localDayRate': dayRate,
      'localDayKm': dayKm,
      'createdAt': '2030-01-01T00:00:00Z',
    });

NearbyDistance _near(NearbyLabel label, double km, String city) => NearbyDistance(km: km, label: label, city: city);

Future<void> _pump(WidgetTester t, Widget child, {double width = 360, double scale = 1.0}) async {
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, Scaffold(body: SingleChildScrollView(child: child)), size: Size(width, 1200), textScale: scale);
}

void _sized(String name, Future<void> Function(WidgetTester t, double width, double scale) body) {
  for (final w in _sizes) {
    for (final s in _scales) {
      testWidgets('$name at ${w.toInt()} @$s', (t) async {
        await body(t, w, s);
        expect(t.takeException(), isNull);
      });
    }
  }
}

void main() {
  _sized('display photo goes in the circle; none = vehicle art', (t, w, s) async {
    await _pump(t, TaxiCard(item: _taxi(photo: 'https://example.com/d.jpg'), onOpen: () {}), width: w, scale: s);
    expect(t.widget<PhotoCircle>(find.byType(PhotoCircle)).url, 'https://example.com/d.jpg');
    expect(find.byKey(PhotoCircle.photoKey), findsOneWidget);
    await _pump(t, TaxiCard(item: _taxi(), onOpen: () {}), width: w, scale: s);
    expect(find.byKey(PhotoCircle.photoKey), findsNothing);
    expect(t.widget<PhotoCircle>(find.byType(PhotoCircle)).art, 'assets/images/design/travel3d/taxi.png');
    await _pump(t, TaxiCard(item: _taxi(vehicle: 'Tempo Traveller', seats: 12), onOpen: () {}), width: w, scale: s);
    expect(t.widget<PhotoCircle>(find.byType(PhotoCircle)).art, 'assets/images/design/travel3d/bus.png');
  });

  testWidgets('featured: one star badge, tag TAXI, no Featured text', (t) async {
    await _pump(t, TaxiCard(item: _taxi(featured: true), onOpen: () {}));
    expect(find.byKey(PhotoCircle.starKey), findsOneWidget);
    expect(find.text('TAXI'), findsOneWidget);
    expect(find.textContaining('Featured'), findsNothing);
  });

  testWidgets('fare: route match, local day rate, ask for fare', (t) async {
    await _pump(t, TaxiCard(item: _taxi(matchedFare: 2400, matchedTo: 'Nainital', tripType: 'RoundTrip'), onOpen: () {}));
    expect(find.text('₹2,400'), findsOneWidget);
    expect(find.text('to Nainital'), findsOneWidget);
    expect(find.text('Round trip'), findsOneWidget);
    await _pump(t, TaxiCard(item: _taxi(dayRate: 1600, dayKm: 80), onOpen: () {}));
    expect(find.text('₹1,600'), findsOneWidget);
    expect(find.text('/day local'), findsOneWidget);
    expect(find.text('80 km/day'), findsOneWidget);
    await _pump(t, TaxiCard(item: _taxi(), onOpen: () {}));
    expect(find.text('Ask for fare'), findsOneWidget);
    expect(t.widget<Text>(find.text('Ask for fare')).style?.fontSize, isNot(TypeTokens.style(18, FontWeight.w800).fontSize));
  });

  _sized('address one line: near and in city', (t, w, s) async {
    await _pump(t, TaxiCard(item: _taxi(), distance: _near(NearbyLabel.near, 5, 'Haldwani'), onOpen: () {}), width: w, scale: s);
    expect(find.text('Haldwani. About 5 km'), findsOneWidget);
    expect(t.widget<Text>(find.text('Haldwani. About 5 km')).maxLines, 1);
    expect(find.textContaining('Based near'), findsNothing);
    expect(find.textContaining('away'), findsNothing);
    await _pump(t, TaxiCard(item: _taxi(), distance: _near(NearbyLabel.inCity, 1, 'Bhimtal'), onOpen: () {}), width: w, scale: s);
    expect(find.text('In Bhimtal'), findsOneWidget);
  });

  testWidgets('hero radius and one coral theme for every row', (t) async {
    await _pump(t, Column(children: [for (var i = 0; i < 3; i++) TaxiCard(key: ValueKey(i), item: _taxi(id: 't$i', dayRate: 1600 + i), onOpen: () {})]));
    for (var i = 0; i < 3; i++) {
      expect(t.widget<Text>(find.text('₹1,60$i')).style?.color, ListingPalette.coral.text);
    }
    final box = t
        .widgetList<Container>(find.descendant(of: find.byType(TaxiCalmCard).first, matching: find.byType(Container)))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.gradient != null);
    expect(box.borderRadius, DS.br(CardRadius.hero));
  });

  for (final w in _sizes) {
    testWidgets('circle sticks out 10% above the card at ${w.toInt()}', (t) async {
      await _pump(t, TaxiCard(item: _taxi(), onOpen: () {}), width: w);
      final circle = t.getRect(find.byType(PhotoCircle));
      final cardTop = t.getTopLeft(find.byType(ClipRRect).first).dy;
      expect(cardTop - circle.top, closeTo(circle.height * 0.10, 1.0));
      final cardWidth = t.getSize(find.byType(ClipRRect).first).width;
      expect(circle.height, closeTo(DS.s(TaxiCalmCard.circleFor(cardWidth)), 0.5));
    });
  }

  testWidgets('browse mode: Call and WhatsApp keys', (t) async {
    await _pump(t, TaxiCard(item: _taxi(), onOpen: () {}));
    expect(find.byKey(TaxiCard.callKey), findsOneWidget);
    expect(find.byKey(TaxiCard.whatsAppKey), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
  });

  testWidgets('inLabel mode: one Call pill, address is the label', (t) async {
    await _pump(t, TaxiCard(item: _taxi(), inLabel: 'In Bhimtal', onOpen: () {}));
    expect(find.byKey(TaxiCard.callKey), findsOneWidget);
    expect(find.byType(CalmPillButton), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('In Bhimtal'), findsOneWidget);
  });

  testWidgets('trip mode: Select / Selected and I booked / Booked in the second row', (t) async {
    var opens = 0;
    var selects = 0;
    await _pump(t, TaxiCard(item: _taxi(), onOpen: () => opens++, onSelect: () => selects++, onBook: () {}, onEnquire: () {}));
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('I booked'), findsOneWidget);
    expect(find.text('Enquiry'), findsOneWidget);
    final selectY = t.getCenter(find.text('Select')).dy;
    expect(selectY, greaterThan(t.getCenter(find.text('Call')).dy));
    await t.tap(find.text('Select'));
    await t.pump(const Duration(milliseconds: 300));
    expect((opens, selects), (0, 1));
    await _pump(t, TaxiCard(item: _taxi(), onOpen: () {}, onSelect: () {}, selected: true, onBook: () {}, booked: true));
    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('Booked'), findsOneWidget);
    expect(t.widget<CalmPillButton>(find.ancestor(of: find.text('Booked'), matching: find.byType(CalmPillButton))).action.selected, isTrue);
  });

  _sized('long vehicle, three chips, far address fit', (t, w, s) async {
    await _pump(
      t,
      TaxiCalmCard(
        title: 'Sunil Kumar Negi Bhandari',
        lines: const ['Tempo Traveller · 12+ seats', 'Almora'],
        art: 'assets/images/design/travel3d/bus.png',
        featured: true,
        chips: const ['Local taxi', '12+ seats', '80 km/day'],
        price: '₹1,600',
        unit: '/day local',
        address: 'Almora Cantonment Area. About 210 km',
        actions: [
          CalmAction(kind: CalmActionKind.call, label: 'Call', onTap: () {}),
          CalmAction(kind: CalmActionKind.whatsApp, label: 'WhatsApp', onTap: () {}),
        ],
      ),
      width: w,
      scale: s,
    );
  });
}
