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

  testWidgets('featured: one star badge, no TAXI tag, no Featured text', (t) async {
    await _pump(t, TaxiCard(item: _taxi(featured: true), onOpen: () {}));
    expect(find.byKey(PhotoCircle.starKey), findsOneWidget);
    expect(find.text('TAXI'), findsNothing);
    expect(find.textContaining('Featured'), findsNothing);
  });

  testWidgets('header: name first at 14, chips under the vehicle line, no Local taxi chip', (t) async {
    await _pump(t, TaxiCard(item: _taxi(dayRate: 2500, dayKm: 30), distance: _near(NearbyLabel.inCity, 1, 'Haldwani'), onOpen: () {}));
    expect(find.text('Local taxi'), findsNothing);
    final name = find.text('Rakesh Singh');
    expect(t.widget<Text>(name).style?.fontSize, TypeTokens.style(14, FontWeight.w700).fontSize);
    final cardTop = t.getTopLeft(find.byType(ClipRRect).first).dy;
    expect(t.getTopLeft(name).dy - cardTop, closeTo(DS.s(TaxiCalmCard.cardTopPad), 1.0));
    final vehicle = find.text('Innova · 7 seats');
    final chip = find.ancestor(of: find.text('30 km/day'), matching: find.byType(CalmChip));
    expect(t.getTopLeft(chip).dy, greaterThan(t.getBottomLeft(vehicle).dy));
    expect(t.getTopLeft(chip).dx, closeTo(t.getTopLeft(name).dx, 1.0));
    expect(t.widget<CalmChip>(chip).textSize, TaxiCalmCard.listingChipText);
    final chipSize = t.widget<Text>(find.text('30 km/day')).style!.fontSize!;
    expect(chipSize, TypeTokens.style(13, FontWeight.w700, chip: true).fontSize);
    expect(chipSize, greaterThan(TypeTokens.style(10, FontWeight.w700, chip: true).fontSize!));
    expect(t.getTopLeft(find.text('₹2,500')).dy, greaterThan(t.getBottomLeft(chip).dy));
  });

  testWidgets('price is one line with a short top rule, no side divider', (t) async {
    await _pump(t, TaxiCard(item: _taxi(dayRate: 2500, dayKm: 30), onOpen: () {}));
    expect(t.getCenter(find.text('/day local')).dx, greaterThan(t.getCenter(find.text('₹2,500')).dx));
    final value = t.getRect(find.text('₹2,500'));
    final unitY = t.getCenter(find.text('/day local')).dy;
    expect(unitY, inInclusiveRange(value.top, value.bottom));
    final block = find.byType(CalmPriceBlock);
    expect(t.widget<CalmPriceBlock>(block).oneLine, isTrue);
    final rule = t
        .widgetList<Container>(find.descendant(of: block, matching: find.byType(Container)))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.border != null)
        .border! as Border;
    expect(rule.top.style, BorderStyle.solid);
    expect(rule.left, BorderSide.none);
    expect(t.getSize(block).width, lessThan(t.getSize(find.byType(ClipRRect).first).width / 2));
  });

  testWidgets('locality shows once: header keeps it only when the bottom row has no address', (t) async {
    await _pump(t, TaxiCard(item: _taxi(), distance: _near(NearbyLabel.inCity, 1, 'Haldwani'), onOpen: () {}));
    expect(find.text('In Haldwani'), findsOneWidget);
    expect(find.text('Haldwani'), findsNothing);
    await _pump(t, TaxiCard(item: _taxi(), inLabel: 'In Bhimtal', onOpen: () {}));
    expect(find.text('Haldwani'), findsNothing);
    await _pump(t, TaxiCard(item: _taxi(), onOpen: () {}, onSelect: () {}, onEnquire: () {}));
    expect(find.text('Haldwani'), findsOneWidget);
  });

  _sized('circle and its ring stay above the address row line', (t, w, s) async {
    await _pump(t, TaxiCard(item: _taxi(dayRate: 2500, dayKm: 30), distance: _near(NearbyLabel.inCity, 1, 'Haldwani'), onOpen: () {}),
        width: w, scale: s);
    final circle = t.getRect(find.byType(PhotoCircle));
    final line = t.getTopLeft(find.byType(CalmBottomRow)).dy;
    expect(circle.bottom + DS.s(PhotoCircle.ring), lessThanOrEqualTo(line + 0.5));
  });

  _sized('long name, many chips and long fare unit fit the listing header', (t, w, s) async {
    await _pump(
      t,
      TaxiCalmCard(
        layout: TaxiCalmLayout.listing,
        tag: null,
        title: 'Sunil Kumar Negi Bhandari Tour and Travels Almora',
        lines: const ['Tempo Traveller · 12+ seats'],
        art: 'assets/images/design/travel3d/bus.png',
        featured: true,
        chips: const ['Round trip', '12+ seats', 'Reverse', 'Listed Jan 2030'],
        price: '₹12,600',
        unit: 'to Pithoragarh Cantonment',
        address: 'Almora Cantonment Area. About 210 km',
        actions: [
          CalmAction(kind: CalmActionKind.call, label: 'Call', onTap: () {}),
          CalmAction(kind: CalmActionKind.whatsApp, label: 'WhatsApp', onTap: () {}),
        ],
      ),
      width: w,
      scale: s,
    );
    expect(find.text('TAXI'), findsNothing);
  });

  testWidgets('one TalkBack button for the whole tappable card', (t) async {
    final handle = t.ensureSemantics();
    await _pump(t, TaxiCard(item: _taxi(dayRate: 2500, dayKm: 30), onOpen: () {}));
    expect(
      find.byWidgetPredicate((w) => w is Semantics && w.properties.button == true && w.properties.label == 'Rakesh Singh'),
      findsOneWidget,
    );
    handle.dispose();
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
