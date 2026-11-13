import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/taxi/guest/taxi_card.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/trip/widgets/trip_status.dart';
import 'package:bakhli/models/card_fact.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/real_phone.dart';

TaxiBrowseItem _taxi({
  String name = 'Pradeep Kumar',
  String vehicle = 'Dzire',
  int? seats = 4,
  int? fare = 2400,
  bool featured = false,
  int? localRate,
  String round = 'OneWay',
}) =>
    TaxiBrowseItem(
      id: name,
      driverName: name,
      vehicleTypeName: vehicle,
      seats: seats,
      plateDisplay: 'UK 04 AB 1234',
      cityName: 'Haldwani',
      routeCount: 3,
      matchedFare: fare,
      matchedFromName: 'Haldwani',
      matchedToName: fare == null ? null : 'Nainital',
      matchedTripType: round,
      minFare: 1800,
      matchReversed: false,
      createdAt: DateTime(2030, 1, 1),
      isFeatured: featured,
      localDayRate: localRate,
      localDayKm: localRate == null ? null : 80,
    );

Widget _stay(String title, {bool featured = false, String tag = 'HOMESTAY', List<CardFact>? facts}) => WideCard(
      tone: ListingTone.forest,
      kind: WideKind.photo,
      sticker: ListingArt.key,
      badge: featured ? 'Featured' : null,
      tag: tag,
      title: title,
      subtitle: 'Kausani, Bageshwar',
      chips: [for (final f in facts ?? const [CardFact('3 rooms'), CardFact('Breakfast')]) f.label],
      priceCaption: 'FROM',
      number: 'Rs 1,500',
      unit: '/night',
      actions: [
        WideAction(icon: Icons.phone_rounded, label: 'Call', onTap: () {}),
        WideAction(icon: Icons.mail_rounded, label: 'Enquiry', onTap: () {}),
      ],
      onTap: () {},
    );

Widget _page(ListingPalette p, List<Widget> kids) => Scaffold(
      backgroundColor: p.page,
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 40, 20, 40), children: kids),
    );

void main() {
  setUp(() => shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Listing\shots');

  for (final scale in [1.0, 1.3]) {
    final s = scale == 1.0 ? '' : '_x13';
    testWidgets('stay cards $scale', (tester) async {
      await pumpPhone(
        tester,
        _page(ListingPalette.forest, [
          _stay('Deodar Cottage', featured: true),
          _stay('Himalayan View Heritage Homestay with Lake Facing Rooms and a very long name'),
          _stay('Pine Ridge Stay', tag: 'HOTEL', facts: const [CardFact('Hotel'), CardFact('Breakfast'), CardFact('Parking')]),
        ]),
        textScale: scale,
      );
      await settlePhone(tester);
      await shot(tester, 'stay_cards$s');
      expect(tester.takeException(), isNull);
    });

    testWidgets('taxi cards $scale', (tester) async {
      await pumpPhone(
        tester,
        _page(ListingPalette.coral, [
          TaxiCard(item: _taxi(featured: true), onOpen: () {}),
          TaxiCard(item: _taxi(name: 'Rakesh Singh Rawat Kumar Negi Bisht', vehicle: 'Innova', seats: 7, round: 'RoundTrip'), onOpen: () {}),
          TaxiCard(item: _taxi(name: 'Sunil Local', fare: null, localRate: 16, vehicle: 'Traveller', seats: 12), onOpen: () {}),
        ]),
        textScale: scale,
      );
      await settlePhone(tester);
      await shot(tester, 'taxi_cards$s');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('taxi trip mode', (tester) async {
    await pumpPhone(
      tester,
      _page(ListingPalette.coral, [
        TaxiCard(item: _taxi(), onOpen: () {}, onSelect: () {}, onBook: () {}, onEnquire: () {}),
        TaxiCard(item: _taxi(name: 'Selected Driver'), onOpen: () {}, onSelect: () {}, selected: true, onBook: () {}, onEnquire: () {}, enquiryStatus: TripDisplayStatus.asked),
        TaxiCard(item: _taxi(name: 'Booked Driver'), onOpen: () {}, onSelect: () {}, onBook: () {}, booked: true, onEnquire: () {}),
      ]),
    );
    await settlePhone(tester);
    await shot(tester, 'taxi_trip_mode');
    expect(tester.takeException(), isNull);
  });
}
