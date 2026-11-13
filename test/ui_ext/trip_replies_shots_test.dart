import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_supply_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/screens/trip_replies_screen.dart';
import 'package:bakhli/features/trip/screens/trip_taxi_replies_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../journeys/fake_api.dart';
import '../support/real_phone.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Supply extends TripSupplyController {
  @override
  bool get staysOutOfDate => false;
  @override
  Future<void> ensureStays(int legIndex) async => stayLeg.value = legIndex;
  @override
  Future<void> ensureTaxis(int legIndex, {int? day}) async => taxiLeg.value = legIndex;
}

final _configs = <(String, double, double)>[('', 360, 1.0), ('_13', 360, 1.3), ('_300', 300, 1.0)];

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, Object?> _stayJson(
  String id,
  String name,
  String display, {
  String status = 'Asked',
  int day = 1,
  int nights = 2,
  DateTime? start,
  int? cityLeg,
  bool urgent = false,
  int? agreed,
  Map<String, Object?>? openOffer,
  Map<String, Object?>? advance,
  Map<String, Object?>? counter,
  Map<String, Object?>? revised,
  String? failReason,
  String? conversation = 'c1',
}) {
  final j = enquiryJson(id: id, kind: 'Stay', status: status, start: start ?? journeyStart(), day: day, nights: nights, displayStatus: display, agreedTotal: agreed, cityLeg: cityLeg);
  return {
    ...j,
    'listingId': 'stay-$id',
    'listingName': name,
    'isUrgent': urgent,
    'conversationId': conversation,
    'createdAt': _iso(DateTime.now().subtract(const Duration(hours: 2))),
    'expiresAt': _iso(DateTime.now().add(const Duration(hours: 22))),
    'owner': {'id': 'o$id', 'name': 'Host', 'phone': '9876543210'},
    'context': {
      ...(j['context'] as Map<String, Object?>),
      'adults': 2,
      'rooms': 1,
    },
    'openOffer': ?openOffer,
    'advance': ?advance,
    'pendingCounter': ?counter,
    'pendingRevised': ?revised,
    'failReason': ?failReason,
  };
}

Map<String, Object?> _offer(int perNight, int nights, {int? advance, String kind = 'Offer'}) => {
      'id': 'of$perNight',
      'kind': kind,
      'nights': nights,
      'lines': [
        {'roomName': 'Deluxe room', 'units': 1, 'guests': 2, 'pricePerNight': perNight},
      ],
      'total': perNight * nights,
      'advanceAmount': ?advance,
      'validUntil': _iso(DateTime.now().add(const Duration(hours: 23))),
      'status': 'Pending',
    };

StayNearbyModel _stay(String id, String name, int price) => StayNearbyModel(
      id: id,
      name: name,
      latitude: 29.3,
      longitude: 79.5,
      minPricePerNight: price,
      distanceKm: 1,
      isActive: true,
      ownerPhone: '9876543210',
    );

Future<void> _leave(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 5));
  debugDisableShadows = true;
}

Future<void> _open(WidgetTester t, Widget screen, {double w = 360, double s = 1.0, Map<String, Object?> args = const {'day': 1}}) async {
  await pumpPhone(
    t,
    Builder(
      builder: (c) => TextButton(
        onPressed: () => Navigator.of(c).push(MaterialPageRoute(settings: RouteSettings(arguments: args), builder: (_) => screen)),
        child: const Text('go'),
      ),
    ),
    size: Size(w, 800),
    devicePixelRatio: 1.5,
    textScale: s,
  );
  await t.tap(find.text('go'));
  await t.pump();
  await settlePhone(t);
}

Future<void> _snap(WidgetTester t, String name) async {
  await settlePhone(t);
  await shot(t, name);
  expect(t.takeException(), isNull);
}

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
  });
  setUp(() {
    shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\trip-replies';
    Get.testMode = true;
    debugDisableShadows = false;
    installFakeApi([]);
  });
  tearDown(Get.reset);

  TripPlanController boot(List<Map<String, Object?>> enquiries, {List<int> legs = const [3]}) {
    Get.put<TabConfigController>(_Tabs());
    final plan = Get.put(TripPlanController());
    plan.plan.value = journeyPlan(legs);
    final supply = Get.put<TripSupplyController>(_Supply());
    supply.stays.assignAll([_stay('stay-b', 'Lakeside Rooms', 3000), _stay('stay-c', 'Pine Ridge Stay', 2600)]);
    plan.enquiryList.assignAll([for (final j in enquiries) TripEnquiryModel.fromJson(j)]);
    return plan;
  }

  final listData = [
    _stayJson('a', 'Deodar Cottage', 'offered', status: 'Offered', openOffer: _offer(3600, 2, advance: 2000)),
    _stayJson('b', 'Lakeside Rooms', 'asked', urgent: true),
  ];

  for (final (tag, w, s) in _configs) {
    testWidgets('sr_list$tag', (t) async {
      boot(listData);
      await _open(t, const TripRepliesScreen(), w: w, s: s);
      await _snap(t, 'sr_list$tag');
      expect(find.text('Deodar Cottage'), findsOneWidget);
      await _leave(t);
    });
  }

  testWidgets('sr_list scrolled', (t) async {
    boot(listData);
    await _open(t, const TripRepliesScreen());
    await scrollShots(t, find.byType(TripRepliesScreen), 'sr_list_scroll', [600]);
    expect(find.text('Ask another stay'), findsOneWidget);
    await _leave(t);
  });

  testWidgets('sr_more', (t) async {
    boot([
      _stayJson('c', 'Pine Ridge Stay', 'asked', counter: {..._offer(2200, 2), 'kind': 'Counter', 'id': 'k1'}),
      _stayJson('d', 'Himalayan View Homestay', 'confirmedByYou', status: 'ConfirmedByTraveller', agreed: 5600),
    ]);
    await _open(t, const TripRepliesScreen());
    await _snap(t, 'sr_more');
    await _leave(t);
  });

  testWidgets('sr_conf', (t) async {
    boot([
      _stayJson('a', 'Deodar Cottage', 'confirmedByBoth', status: 'ConfirmedByBoth', agreed: 7200, advance: {
        'status': 'Pending',
        'amount': 2000,
        'holdUntil': _iso(DateTime.now().add(const Duration(hours: 4))),
      }),
      _stayJson('c', 'Pine Ridge Stay', 'confirmedByBoth', status: 'ConfirmedByBoth', agreed: 4800, advance: {'status': 'Received', 'amount': 1500}),
    ]);
    await _open(t, const TripRepliesScreen());
    await _snap(t, 'sr_conf');
    await _leave(t);
  });

  testWidgets('sr_ended', (t) async {
    boot([
      _stayJson('b', 'Lakeside Rooms', 'holdExpired', status: 'ConfirmedByBoth', agreed: 6400, advance: {
        'status': 'HoldExpired',
        'amount': 2000,
        'holdUntil': _iso(DateTime.now().subtract(const Duration(hours: 1))),
      }),
      _stayJson('d', 'Himalayan View Homestay', 'notMe', status: 'Failed'),
    ]);
    await _open(t, const TripRepliesScreen());
    await _snap(t, 'sr_ended');
    await _leave(t);
  });

  testWidgets('sr_multi', (t) async {
    boot([
      _stayJson('a', 'Deodar Cottage', 'confirmedByBoth', status: 'ConfirmedByBoth', agreed: 7200, cityLeg: 1, revised: {..._offer(3400, 2, kind: 'Revised'), 'id': 'rv1'}),
      _stayJson('b', 'Lakeside Rooms', 'asked', nights: 3, cityLeg: 1),
      _stayJson('c', 'Pine Ridge Stay', 'asked', start: journeyStart().add(const Duration(days: 20)), cityLeg: 1),
    ], legs: [2, 2]);
    await _open(t, const TripRepliesScreen());
    await _snap(t, 'sr_multi');
    await scrollShots(t, find.byType(TripRepliesScreen), 'sr_multi_scroll', [700]);
    await _leave(t);
  });

  testWidgets('sr_loading', (t) async {
    final plan = boot(const []);
    plan.enquiriesLoading.value = true;
    await _open(t, const TripRepliesScreen());
    await _snap(t, 'sr_loading');
    await _leave(t);
  });

  testWidgets('sr_empty', (t) async {
    boot(const []);
    await _open(t, const TripRepliesScreen());
    await _snap(t, 'sr_empty');
    await _leave(t);
  });

  testWidgets('sr_error', (t) async {
    final plan = boot(const []);
    plan.enquiriesFailed.value = true;
    await _open(t, const TripRepliesScreen());
    await _snap(t, 'sr_error');
    await _leave(t);
  });

  testWidgets('sr_off', (t) async {
    final plan = boot(const []);
    plan.plannerOff.value = true;
    await _open(t, const TripRepliesScreen());
    await _snap(t, 'sr_off');
    await _leave(t);
  });

  testWidgets('sr_menu and sr_decline', (t) async {
    boot(listData);
    await _open(t, const TripRepliesScreen());
    await t.tap(find.byTooltip('More').first);
    await t.pump(const Duration(milliseconds: 300));
    await _snap(t, 'sr_menu');
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('Withdraw'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    await t.tap(find.text('Decline'));
    await t.pump(const Duration(milliseconds: 400));
    await _snap(t, 'sr_decline');
    expect(find.text('Decline this offer?'), findsOneWidget);
    await _leave(t);
  });

  Map<String, Object?> taxiJson(String id, String name, String display, {String status = 'Asked', int? fare, int? agreed, bool urgent = false, String? note}) {
    final j = enquiryJson(id: id, kind: 'Taxi', status: status, start: journeyStart(), days: [1], displayStatus: display);
    return {
      ...j,
      'listingName': name,
      'isUrgent': urgent,
      'conversationId': 'c$id',
      'createdAt': _iso(DateTime.now().subtract(const Duration(hours: 1))),
      'expiresAt': _iso(DateTime.now().add(const Duration(hours: 20))),
      'owner': {'id': 'd$id', 'name': name, 'phone': '9876543210'},
      'taxi': {'listedRate': 3000, 'driverFare': ?fare, 'driverNote': ?note, 'agreedFare': ?agreed},
    };
  }

  final taxiScenes = <String, List<Map<String, Object?>>>{
    'tr_list': [
      taxiJson('t1', 'Ramesh Kumar', 'fareSent', status: 'FareSent', fare: 3200, note: 'AC car, toll included'),
      taxiJson('t2', 'Suresh Negi', 'asked', urgent: true),
    ],
    'tr_done': [
      taxiJson('t3', 'Ramesh Kumar', 'bookedByYou', status: 'BookedByTraveller', agreed: 3200),
      taxiJson('t4', 'Suresh Negi', 'confirmedByBoth', status: 'ConfirmedByBoth', agreed: 3000),
    ],
    'tr_red': [
      taxiJson('t5', 'Ramesh Kumar', 'notMe', status: 'Failed'),
      taxiJson('t6', 'Suresh Negi', 'asked'),
    ],
  };

  for (final e in taxiScenes.entries) {
    for (final (tag, w, s) in _configs) {
      testWidgets('${e.key}$tag', (t) async {
        boot(e.value);
        await _open(t, const TripTaxiRepliesScreen(), w: w, s: s);
        await _snap(t, '${e.key}$tag');
        await _leave(t);
      });
    }
  }

  testWidgets('tr_loading', (t) async {
    final plan = boot(const []);
    plan.enquiriesLoading.value = true;
    await _open(t, const TripTaxiRepliesScreen());
    await _snap(t, 'tr_loading');
    await _leave(t);
  });

  testWidgets('tr_empty', (t) async {
    boot(const []);
    await _open(t, const TripTaxiRepliesScreen());
    await _snap(t, 'tr_empty');
    await _leave(t);
  });

  testWidgets('tr_error', (t) async {
    final plan = boot(const []);
    plan.enquiriesFailed.value = true;
    await _open(t, const TripTaxiRepliesScreen());
    await _snap(t, 'tr_error');
    await _leave(t);
  });

  testWidgets('sr_gone', (t) async {
    final plan = boot(const []);
    plan.tripGone.value = true;
    await _open(t, const TripRepliesScreen());
    await _snap(t, 'sr_gone');
    await _leave(t);
  });
}
