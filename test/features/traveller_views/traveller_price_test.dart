import 'dart:io';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_details.dart';
import 'package:bakhli/features/stay/guest/stay_detail_screen.dart';
import 'package:bakhli/features/stay/guest/v2/stay_feed_item.dart';
import 'package:bakhli/features/stay/models/stay_detail_model.dart';
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:bakhli/features/stay/models/stay_price_chip.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/widgets/trip_stay_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/owner_render.dart';
import '../../support/owner_sizes.dart';

Map<String, dynamic> nearbyJson(String id, String name, String type, String city, double km, int base,
        {int? dated, Map<String, dynamic>? chip, bool full = false, String room = 'Double room'}) =>
    {
      'id': id,
      'name': name,
      'stayTypeName': type,
      'latitude': 29.39,
      'longitude': 79.45,
      'minPricePerNight': base,
      'distanceKm': km,
      'isActive': true,
      'cityName': city,
      'bestRoomName': room,
      'datesPerNight': ?dated,
      if (dated != null) 'datesTotal': dated * 3,
      if (dated != null) 'basePerNight': base,
      'priceChip': ?chip,
      'fullOnDates': full,
    };

final _lakeview = StayNearbyModel.fromJson(nearbyJson('s1', 'Lakeview Homestay', 'Homestay', 'Mallital', 0.4, 1800,
    dated: 1530, chip: {'kind': 'Off', 'text': '15% off'}));
final _hillCrest = StayNearbyModel.fromJson(nearbyJson('s2', 'Hill Crest Resort', 'Hotel', 'Bhowali', 6.5, 3000, dated: 3600, room: 'Deluxe room'));
final _pineNest = StayNearbyModel.fromJson(nearbyJson('s3', 'Pine Nest Hostel', 'Hostel', 'Tallital', 1.2, 650, full: true, room: 'Dorm bed'));
final _plain = StayNearbyModel.fromJson(nearbyJson('s4', 'Plain Stay', 'Homestay', 'Mallital', 2, 1800));

Widget _rows(List<StayNearbyModel> stays, {Set<String> shortlisted = const {}, List<String>? taps}) => Scaffold(
      backgroundColor: ListingPalette.forest.page,
      body: ListView(
        children: [
          for (var i = 0; i < stays.length; i++)
            TripStayRow(
              key: ValueKey(stays[i].id),
              stay: stays[i],
              index: i,
              onOpen: () {},
              onCall: () {},
              shortlisted: shortlisted.contains(stays[i].id),
              onShortlist: () => taps?.add(stays[i].id),
            ),
        ],
      ),
    );

void main() {
  group('models', () {
    test('StayPriceChip: only kind Off with text; unknown kind = no chip', () {
      expect(StayPriceChip.fromJson({'kind': 'Off', 'text': '15% off'})?.text, '15% off');
      for (final raw in <Object?>[null, 'x', 7, [], {}, {'kind': 'Higher', 'text': '10% more'}, {'kind': 'Off'}, {'kind': 'Off', 'text': ' '}]) {
        expect(StayPriceChip.fromJson(raw), isNull, reason: '$raw');
      }
      expect(StayPriceChip.money('1530'), 1530);
      expect(StayPriceChip.money(0), isNull);
      expect(StayPriceChip.money('x'), isNull);
    });

    test('o_tr_1 model variants: dated fields of any type never throw', () {
      final base = nearbyJson('s', 'n', 'Homestay', 'c', 1, 1000, dated: 900, chip: {'kind': 'Off', 'text': '10% off'});
      const wrong = <Object?>[null, 'x', 7, <Object?>[], <String, Object?>{}, true];
      for (final key in ['datesTotal', 'datesPerNight', 'basePerNight', 'priceChip', 'fullOnDates']) {
        for (final w in wrong) {
          expect(() => StayNearbyModel.fromJson({...base, key: w}), returnsNormally, reason: '$key=$w');
        }
        expect(() => StayNearbyModel.fromJson({...base}..remove(key)), returnsNormally);
      }
    });

    test('o_tr_1_missingDatedFields_todaysCard: no dated price, no strike, no chip', () {
      expect(_plain.hasDatedPrice, isFalse);
      expect(_plain.struckBase, isNull);
      expect(_plain.priceChip, isNull);
      expect(_hillCrest.struckBase, isNull);
      expect(_lakeview.struckBase, 1800);
    });

    test('o_tr_2 detail model reads title and room dated prices; pricesByDate is never read', () {
      final d = StayDetailModel.fromJson({
        'id': 's1',
        'name': 'Lakeview Homestay',
        'createdAt': '2026-11-19T10:00:00Z',
        'datesFromPerNight': 1530,
        'basePerNight': 1800,
        'priceChip': {'kind': 'Off', 'text': '15% off'},
        'pricesByDate': {'2026-12-18': 1500},
        'rooms': [
          {'id': 'r1', 'roomIndex': 1, 'pricePerNight': 1800, 'maxGuests': 2, 'roomName': 'Deluxe', 'meals': 'Breakfast', 'priceForDates': 1530, 'basePrice': 1800},
          {'id': 'r2', 'roomIndex': 2, 'pricePerNight': 3600, 'maxGuests': 4, 'roomName': 'Family Room', 'meals': 'AllMeals', 'priceForDates': 3060, 'basePrice': 3600},
          {'id': 'r3', 'roomIndex': 3, 'pricePerNight': 2000, 'maxGuests': 2, 'roomName': 'Garden', 'meals': 'None', 'priceForDates': 2400, 'basePrice': 2000},
        ],
      });
      expect(d.struckBase, 1800);
      expect(d.priceChip?.text, '15% off');
      expect(d.datedPriceOf(d.rooms[0])?.price, 1530);
      expect(d.datedPriceOf(d.rooms[0])?.struck, 1800);
      expect(d.datedPriceOf(d.rooms[2])?.struck, isNull);
      expect(File('lib/features/stay/models/stay_detail_model.dart').readAsStringSync().contains('pricesByDate'), isFalse);
    });

    test('o_tr_2_noDates_baseLook: no dated fields = nothing new', () {
      final d = StayDetailModel.fromJson({'id': 's1', 'createdAt': '2026-11-19T10:00:00Z', 'minPricePerNight': 1800, 'rooms': [
        {'id': 'r1', 'roomIndex': 1, 'pricePerNight': 1800, 'maxGuests': 2, 'roomName': 'Deluxe', 'meals': 'None'},
      ]});
      expect(d.datesFromPerNight, isNull);
      expect(d.struckBase, isNull);
      expect(d.roomDatedPrices, isEmpty);
    });

    test('o_tr_2_routeArgsMissing_noCrash: date args are read tolerantly', () {
      expect(StayDetailDates.fromArgs(null), isNull);
      expect(StayDetailDates.fromArgs('id'), isNull);
      expect(StayDetailDates.fromArgs({'id': 'x'}), isNull);
      expect(StayDetailDates.fromArgs({'checkIn': 'soon'}), isNull);
      expect(StayDetailDates.fromArgs({'checkIn': '2026-12-18', 'nights': 3}), {'checkIn': '2026-12-18', 'nights': 3});
      expect(StayDetailDates.fromArgs({'checkIn': '2026-12-18', 'nights': 'x'}), {'checkIn': '2026-12-18'});
    });

    test('o_tr_4_modelVariants: listedPerNight read tolerantly', () {
      final base = <String, dynamic>{'id': 'e1', 'status': 'Asked', 'stayId': 's1'};
      for (final v in <Object?>[null, 'x', [], {}, -5, 0]) {
        expect(() => TripEnquiryModel.fromJson({...base, 'listedPerNight': v}), returnsNormally);
        expect(TripEnquiryModel.fromJson({...base, 'listedPerNight': v}).listedPerNight, isNull);
      }
      expect(TripEnquiryModel.fromJson({...base, 'listedPerNight': 1530}).listedPerNight, 1530);
    });

    test('o_tr_5 feed item chip; missing or unknown = no chip', () {
      final j = {'id': 's1', 'name': 'Lakeview Homestay', 'minPricePerNight': 1800, 'distanceKm': 0.4};
      expect(StayFeedItem.fromJson({...j, 'priceChip': {'kind': 'Off', 'text': '15% off'}}).priceChip?.text, '15% off');
      expect(StayFeedItem.fromJson(j).priceChip, isNull);
      expect(StayFeedItem.fromJson({...j, 'priceChip': {'kind': 'Higher', 'text': '10% more'}}).priceChip, isNull);
    });

    test('o_tr_1_noListedTotalFieldRead / o_tr_3_noListedTotalOnAnyTravellerScreen (guard)', () {
      for (final f in [
        'lib/features/stay/models/stay_nearby_model.dart',
        'lib/features/stay/models/stay_detail_model.dart',
        'lib/features/trip/models/trip_enquiry_model.dart',
        'lib/features/trip/widgets/trip_stay_row.dart',
        'lib/features/trip/screens/trip_replies_screen.dart',
        'lib/features/stay/guest/v2/stay_feed_item.dart',
      ]) {
        final text = File(f).readAsStringSync();
        expect(text.contains('listedStayTotal'), isFalse, reason: f);
      }
    });
  });

  group('o_tr_1 trip stay row price slot', () {
    testWidgets('o_tr_1_lowerPrice_showsNewOldStrikeAndChip', (t) async {
      await t.pumpWidget(MaterialApp(home: _rows([_lakeview])));
      expect(find.text('15% off'), findsOneWidget);
      expect(find.text('₹1,530'), findsOneWidget);
      final was = t.widget<Text>(find.text('₹1,800'));
      expect(was.style?.decoration, TextDecoration.lineThrough);
      expect(find.text('YOUR GROUP'), findsOneWidget);
    });

    testWidgets('o_tr_1_higherPrice_showsPriceOnly', (t) async {
      await t.pumpWidget(MaterialApp(home: _rows([_hillCrest])));
      expect(find.text('₹3,600'), findsOneWidget);
      expect(find.text('₹3,000'), findsNothing);
      expect(find.textContaining('% off'), findsNothing);
    });

    testWidgets('o_tr_1_fullOnDates_greyChipAndDisabledFullButton_cardKeepsPlace', (t) async {
      final taps = <String>[];
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(392, 2400);
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: _rows([_lakeview, _pineNest, _hillCrest], taps: taps)));
      expect(find.text('Full on your dates'), findsOneWidget);
      expect(find.text('Full'), findsOneWidget);
      expect(find.text('FROM'), findsOneWidget);
      expect(find.text('₹650'), findsOneWidget);
      await t.tap(find.text('Full'));
      await t.pump();
      expect(taps, isEmpty);
      final y = [for (final id in ['s1', 's3', 's2']) t.getTopLeft(find.byKey(ValueKey(id))).dy];
      expect(y, orderedEquals([...y]..sort()));
    });

    testWidgets('o_tr_1_priceNeverChangesOrder: rows keep the order they are given', (t) async {
      await t.pumpWidget(MaterialApp(home: _rows([_hillCrest, _lakeview])));
      expect(t.getTopLeft(find.byKey(const ValueKey('s2'))).dy, lessThan(t.getTopLeft(find.byKey(const ValueKey('s1'))).dy));
    });

    testWidgets('o_tr_1_noCheckIn_todaysCard', (t) async {
      await t.pumpWidget(MaterialApp(home: _rows([_plain])));
      expect(find.text('₹1,800'), findsOneWidget);
      expect(find.text('FROM'), findsOneWidget);
      expect(find.textContaining('% off'), findsNothing);
      expect(find.text('Full on your dates'), findsNothing);
    });

    testOwnerSizes('o_tr_1 rows 0', () => _rows(const []));
    testOwnerSizes('o_tr_1 rows 3', () => _rows([_lakeview, _hillCrest, _pineNest], shortlisted: {'s1', 's2'}));
    testOwnerSizes('o_tr_1 rows 12', () => _rows([for (var i = 0; i < 4; i++) ...[_lakeview, _hillCrest, _pineNest]]));
  });

  group('o_tr_2 detail price slots', () {
    Widget detail({bool dated = true}) => Scaffold(
          body: ListView(children: [
            DetailTitleCard(
              tone: ListingTone.forest,
              eyebrow: 'FOR STAY',
              title: 'Lakeview Homestay',
              caption: 'FROM',
              value: dated ? '₹1,530' : '₹1,800',
              unit: '/night',
              was: dated ? '₹1,800' : null,
              chip: dated ? '15% off' : null,
            ),
            DetailSlimCard(tone: ListingTone.forest, art: ListingArt.bed, title: 'Deluxe', subtitle: '2 guests · Breakfast', price: '₹1,530', unit: '/night', was: dated ? '₹1,800' : null),
          ]),
        );

    testWidgets('o_tr_2_datedTitleCardShowsNewOldAndChip and o_tr_2_roomRowsShowDatedPriceWithStrike', (t) async {
      await t.pumpWidget(MaterialApp(home: detail()));
      expect(find.text('15% off'), findsOneWidget);
      expect(find.text('₹1,800'), findsNWidgets(2));
      for (final e in t.widgetList<Text>(find.text('₹1,800'))) {
        expect(e.style?.decoration, TextDecoration.lineThrough);
      }
    });

    testWidgets('o_tr_2_noDates_baseLook', (t) async {
      await t.pumpWidget(MaterialApp(home: detail(dated: false)));
      expect(find.textContaining('% off'), findsNothing);
      expect(find.text('₹1,800'), findsOneWidget);
    });

    test('o_tr_2_noShortlistNoEnquiryButton and o_tr_2_noNightByNightLine (guard on the detail screen)', () {
      final text = File('lib/features/stay/guest/stay_detail_screen.dart').readAsStringSync();
      expect(text.contains('Shortlist'), isFalse);
      expect(text.contains('pricesByDate'), isFalse);
    });

    testOwnerSizes('o_tr_2 cards', () => detail());
  });

  group('render', () {
    useOwnerRenderScale();

    testWidgets('render o_tr_1 (rows only, inside the existing screen body)', (t) async {
      await renderOwnerFrame(t, 'o_tr_1', _rows([_lakeview, _hillCrest, _pineNest], shortlisted: {'s1', 's2'}));
      expect(t.takeException(), isNull);
    });

    testWidgets('render o_tr_2 (price cards of the detail)', (t) async {
      await renderOwnerFrame(
        t,
        'o_tr_2',
        Scaffold(
          backgroundColor: ListingPalette.forest.page,
          body: ListView(children: [
            DetailTitleCard(
              tone: ListingTone.forest,
              eyebrow: 'FOR STAY',
              title: 'Lakeview Homestay',
              caption: 'FROM',
              value: '₹1,530',
              unit: '/night',
              was: '₹1,800',
              chip: '15% off',
            ),
            const TitleRow3D(title: 'Rooms'),
            DetailSlimCard(tone: ListingTone.forest, art: ListingArt.bed, title: 'Deluxe', subtitle: '2 guests · Breakfast', price: '₹1,530', unit: '/night', was: '₹1,800'),
            DetailSlimCard(tone: ListingTone.teal, art: ListingArt.bed, title: 'Family Room', subtitle: '4+ guests · All meals', price: '₹3,060', unit: '/night', was: '₹3,600'),
          ]),
        ),
      );
    });
  });
}
