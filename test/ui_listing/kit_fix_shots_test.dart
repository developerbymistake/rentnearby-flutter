import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/taxi/guest/taxi_card.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/trip/widgets/trip_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/real_phone.dart';

TaxiBrowseItem _taxi({String name = 'Pradeep Kumar', String vehicle = 'Dzire', int? seats = 4, int? fare = 2400, bool featured = false, int? localRate, String round = 'OneWay'}) =>
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

Widget _photo() => const ColoredBox(color: Color(0xFF6E8FA8));

Widget _stay(String title, {bool featured = false, bool photo = true, String number = '₹1,500', String unit = '/night', String? cap = 'FROM', List<String> chips = const ['Homestay', 'Breakfast', 'Deluxe room']}) => WideCard(
      tone: ListingTone.cE,
      kind: WideKind.photo,
      photo: photo ? _photo() : null,
      sticker: ListingArt.key,
      badge: featured ? 'Featured' : null,
      tag: 'Homestay',
      title: title,
      subtitle: 'Kausani, Bageshwar',
      chips: chips,
      priceCaption: cap,
      number: number,
      unit: unit,
      label: 'Kathgodam. About 12 km away',
      actions: [
        WideAction(icon: Icons.phone_rounded, label: 'Call', onTap: () {}),
        WideAction(icon: Icons.mail_rounded, label: 'Enquiry', onTap: () {}),
      ],
      onTap: () {},
    );

const _near = NearbyDistance(km: 5, label: NearbyLabel.near, city: 'Haldwani', state: 'Uttarakhand');
const _far = NearbyDistance(km: 210, label: NearbyLabel.far, city: 'Haridwar', state: 'Uttarakhand');

Widget _page(Color bg, List<Widget> kids) => Scaffold(
      backgroundColor: bg,
      body: ListView(padding: const EdgeInsets.fromLTRB(0, 20, 0, 40), children: kids),
    );

final _configs = <(double, double)>[(360, 1.0), (360, 1.3), (300, 1.0), (300, 1.3)];

Future<void> _run(WidgetTester t, String name, Widget page, double w, double s, {double h = 2000}) async {
  debugDisableShadows = false;
  await pumpPhone(t, page, size: Size(w, h), devicePixelRatio: 1.5, textScale: s);
  await settlePhone(t);
  await shot(t, '${name}_${w.toInt()}_${s == 1.0 ? '10' : '13'}');
  final e = t.takeException();
  debugDisableShadows = true;
  expect(e, isNull);
}

void main() {
  setUp(() => shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\kit');

  for (final (w, s) in _configs) {
    testWidgets('stays $w $s', (t) async {
      await _run(
        t,
        'stays',
        _page(ListingPalette.forest.page, [
          _stay('Deodar Cottage', featured: true),
          _stay('Himalayan View Heritage Homestay with Lake Facing Rooms', number: '₹1,24,800', unit: '/night for two guests'),
          _stay('Pine Ridge Stay', photo: false, number: 'On request', unit: '', cap: null, chips: const []),
        ]),
        w,
        s,
        h: 2300,
      );
    });

    testWidgets('taxi $w $s', (t) async {
      await _run(
        t,
        'taxi',
        _page(ListingPalette.coral.page, [
          TaxiCard(item: _taxi(featured: true, vehicle: 'Toyota Innova Crysta', seats: 7), distance: _near, onOpen: () {}),
          TaxiCard(item: _taxi(name: 'Mohan Singh Rawat', vehicle: 'Innova', seats: 7, round: 'RoundTrip'), distance: _far, onOpen: () {}),
          TaxiCard(item: _taxi(name: 'Sunil Local', fare: null, vehicle: 'Traveller', seats: 12), onOpen: () {}),
        ]),
        w,
        s,
        h: 2100,
      );
    });

    testWidgets('trip $w $s', (t) async {
      await _run(
        t,
        'trip',
        _page(ListingPalette.coral.page, [
          TaxiCard(item: _taxi(), onOpen: () {}, onSelect: () {}, onBook: () {}, onEnquire: () {}, enquiryStatus: TripDisplayStatus.asked),
          TaxiCard(item: _taxi(name: 'Selected Driver'), onOpen: () {}, onSelect: () {}, selected: true, onBook: () {}, onEnquire: () {}),
          WideCard(
            tone: ListingTone.cB,
            art: ListingArt.luggage,
            title: 'Nainital, Kausani and Almora weekend',
            subtitle: '12 Dec to 15 Dec\nNext: stay in Kausani',
            chips: const ['3 of 5 done', '1 needs you'],
            showPrice: false,
            progress: 1,
            onTap: () {},
          ),
        ]),
        w,
        s,
        h: 2000,
      );
    });

    testWidgets('rails $w $s', (t) async {
      await _run(
        t,
        'rails',
        _page(ListingPalette.indigo.page, [
          MealsRail(children: [
            MealsCardV(tone: ListingTone.cE, tag: 'Homestay', title: 'Deodar Cottage', description: 'Kausani', chips: const ['Featured', 'Homestay', 'Breakfast', 'Deluxe room'], photo: _photo(), sticker: ListingArt.key, caption: 'FROM', number: '₹1,500', unit: '/night', onTap: () {}),
            MealsCardV(tone: ListingTone.cB, tag: 'Hotel', title: 'Himalayan View Heritage', description: 'Nainital', chips: const ['Hotel'], art: ListingArt.hotel, caption: 'FROM', number: '₹12,500', unit: '/night', onTap: () {}),
            MealsCardV(tone: ListingTone.cA, tag: 'TAXI', title: 'Pradeep Kumar', description: 'Haldwani', chips: const ['Featured', 'Traveller', '12 seats'], art: ListingArt.taxi, caption: 'FARE FROM', number: '₹1,800', onTap: () {}),
          ]),
          const SizedBox(height: 30),
          WorkoutCard(tone: ListingTone.forest, art: ListingArt.hotel, eyebrow: 'Looking for a stay?', title: 'Find your stay', subtitle: 'Browse stays near you', ctaLabel: 'Browse Stays', trailing: WorkoutTrailing.dots, onTap: () {}),
          const SizedBox(height: 20),
          WorkoutCard(tone: ListingTone.indigo, art: ListingArt.luggage, eyebrow: 'Travel Planner', title: 'Plan a trip', subtitle: 'Places, days, stay and taxi', trailing: WorkoutTrailing.arrow, onTap: () {}),
          const SizedBox(height: 20),
          WorkoutCard(tone: ListingTone.coral, art: ListingArt.taxi, eyebrow: 'Featured · Dzire · 4 seats', title: 'Pradeep Kumar', subtitle: 'Haldwani to Nainital', chips: const ['Round trip', '₹2,400'], trailing: WorkoutTrailing.arrow, onTap: () {}),
          const SizedBox(height: 20),
          WorkoutCard(tone: ListingTone.forest, art: ListingArt.luggage, eyebrow: 'Your trip', title: 'All arranged', subtitle: 'Places, days, stay and taxi', ctaLabel: 'Open summary', trailing: WorkoutTrailing.ring, progress: 1, minHeight: 200, onTap: () {}),
        ]),
        w,
        s,
        h: 1900,
      );
    });
  }
}
