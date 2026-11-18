import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/taxi/requests/controllers/driver_requests_controller.dart';
import 'package:bakhli/features/taxi/requests/data/driver_request_repository.dart';
import 'package:bakhli/features/taxi/requests/driver_request_detail_screen.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';

const _id = 'a1b2c3d4-0001-4a00-8000-000000000001';

Map<String, dynamic> _sample(String name) =>
    jsonDecode(File('test/features/taxi_request/samples/$name').readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> _nineDays(Map<String, dynamic> base) {
  const cities = ['Nainital', 'Nainital', 'Nainital', 'Ranikhet', 'Kausani', 'Almora', 'Almora', 'Jim Corbett', 'Jim Corbett'];
  final days = [
    for (var i = 0; i < 9; i++)
      {
        'day': i + 1,
        'date': '2026-12-${18 + i}',
        'city': cities[i],
        'taxi': i != 2 && i != 6 && i != 8,
        'km': 20 + i,
        'minutes': 230 + i * 20,
        'places': ['Naini Lake', 'Snow View Point', 'Eco Cave Gardens', 'A very long place name for overflow checking'],
      },
  ];
  final trip = Map<String, dynamic>.from(base['trip'] as Map);
  return {
    ...base,
    'dateFrom': '2026-12-18',
    'dateTo': '2026-12-26',
    'dayCount': 9,
    'nightCount': 8,
    'sightseeingDayCount': 6,
    'trip': {
      ...trip,
      'cities': [
        {'name': 'Nainital', 'nights': 3, 'from': '2026-12-18', 'to': '2026-12-21'},
        {'name': 'Ranikhet', 'nights': 1, 'from': '2026-12-21', 'to': '2026-12-22'},
        {'name': 'Kausani', 'nights': 1, 'from': '2026-12-22', 'to': '2026-12-23'},
        {'name': 'Almora', 'nights': 2, 'from': '2026-12-23', 'to': '2026-12-25'},
        {'name': 'Jim Corbett', 'nights': 1, 'from': '2026-12-25', 'to': '2026-12-26'},
      ],
      'drop': {'name': 'Kathgodam', 'sameAsPickup': true, 'date': '2026-12-26'},
      'days': days,
    },
  };
}

class _FakeRepo extends DriverRequestRepository {
  _FakeRepo(this.json);

  Map<String, dynamic> json;
  final List<String> calls = [];
  TaxiResult<DriverOffer>? result;

  @override
  Future<TaxiResult<DriverOffer>> offer(String offerId) async => TaxiOk(DriverOffer.fromJson(json));

  @override
  Future<TaxiResult<DriverOffer>> accept(String offerId) async {
    calls.add('accept');
    return result ?? TaxiOk(DriverOffer.fromJson({...json, 'state': 'Accepted'}));
  }

  @override
  Future<TaxiResult<DriverOffer>> decline(String offerId, {ReasonChip? chip}) async {
    calls.add('decline');
    return result ?? TaxiOk(DriverOffer.fromJson({...json, 'state': 'Declined'}));
  }

  @override
  Future<TaxiResult<DriverOffer>> confirm(String offerId) async {
    calls.add('confirm');
    return result ?? TaxiOk(DriverOffer.fromJson({...json, 'state': 'Confirmed'}));
  }

  @override
  Future<TaxiResult<DriverOfferList>> offers({String? cursor}) async => const TaxiOffline();
}

class _Rig {
  _Rig(this.json) : repo = _FakeRepo(json) {
    controller = DriverRequestsController(repo: repo, now: () => DateTime.utc(2026, 12, 10, 9, 46, 0));
  }

  final Map<String, dynamic> json;
  final _FakeRepo repo;
  late final DriverRequestsController controller;
  final List<String> phones = [];
  int backs = 0;
  int bookings = 0;

  Widget screen() => DriverRequestDetailScreen(
        offerId: _id,
        controller: controller,
        onBack: () => backs++,
        onCall: (p) async => phones.add(p),
        onOpenBookings: () => bookings++,
      );
}

Future<_Rig> _open(WidgetTester tester, Map<String, dynamic> json, {Size size = phoneSize}) async {
  final rig = _Rig(json);
  await pumpAtSize(tester, rig.screen(), size);
  await tester.pump();
  await tester.pump();
  return rig;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  expect(f, findsOneWidget, reason: key);
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump();
}

Finder _t(String text) => find.text(text);

Map<String, dynamic> _selected({bool conflict = false}) => {
      ..._sample('driver_offer_detail_selected.json'),
      if (!conflict) 'datesConflict': null,
    };

void main() {
  tearDown(Get.reset);

  testWidgets('frame_44_request_details', (tester) async {
    await _open(tester, _sample('driver_offer_detail_ringing.json'));
    expect(_t('Request details'), findsOneWidget);
    expect(_t('Kathgodam pickup'), findsOneWidget);
    expect(_t('Traveller'), findsOneWidget);
    expect(_t('Uttarakhand Hills Trip'), findsOneWidget);
    expect(_t('18 Dec to 21 Dec'), findsOneWidget);
    expect(_t('4 days · 3 nights'), findsOneWidget);
    expect(_t('2 travellers'), findsOneWidget);
    expect(_t('4 seater'), findsOneWidget);
    expect(_t('Pickup, 3 sightseeing days, Drop'), findsOneWidget);
    expect(_t('Kathgodam hub · 18 Dec'), findsOneWidget);
    expect(_t('3 nights · 18 to 21 Dec'), findsOneWidget);
    expect(_t('Same as pickup · Kathgodam hub · 21 Dec'), findsOneWidget);
    expect(_t('Day 1 · Fri 18 Dec'), findsOneWidget);
    expect(_t('25 km · 6 h 10 m'), findsOneWidget);
    expect(_t('Taxi needed'), findsNWidgets(3));
    expect(_t('No taxi needed'), findsOneWidget);
    expect(_t('Own plan'), findsOneWidget);
    expect(_t('Decline'), findsOneWidget);
    expect(_t('Accept'), findsOneWidget);
  });

  testWidgets('frame_45_waiting_for_traveller', (tester) async {
    await _open(tester, {..._sample('driver_offer_detail_selected.json'), 'state': 'Accepted', 'confirmBy': null, 'datesConflict': null});
    expect(_t('Request accepted'), findsOneWidget);
    expect(_t('Aarav Sharma'), findsOneWidget);
    expect(_t('+919876543210'), findsOneWidget);
    expect(_t('Waiting for traveller to choose'), findsOneWidget);
    expect(_t('Call traveller'), findsOneWidget);
    expect(_t('Accept'), findsNothing);
    expect(_t('Decline'), findsNothing);
  });

  testWidgets('frame_46_booking_request_countdown', (tester) async {
    await _open(tester, _selected());
    expect(_t('Booking request'), findsOneWidget);
    expect(_t('Aarav Sharma'), findsOneWidget);
    expect(_t('Selected you · confirm in 15:00'), findsOneWidget);
    expect(_t('Decline'), findsOneWidget);
    expect(_t('Confirm booking'), findsOneWidget);
    expect(find.byKey(const ValueKey('request_conflict_banner')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(_t('Selected you · confirm in 15:00'), findsOneWidget);
  });

  testWidgets('frame_47_dates_already_booked_disables_confirm', (tester) async {
    final rig = await _open(tester, _selected(conflict: true));
    expect(_t('Dates already booked. You have another booking from 20 Dec to 24 Dec.'), findsOneWidget);
    expect(_t('Confirm booking'), findsOneWidget);
    await _tap(tester, 'request_confirm');
    expect(rig.repo.calls, isEmpty);
  });

  testWidgets('number hidden before accept', (tester) async {
    await _open(tester, {..._sample('driver_offer_detail_ringing.json'), 'traveller': {'name': 'Aarav Sharma', 'phone': '+919876543210'}});
    expect(_t('Traveller'), findsOneWidget);
    expect(_t('Aarav Sharma'), findsNothing);
    expect(_t('+919876543210'), findsNothing);
    expect(find.byKey(const ValueKey('request_traveller_phone')), findsNothing);
  });

  testWidgets('end states show their chip only', (tester) async {
    await _open(tester, {..._sample('driver_offer_detail_ringing.json'), 'state': 'Missed', 'expiresAt': null});
    expect(_t('Missed'), findsOneWidget);
    expect(_t('Went to the next drivers'), findsOneWidget);
    expect(_t('Accept'), findsNothing);
    expect(_t('Decline'), findsNothing);
    expect(_t('Call traveller'), findsNothing);
  });

  testWidgets('confirmed shows Booked and opens My bookings', (tester) async {
    final rig = await _open(tester, {..._selected(), 'state': 'Confirmed', 'confirmBy': null});
    expect(_t('Booked'), findsOneWidget);
    expect(_t('Confirm booking'), findsNothing);
    await _tap(tester, 'request_open_bookings');
    expect(rig.bookings, 1);
  });

  testWidgets('actions call controller', (tester) async {
    final rig = await _open(tester, _sample('driver_offer_detail_ringing.json'));
    await _tap(tester, 'request_accept');
    expect(rig.repo.calls, ['accept']);
    expect(_t('Request accepted'), findsOneWidget);
  });

  testWidgets('decline calls controller and goes back', (tester) async {
    final rig = await _open(tester, _sample('driver_offer_detail_ringing.json'));
    await _tap(tester, 'request_decline');
    expect(rig.repo.calls, ['decline']);
    expect(rig.backs, 1);
  });

  testWidgets('confirm calls controller and call opens phone', (tester) async {
    final rig = await _open(tester, _selected());
    await _tap(tester, 'request_confirm');
    expect(rig.repo.calls, ['confirm']);
    expect(_t('Booked'), findsOneWidget);
  });

  testWidgets('call traveller passes the number', (tester) async {
    final rig = await _open(tester, {..._selected(), 'state': 'Accepted', 'confirmBy': null});
    await _tap(tester, 'request_call');
    expect(rig.phones, ['+919876543210']);
  });

  testWidgets('failed action shows the server message', (tester) async {
    final rig = _Rig(_sample('driver_offer_detail_ringing.json'));
    rig.repo.result = const TaxiRefused(type: 'X', statusCode: 400, message: 'Not possible now.');
    await pumpAtSize(tester, rig.screen(), phoneSize);
    await tester.pump();
    await tester.pump();
    await _tap(tester, 'request_accept');
    expect(_t('Not possible now.'), findsOneWidget);
  });

  group('five sizes with a 9 day body', () {
    final variants = <String, Map<String, dynamic>>{
      'ringing': _nineDays(_sample('driver_offer_detail_ringing.json')),
      'accepted': {..._nineDays(_sample('driver_offer_detail_selected.json')), 'state': 'Accepted', 'datesConflict': null},
      'selected': {..._nineDays(_sample('driver_offer_detail_selected.json')), 'datesConflict': null},
      'conflict': _nineDays(_sample('driver_offer_detail_selected.json')),
    };
    variants.forEach((name, json) {
      for (final size in fiveSizes) {
        testWidgets('$name at ${sizeLabel(size)}', (tester) async {
          await _open(tester, json, size: size);
          expect(tester.takeException(), isNull);
          expect(_t('Day by day'), findsOneWidget);
          await tester.dragUntilVisible(find.byKey(const ValueKey('request_day_9')), find.byType(SingleChildScrollView), const Offset(0, -300));
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    });
  });
}
