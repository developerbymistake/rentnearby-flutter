import 'dart:async';
import 'dart:io';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/extra/calm_card_kit.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/stay/guest/v2/stay_feed_item.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_controller_v2.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_screen_v2.dart';
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:bakhli/features/stay/models/stay_type_model.dart';
import 'package:bakhli/features/stay/stay_types_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_supply_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/screens/trip_replies_screen.dart';
import 'package:bakhli/features/trip/screens/trip_stay_screen.dart';
import 'package:bakhli/features/trip/widgets/trip_send_result_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_shortlist_bar.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../e2e_journeys/nearby/nearby_support.dart';
import '../../journeys/fake_api.dart';
import '../../support/owner_render.dart';
import '../../support/real_phone.dart';

final DateTime _start = DateTime(2026, 12, 18);

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Supply extends TripSupplyController {
  @override
  bool get staysOutOfDate => false;
  @override
  Future<void> ensureStays(int legIndex, {List<int>? onlyDays}) async => stayLeg.value = legIndex;
}

class _Repo extends TripShortlistRepository {
  _Repo(this.items);
  final List<ShortlistItem> items;
  @override
  Future<TripShortlist> list(String tripId) async => TripShortlist(items: items, max: 3);
}

Map<String, dynamic> _nearby(String id, String name, String type, String city, double km, int base,
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
      'ownerPhone': '9876543210',
      'datesPerNight': ?dated,
      if (dated != null) 'datesTotal': dated * 3,
      if (dated != null) 'basePerNight': base,
      'priceChip': ?chip,
      'fullOnDates': full,
    };

final List<StayNearbyModel> _three = [
  StayNearbyModel.fromJson(_nearby('s1', 'Lakeview Homestay', 'Homestay', 'Mallital', 0.4, 1800, dated: 1530, chip: {'kind': 'Off', 'text': '15% off'})),
  StayNearbyModel.fromJson(_nearby('s2', 'Hill Crest Resort', 'Hotel', 'Bhowali', 6.5, 3000, dated: 3600, room: 'Deluxe room')),
  StayNearbyModel.fromJson(_nearby('s3', 'Pine Nest Hostel', 'Hostel', 'Tallital', 1.2, 650, full: true, room: 'Dorm bed')),
];

List<ShortlistItem> _picks(String step) => [
      ShortlistItem(stepKey: step, kind: ShortlistKinds.stay, listingId: 's1', name: 'Lakeview Homestay'),
      ShortlistItem(stepKey: step, kind: ShortlistKinds.stay, listingId: 's2', name: 'Hill Crest Resort'),
    ];

TripPlan _nainitalPlan() {
  final p = journeyPlan([3], start: _start);
  return p.copyWith(legs: [TripCityLeg.fromCity(1, TripCityModel(cityKey: 210000001, name: 'Nainital', latitude: 29.39, longitude: 79.45))]);
}

TripPlanController _bootTrip({List<StayNearbyModel>? stays, List<ShortlistItem> Function(String step)? picks}) {
  Get.put<TabConfigController>(_Tabs());
  final plan = Get.put(TripPlanController());
  plan.plan.value = _nainitalPlan();
  final supply = Get.put<TripSupplyController>(_Supply());
  supply.stays.assignAll(stays ?? _three);
  supply.hostelAvailable.value = (stays ?? _three).any((s) => s.stayTypeName == 'Hostel');
  Get.put(TripShortlistController(repo: _Repo((picks ?? _picks)('stay:1')), tripId: () async => 't1', offline: () => false, warn: (_) {}));
  return plan;
}

Widget _pushing(Widget screen, Map<String, Object?> args) => Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        settings: RouteSettings(arguments: args),
        builder: (_) {
          Get.routing.args = args;
          return screen;
        },
      ),
    );

Future<void> _go(WidgetTester t) async {
  await t.pump();
  await settlePhone(t);
}

Future<void> _leave(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 5));
}

TripEnquiryBatch _sentBatch(List<(String, String)> rows) => TripEnquiryBatch(
      items: const [],
      skipped: const [],
      veryShortNotice: false,
      results: [for (final (id, status) in rows) TripSendResult(listingId: id, status: status)],
    );

Widget _sheetHost(Future<void> Function(BuildContext c) open) => Builder(
      builder: (c) => Center(child: TextButton(onPressed: () => open(c), child: const Text('open'))),
    );

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, Object?> _reply(String id, String name, {required String status, required String display, int? listed, Map<String, Object?>? offer}) {
  final j = enquiryJson(id: id, kind: 'Stay', status: status, start: _start, day: 1, nights: 3, displayStatus: display);
  return {
    ...j,
    'listingId': id,
    'listingName': name,
    'conversationId': 'c$id',
    'createdAt': _iso(DateTime.now().subtract(const Duration(hours: 2))),
    if (offer == null) 'expiresAt': _iso(DateTime.now().add(const Duration(hours: 22, minutes: 30))),
    'owner': {'id': 'o$id', 'name': 'Host', 'phone': '9876543210'},
    'context': {...(j['context'] as Map<String, Object?>), 'adults': 2, 'rooms': 1},
    'listedPerNight': ?listed,
    'openOffer': ?offer,
  };
}

Map<String, Object?> _offer(int perNight, int nights) => {
      'id': 'of$perNight',
      'kind': 'Offer',
      'nights': nights,
      'lines': [
        {'roomName': 'Deluxe room', 'units': 1, 'guests': 2, 'pricePerNight': perNight},
      ],
      'total': perNight * nights,
      'validUntil': _iso(DateTime.now().add(const Duration(hours: 23, minutes: 30))),
      'status': 'Pending',
    };

List<Map<String, Object?>> _replies({bool listed = true}) => [
      _reply('s2', 'Hill Crest Resort', status: 'Offered', display: 'offered', listed: listed ? 3400 : null, offer: _offer(3400, 3)),
      _reply('s1', 'Lakeview Homestay', status: 'Asked', display: 'asked', listed: listed ? 1530 : null),
    ];

TripPlanController _bootReplies(List<Map<String, Object?>> rows) {
  final plan = _bootTrip(stays: [
    StayNearbyModel.fromJson(_nearby('s1', 'Lakeview Homestay', 'Homestay', 'Mallital', 0.4, 1800)),
    StayNearbyModel.fromJson(_nearby('s2', 'Hill Crest Resort', 'Hotel', 'Bhowali', 6.5, 3000)),
  ]);
  plan.enquiryList.assignAll([for (final j in rows) TripEnquiryModel.fromJson(j)]);
  return plan;
}

class _Types extends StayTypesController {
  @override
  void ensureLoaded() {}
}

class _Stays extends StayLandingControllerV2 {
  _Stays(this.rows);
  final List<Map<String, dynamic>> rows;
  @override
  int? get tabIndex => null;
  @override
  RxInt? get tabRx => null;
  @override
  Future<NearbyPage<StayFeedItem>> fetchPage(String? token) async => NearbyPage(items: [for (final r in rows) StayFeedItem.fromJson(r)]);
}

Map<String, dynamic> _feedRow(String id, String name, String city, double km, int price, {String type = 'Homestay', Map<String, dynamic>? chip}) => {
      'id': id,
      'userId': 'u',
      'name': name,
      'cityName': city,
      'districtName': 'Nainital',
      'stateName': 'Uttarakhand',
      'minPricePerNight': price,
      'distanceKm': km,
      'labelKey': 'inCity',
      'stayTypeName': type,
      'priceChip': ?chip,
    };

final List<Map<String, dynamic>> _feedRows = [
  _feedRow('a', 'Lakeview Homestay', 'Mallital', 0.4, 1800, chip: {'kind': 'Off', 'text': '15% off'}),
  _feedRow('b', 'Pine Nest Hostel', 'Tallital', 1.2, 650, type: 'Hostel'),
];

Future<void> _bootStaysTab(List<Map<String, dynamic>> rows) async {
  final loc = Get.put<LocationController>(JLoc()) as JLoc;
  loc.userLocation.value = const LatLng(29.39, 79.45);
  loc.selectedDistrict.value = DistrictModel(id: 'd', name: 'Nainital');
  loc.autoCity.value = CityModel(id: 'c', districtId: 'd', name: 'Nainital');
  Get.put<AuthController>(JAuth());
  Get.put<TabConfigController>(JTabs());
  Get.put(NearbyCentreController());
  final types = Get.put<StayTypesController>(_Types());
  types.types.value = const [
    StayTypeModel(id: '1', name: 'Homestay', sortOrder: 1),
    StayTypeModel(id: '2', name: 'Hostel', sortOrder: 2),
    StayTypeModel(id: '3', name: 'Hotel', sortOrder: 3),
  ];
  Get.put<StayLandingControllerV2>(_Stays(rows), tag: StayLandingControllerV2.tag).reload();
}

Future<void> _settleFeed(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await t.pump(const Duration(milliseconds: 400));
  }
  await settlePhone(t);
}

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
  });
  late FakeTripAdapter api;
  setUp(() {
    Get.testMode = true;
    api = installFakeApi([
      FakeRoute.value('GET', '/stays/nearby', {
        'items': [for (final s in _three) _nearby(s.id, s.name ?? '', s.stayTypeName ?? '', s.cityName ?? '', s.distanceKm, s.minPricePerNight ?? 0)],
      }),
    ]);
  });
  tearDown(Get.reset);

  group('o_tr_1 trip stay list', () {
    test('o_tr_1_supplyController_sendsCheckInBesideNights', () async {
      Get.put<TabConfigController>(_Tabs());
      final plan = Get.put(TripPlanController());
      plan.plan.value = journeyPlan([3], start: _start);
      final supply = Get.put(TripSupplyController());
      supply.stayLeg.value = 1;
      await supply.loadStays();
      final call = api.calls('GET', '/stays/nearby').last;
      expect(call.queryParameters['checkIn'], '2026-12-18');
      expect(call.queryParameters['nights'], 3);
      expect(call.queryParameters.keys.where((k) => k.toLowerCase().contains('price')), isEmpty);
    });

    test('o_tr_1_noDates_noCheckIn: a trip without a start date sends no checkIn', () async {
      Get.put<TabConfigController>(_Tabs());
      final plan = Get.put(TripPlanController());
      final p = journeyPlan([3], start: _start);
      plan.plan.value = p.copyWith(settings: p.settings.copyWith(clearStartDate: true));
      final supply = Get.put(TripSupplyController());
      supply.stayLeg.value = 1;
      await supply.loadStays();
      final calls = api.calls('GET', '/stays/nearby');
      if (calls.isNotEmpty) expect(calls.last.queryParameters.containsKey('checkIn'), isFalse);
    });

    testWidgets('o_tr_1 real screen: three price states, Full disabled, order kept, bar 2 of 3', (t) async {
      _bootTrip();
      await pumpPhone(t, _pushing(const TripStayScreen(), const {'legIndex': 1, 'shortlist': true}), size: const Size(392, 1400));
      await _go(t);
      expect(find.text('15% off'), findsOneWidget);
      expect(find.text('₹1,530'), findsOneWidget);
      expect(find.text('₹3,600'), findsOneWidget);
      expect(find.text('Full on your dates'), findsOneWidget);
      expect(find.text('Full'), findsOneWidget);
      expect(find.text('2 of 3 shortlisted'), findsOneWidget);
      expect(find.text('Tap Done to send your enquiry'), findsOneWidget);
      final y = [for (final n in ['Lakeview Homestay', 'Hill Crest Resort', 'Pine Nest Hostel']) t.getTopLeft(find.text(n)).dy];
      expect(y, orderedEquals([...y]..sort()));
      expect(t.takeException(), isNull);
      await _leave(t);
    });

    for (final (w, s) in [(320.0, 1.0), (320.0, 1.3), (360.0, 1.0), (360.0, 1.3), (411.0, 1.0), (411.0, 1.3)]) {
      testWidgets('o_tr_1 real screen sizes ${w.toInt()} @$s', (t) async {
        _bootTrip();
        await pumpPhone(t, _pushing(const TripStayScreen(), const {'legIndex': 1, 'shortlist': true}), size: Size(w, 800), textScale: s);
        await _go(t);
        expect(t.takeException(), isNull);
        await _leave(t);
      });
    }
  });

  group('o_tr_3 send the enquiry (unchanged flow)', () {
    testWidgets('o_tr_3_a_greatPicksListsOnlyShortlisted and o_tr_3_a_notNowClosesNothingSent', (t) async {
      bool? answer;
      await pumpPhone(t, _sheetHost((c) async => answer = await TripShortlistReview.show(c, taxi: false, count: 2, names: const ['Lakeview Homestay', 'Hill Crest Resort'])), size: const Size(392, 1000));
      await t.tap(find.text('open'));
      for (var i = 0; i < 15; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await settlePhone(t);
      expect(find.text('Great picks'), findsOneWidget);
      expect(find.text('Send an enquiry to all your shortlisted stays together?'), findsOneWidget);
      expect(find.text('Lakeview Homestay'), findsOneWidget);
      expect(find.text('Hill Crest Resort'), findsOneWidget);
      expect(find.text('Pine Nest Hostel'), findsNothing);
      expect(find.text('Send to all'), findsOneWidget);
      await t.tap(find.text('Not now'));
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await settlePhone(t);
      expect(find.text('Great picks'), findsNothing);
      expect(answer, isFalse);
    });

    testWidgets('o_tr_3_b_enquirySentRowPerStayWithSent', (t) async {
      await pumpPhone(t, _sheetHost((c) => TripSendResultSheet.show(c,
          batch: _sentBatch([('s1', 'Sent'), ('s2', 'Sent')]), names: const {'s1': 'Lakeview Homestay', 's2': 'Hill Crest Resort'}, shortlist: true)));
      await t.tap(find.text('open'));
      await settlePhone(t);
      expect(find.text('Enquiry sent'), findsOneWidget);
      expect(find.text('We told 2 hosts. You will see replies here.'), findsOneWidget);
      expect(find.text('Sent'), findsNWidgets(2));
      expect(find.text('Back to plan'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing);
    });

    testWidgets('o_tr_3_fullOnDatesRowShowsReason: a stay the server skipped shows its reason, not Sent', (t) async {
      await pumpPhone(t, _sheetHost((c) => TripSendResultSheet.show(c,
          batch: _sentBatch([('s1', 'Sent'), ('s3', 'NotAvailable')]), names: const {'s1': 'Lakeview Homestay', 's3': 'Pine Nest Hostel'}, shortlist: true)));
      await t.tap(find.text('open'));
      await settlePhone(t);
      expect(find.text('Not available'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('We told 1 host. You will see replies here.'), findsOneWidget);
    });

    test('o_tr_3_requestBodyHasNoPriceField (guard on the enquiry create body)', () {
      final src = File('lib/features/trip/data/trip_enquiry_repository.dart').readAsStringSync();
      final start = src.indexOf('Future<TripEnquiryBatch> create(');
      final body = src.substring(start, src.indexOf('});', start));
      expect(body.toLowerCase().contains('price'), isFalse);
      expect(body.toLowerCase().contains('total'), isFalse);
    });
  });

  group('o_tr_4 stay replies', () {
    testWidgets('o_tr_4_askedCard_listedSlotShowsListedPerNight, o_tr_4_offeredCard_neverShowsListedPrice, o_tr_4_sortOfferedFirst', (t) async {
      _bootReplies(_replies());
      await pumpPhone(t, _pushing(const TripRepliesScreen(), const {'day': 1}), size: const Size(392, 1400));
      await _go(t);
      expect(find.text('Hill Crest Resort'), findsOneWidget);
      expect(find.text('Lakeview Homestay'), findsOneWidget);
      expect(t.getTopLeft(find.text('Hill Crest Resort')).dy, lessThan(t.getTopLeft(find.text('Lakeview Homestay')).dy));
      expect(find.text('₹1,530'), findsOneWidget);
      expect(find.text('₹1,800'), findsNothing);
      expect(find.text('₹3,400'), findsNothing);
      expect(find.text('₹3,000'), findsNothing);
      expect(t.takeException(), isNull);
      await _leave(t);
    });

    testWidgets('o_tr_4_askedCard_fieldMissing_showsBasePrice', (t) async {
      _bootReplies(_replies(listed: false));
      await pumpPhone(t, _pushing(const TripRepliesScreen(), const {'day': 1}), size: const Size(392, 1400));
      await _go(t);
      expect(find.text('₹1,800'), findsOneWidget);
      expect(find.text('₹1,530'), findsNothing);
      await _leave(t);
    });

    for (final n in [1, 8]) {
      for (final (w, s) in [(320.0, 1.3), (411.0, 1.0)]) {
        testWidgets('o_tr_4 $n cards at ${w.toInt()} @$s', (t) async {
          final rows = [
            for (var i = 0; i < n; i++)
              i.isEven
                  ? _reply('s$i', 'Stay $i', status: 'Asked', display: 'asked', listed: 1530)
                  : _reply('s$i', 'Stay $i', status: 'Offered', display: 'offered', offer: _offer(3400, 3)),
          ];
          _bootReplies(rows);
          await pumpPhone(t, _pushing(const TripRepliesScreen(), const {'day': 1}), size: Size(w, 800), textScale: s);
          await _go(t);
          expect(t.takeException(), isNull);
          await _leave(t);
        });
      }
    }
  });

  group('o_tr_5 stays tab card', () {
    testWidgets('o_tr_5_lowerRuleWithin30Days_showsTagUnderPrice, o_tr_5_priceIsBaseFrom, o_tr_5_noChip_whenFieldMissing', (t) async {
      await _bootStaysTab(_feedRows);
      await pumpPhone(t, const StayLandingScreenV2(), size: const Size(392, 1200));
      await _settleFeed(t);
      expect(find.text('15% off'), findsOneWidget);
      expect(find.text('₹1,800'), findsOneWidget);
      expect(find.text('₹1,530'), findsNothing);
      expect(find.textContaining('% off'), findsOneWidget);
      expect(find.descendant(of: find.byType(CalmPriceBlock), matching: find.text('15% off')), findsOneWidget);
      expect(find.descendant(of: find.byType(Wrap), matching: find.text('15% off')), findsNothing);
      expect(t.widget<Text>(find.text('₹1,800')).style?.decoration, isNot(TextDecoration.lineThrough));
      await _leave(t);
    });

    testWidgets('o_tr_5_orderUnchanged: rows keep the server order', (t) async {
      await _bootStaysTab([_feedRows[1], _feedRows[0]]);
      await pumpPhone(t, const StayLandingScreenV2(), size: const Size(392, 1200));
      await _settleFeed(t);
      expect(t.getTopLeft(find.text('Pine Nest Hostel')).dy, lessThan(t.getTopLeft(find.text('Lakeview Homestay')).dy));
      await _leave(t);
    });

    for (final n in [0, 1, 30]) {
      for (final (w, s) in [(320.0, 1.3), (360.0, 1.0), (411.0, 1.3)]) {
        testWidgets('o_tr_5 $n cards at ${w.toInt()} @$s', (t) async {
          await _bootStaysTab([for (var i = 0; i < n; i++) _feedRow('x$i', 'Stay $i', 'Mallital', 0.4 + i, 1800, chip: i.isEven ? {'kind': 'Off', 'text': '15% off'} : null)]);
          await pumpPhone(t, const StayLandingScreenV2(), size: Size(w, 800), textScale: s);
          await _settleFeed(t);
          expect(t.takeException(), isNull);
          await _leave(t);
        });
      }
    }
  });

  group('render', () {
    useOwnerRenderScale();

    testWidgets('render o_tr_1', (t) async {
      _bootTrip();
      await renderOwnerFrame(t, 'o_tr_1', _pushing(const TripStayScreen(), const {'legIndex': 1, 'shortlist': true}), arrange: _go);
      expect(t.takeException(), isNull);
      await _leave(t);
    });

    testWidgets('render o_tr_3 A', (t) async {
      _bootTrip();
      await renderOwnerFrame(t, 'o_tr_3', _pushing(const TripStayScreen(), const {'legIndex': 1, 'shortlist': true}), part: 'A', arrange: (t) async {
        await _go(t);
        final ctx = t.element(find.byType(TripStayScreen));
        unawaited(TripShortlistReview.show(ctx, taxi: false, count: 2, names: const ['Lakeview Homestay', 'Hill Crest Resort']));
        await settlePhone(t);
      });
      expect(t.takeException(), isNull);
      await _leave(t);
    });

    testWidgets('render o_tr_3 B', (t) async {
      _bootTrip();
      await renderOwnerFrame(t, 'o_tr_3', _pushing(const TripStayScreen(), const {'legIndex': 1, 'shortlist': true}), part: 'B', arrange: (t) async {
        await _go(t);
        final ctx = t.element(find.byType(TripStayScreen));
        unawaited(TripSendResultSheet.show(ctx,
            batch: _sentBatch([('s1', 'Sent'), ('s2', 'Sent')]), names: const {'s1': 'Lakeview Homestay', 's2': 'Hill Crest Resort'}, shortlist: true));
        await settlePhone(t);
      });
      expect(t.takeException(), isNull);
      await _leave(t);
    });

    testWidgets('render o_tr_4', (t) async {
      _bootReplies(_replies());
      await renderOwnerFrame(t, 'o_tr_4', _pushing(const TripRepliesScreen(), const {'day': 1}), arrange: _go);
      expect(t.takeException(), isNull);
      await _leave(t);
    });

    testWidgets('render o_tr_5', (t) async {
      await _bootStaysTab(_feedRows);
      await renderOwnerFrame(t, 'o_tr_5', const StayLandingScreenV2(), arrange: _settleFeed);
      expect(t.takeException(), isNull);
      await _leave(t);
    });
  });
}
