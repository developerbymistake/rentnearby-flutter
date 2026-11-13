import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/report_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay/guest/stay_detail_screen.dart';
import 'package:bakhli/features/stay/guest/stay_guest_controller.dart';
import 'package:bakhli/features/stay/models/stay_detail_model.dart';
import 'package:bakhli/features/taxi/guest/taxi_detail_screen.dart';
import 'package:bakhli/features/taxi/taxi_option_sets.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:bakhli/widgets/detail_action_bar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../support/real_phone.dart';

typedef _Answer = FutureOr<Object?> Function(RequestOptions o);

class _Api implements HttpClientAdapter {
  _Api(this.answers);
  final Map<String, _Answer> answers;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final key = answers.keys.firstWhere((k) => o.path.startsWith(k), orElse: () => '');
    if (key.isEmpty) return _json(404, {'status': '404', 'code': 404, 'error': {'type': 'NoStub', 'message': 'No stub'}});
    final v = await answers[key]!(o);
    if (v is int) return _json(v, {'status': '$v', 'code': v, 'error': {'type': 'Fail', 'message': 'Fail'}});
    if (v is DioExceptionType) throw DioException(requestOptions: o, type: v);
    return _json(200, {'status': '200', 'code': 200, 'data': v});
  }

  ResponseBody _json(int code, Map<String, Object?> m) =>
      ResponseBody.fromString(jsonEncode(m), code, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _stayJson({bool min = false, bool reported = false, bool phone = true, List<String>? photos}) => {
      'id': 's1',
      'userId': 'o1',
      'slug': 'deodar',
      'name': min ? 'Pine Shade Rooms' : 'Deodar Cottage Homestay',
      'stayTypeName': 'Homestay',
      if (!min) 'vehicleAccess': 'CarToGate',
      'facilities': min ? <String>[] : ['HotWater', 'Heater', 'WiFi', 'Parking', 'HomeFood', 'MountainView'],
      if (!min) 'description': 'A quiet wooden cottage above the lake. Warm rooms, home food and a short walk to Mall Road.',
      'cityName': min ? 'Bhowali' : 'Nainital',
      'cityId': 'c-nainital',
      'cityLatitude': 29.39,
      'cityLongitude': 79.45,
      'latitude': 29.39,
      'longitude': 79.45,
      'photos': photos ?? <String>[],
      'rooms': min
          ? []
          : [
              {'id': 'r1', 'roomIndex': 1, 'pricePerNight': 1500, 'maxGuests': 2, 'roomName': 'Deluxe', 'meals': 'Breakfast'},
              {'id': 'r2', 'roomIndex': 2, 'pricePerNight': 2800, 'maxGuests': 4, 'roomName': 'Family Room', 'meals': 'AllMeals'},
            ],
      if (!min) 'rules': {'checkInTime': '12:00', 'checkOutTime': '11:00', 'petsAllowed': false, 'cancellationPolicy': 'Flexible'},
      if (!min) 'minPricePerNight': 1500,
      if (phone) 'ownerPhone': '9876543210',
      'hasReported': reported,
      'createdAt': DateTime.now().subtract(Duration(days: min ? 36 : 2)).toIso8601String(),
    };

Map<String, dynamic> _taxiJson({bool bus = false, bool contact = true, bool reported = false, bool available = true}) => bus
    ? {
        'id': 't2',
        'userId': 'd2',
        'slug': 'mohan',
        'driverName': 'Mohan Rawat',
        'vehicleTypeName': 'Bus',
        'vehicleCategory': 'Bus',
        'cityName': 'Haldwani',
        'routes': [],
        'isAvailable': true,
        'contactPhone': '9876500000',
        'createdAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      }
    : {
        'id': 't1',
        'userId': 'd1',
        'slug': 'rakesh',
        'driverName': 'Rakesh Singh',
        'vehicleTypeName': 'Innova',
        'vehicleCategory': 'SUV',
        'seats': 7,
        'plateDisplay': 'UK 04 TA 1234',
        'cityName': 'Haldwani',
        'routes': [
          {'id': 'r1', 'fromName': 'Haldwani', 'toName': 'Nainital', 'tripType': 'RoundTrip', 'fare': 2400},
          {'id': 'r2', 'fromName': 'Haldwani', 'toName': 'Kathgodam', 'tripType': 'OneWay', 'fare': 600},
          {'id': 'r3', 'fromName': 'Haldwani', 'toName': 'Almora', 'tripType': 'OneWay', 'fare': 3100},
        ],
        'minFare': 600,
        'isAvailable': available,
        if (contact) 'contactPhone': '9876500000',
        'hasReported': reported,
        'localDayRate': 2400,
        'localDayKm': 80,
        'createdAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      };

class _Guest extends StayGuestController {
  _Guest(this.answer);
  final Future<StayDetailModel?> Function() answer;
  @override
  Future<StayDetailModel?> getById(String id) => answer();
}

class _Reports extends ReportController {
  _Reports({this.submit});

  final Future<bool> Function()? submit;

  @override
  // ignore: must_call_super
  void onInit() {
    reportReasons.value = [
      for (final (i, n) in ['Wrong price', 'Fake listing', 'Wrong photos', 'Asked for advance', 'Rude behaviour', 'Other'].indexed) ReportReasonModel(id: 'r$i', name: n),
    ];
  }

  @override
  Future<void> loadReportReasons() async {}

  @override
  Future<bool> submitReport({required String listingId, required String listingType, required String reasonId, required String details, String? tripEnquiryId}) =>
      submit?.call() ?? Future.value(true);
}

const _reportText = 'The owner asked me to pay the full amount on UPI before the visit and would not show the room.';

Future<void> _openReport(WidgetTester t) async {
  await t.tap(find.text('Report this listing'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> _pickReason(WidgetTester t) async {
  await t.tap(find.byType(DropdownMenu<String>));
  await t.pump(const Duration(milliseconds: 400));
  await t.tap(find.text('Asked for advance').last);
  await t.pump(const Duration(milliseconds: 400));
  await t.enterText(find.byType(TextField).last, _reportText);
  await t.pump(const Duration(milliseconds: 200));
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump(const Duration(milliseconds: 200));
}

Future<void> _reportFlow(WidgetTester t, String p) async {
  await _openReport(t);
  expect(find.text('Report this listing?'), findsNothing);
  await shot(t, '${p}_rep_empty');
  if (p == 's') {
    await t.tap(find.byType(DropdownMenu<String>));
    await t.pump(const Duration(milliseconds: 600));
    await shot(t, 's_rep_menu');
    await t.tap(find.text('Asked for advance').last);
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    await t.enterText(find.byType(TextField).last, _reportText);
    await t.pump(const Duration(milliseconds: 200));
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump(const Duration(milliseconds: 300));
  } else {
    await _pickReason(t);
  }
  await shot(t, '${p}_rep_filled');
  await t.tap(find.text('Submit'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
  expect(find.text('Report this listing?'), findsOneWidget);
  await shot(t, '${p}_rep_confirm');
  if (p == 's') {
    await t.tap(find.text('Report'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    await shot(t, 's_rep_busy');
  }
}

class _Args extends StatelessWidget {
  const _Args(this.args, this.child);
  final Object args;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    Get.routing.args = args;
    return child;
  }
}

const _ways = {
  'version': '1',
  'allTheWay': [
    {'taxiId': 'a', 'driverName': 'A', 'listedFare': 2600},
  ],
  'plans': [
    {'planKey': 'p', 'cars': 2, 'total': 2300},
  ],
};

void _setup({Future<bool> Function()? reportSubmit, String? me, bool located = true, bool localCity = false, bool locating = false, Map<String, _Answer> api = const {}}) {
  Get.reset();
  final loc = Get.put<LocationController>(JLoc());
  if (located) {
    loc.userLocation.value = const LatLng(29.22, 79.51);
    loc.selectedDistrict.value = DistrictModel(id: 'd', name: 'Nainital');
    loc.autoCity.value = localCity
        ? CityModel(id: 'c-nainital', districtId: 'd', name: 'Nainital', latitude: 29.39, longitude: 79.45)
        : CityModel(id: 'c-hld', districtId: 'd', name: 'Haldwani', latitude: 29.22, longitude: 79.51);
  }
  loc.locationLoading.value = locating;
  final auth = Get.put<AuthController>(JAuth());
  if (me != null) auth.user.value = UserModel.fromJson({'id': me, 'createdAt': '2026-01-01T00:00:00Z'});
  Get.put<TabConfigController>(JTabs());
  Get.put<ReportController>(_Reports(submit: reportSubmit));
  ApiService.init();
  ApiService.dio.httpClientAdapter = _Api({'/taxis/ways': (_) => _ways, ...api});
}

Future<void> _stay(WidgetTester t, {Future<StayDetailModel?> Function()? answer, Size size = phoneSize, double scale = 1}) async {
  Get.put<StayGuestController>(_Guest(answer ?? () async => StayDetailModel.fromJson(_stayJson())));
  await pumpPhone(t, const _Args('s1', StayDetailScreen()), size: size, textScale: scale);
  await settlePhone(t);
  await settlePhone(t);
}

Future<void> _taxi(WidgetTester t, {Object args = 't1', Size size = phoneSize, double scale = 1}) async {
  await pumpPhone(t, _Args(args, const TaxiDetailScreen()), size: size, textScale: scale);
  await settlePhone(t);
  await settlePhone(t);
}

ScrollPosition _pos(WidgetTester t) => t.state<ScrollableState>(find.byType(Scrollable).first).position;

Future<void> _scrollTo(WidgetTester t, Finder f, {double gap = 100}) async {
  final pos = _pos(t);
  final dy = t.getTopLeft(f).dy;
  pos.jumpTo((pos.pixels + dy - gap).clamp(pos.minScrollExtent, pos.maxScrollExtent));
  await t.pump(const Duration(milliseconds: 300));
  await settlePhone(t);
}

Future<void> _gt(WidgetTester t, String name) async {
  await _stay(t);
  await _scrollTo(t, find.text('Getting there').first);
  expect(t.takeException(), isNull);
  await shot(t, name);
}

void _tw(String name, Future<void> Function(WidgetTester t) body) => testWidgets(name, (t) async {
      debugDisableShadows = false;
      try {
        await body(t);
      } finally {
        debugDisableShadows = true;
      }
    });

void main() {
  setUp(() {
    shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\details';
  });
  tearDown(() {
    Get.reset();
  });

  group('stay detail', () {
    _tw('s_main + full + scales', (t) async {
      _setup();
      await _stay(t);
      expect(t.takeException(), isNull);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Call Owner'), findsOneWidget);
      expect(find.text('WhatsApp'), findsNothing);
      await shot(t, 's_main');
      await scrollShots(t, find.byType(StayDetailScreen), 's_main_scroll', [700, 1400, 2200]);
    });

    _tw('s_main full page', (t) async {
      _setup();
      await _stay(t, size: const Size(360, 3000));
      await shot(t, 's_main_full');
    });

    for (final (name, size, scale) in [('s_main_1.3', phoneSize, 1.3), ('s_main_300', const Size(300, 800), 1.0), ('s_main_300_1.3', const Size(300, 800), 1.3)]) {
      _tw(name, (t) async {
        _setup();
        await _stay(t, size: Size(size.width, 3200), scale: scale);
        expect(t.takeException(), isNull);
        await shot(t, name);
      });
    }

    _tw('s_scroll', (t) async {
      _setup();
      await _stay(t);
      await _scrollTo(t, find.text('Facilities'));
      expect(t.takeException(), isNull);
      expect(find.text('Deodar Cottage Homestay'), findsNWidgets(2));
      await shot(t, 's_scroll');
    });

    _tw('s_owner', (t) async {
      _setup(me: 'o1');
      await _stay(t);
      expect(find.text('Share'), findsNothing);
      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('Chat'), findsNothing);
      expect(find.text('Report this listing'), findsNothing);
      await shot(t, 's_owner');
    });

    _tw('s_min', (t) async {
      _setup();
      await _stay(t, answer: () async => StayDetailModel.fromJson(_stayJson(min: true)));
      expect(find.text('On request'), findsOneWidget);
      expect(find.text('Rooms'), findsNothing);
      await shot(t, 's_min');
    });

    _tw('s_nophone', (t) async {
      _setup();
      await _stay(t, answer: () async => StayDetailModel.fromJson(_stayJson(phone: false)));
      expect(find.text('Call Owner'), findsNothing);
      await _scrollTo(t, find.text('Facilities'));
      await shot(t, 's_nophone');
    });

    _tw('s_reported + s_rep_done toast', (t) async {
      _setup();
      await _stay(t, answer: () async => StayDetailModel.fromJson(_stayJson(reported: true)));
      expect(find.text('Reported'), findsOneWidget);
      await _scrollTo(t, find.text('Facilities'));
      await shot(t, 's_reported');
      expect(ToastLane.showInHost(ToastKind.success, 'Report submitted. Thank you for letting us know.'), isTrue);
      await t.pump(const Duration(milliseconds: 400));
      await _scrollTo(t, find.text('Getting there').first, gap: 180);
      await shot(t, 's_rep_done');
      await t.pump(const Duration(seconds: 5));
    });

    _tw('s_rep flow', (t) async {
      _setup(reportSubmit: () => Completer<bool>().future);
      await _stay(t);
      await _reportFlow(t, 's');
      expect(t.takeException(), isNull);
    });

    _tw('s_share', (t) async {
      _setup();
      await _stay(t);
      final errorBuilder = ErrorWidget.builder;
      ErrorWidget.builder = (_) => const SizedBox.shrink();
      await t.tap(find.text('Share').first);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Sharing...'), findsOneWidget);
      await shot(t, 's_share');
      ErrorWidget.builder = errorBuilder;
      expect('${t.takeException()}', contains('margin.isNonNegative'));
    });

    _tw('s_load', (t) async {
      _setup();
      final c = Completer<StayDetailModel?>();
      await _stay(t, answer: () => c.future);
      await shot(t, 's_load');
    });

    _tw('s_err', (t) async {
      _setup();
      await _stay(t, answer: () async => null);
      expect(find.text('Stay not found'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await shot(t, 's_err');
    });
  });

  group('getting there', () {
    final cases = <String, ({Map<String, _Answer> api, bool located, bool local, bool locating})>{
      's_gt_ways': (api: const {}, located: true, local: false, locating: false),
      's_gt_direct': (
        api: {'/taxis/ways': (_) => {'allTheWay': [{'listedFare': 2400}, {'listedFare': 2600}], 'plans': []}},
        located: true, local: false, locating: false),
      's_gt_nodirect': (api: {'/taxis/ways': (_) => {'allTheWay': [], 'plans': [{'planKey': 'p', 'cars': 2, 'total': 2300}]}}, located: true, local: false, locating: false),
      's_gt_noways': (api: {'/taxis/ways': (_) => {'allTheWay': [], 'plans': []}}, located: true, local: false, locating: false),
      's_gt_error': (api: {'/taxis/ways': (_) => 500}, located: true, local: false, locating: false),
      's_gt_offline': (api: {'/taxis/ways': (_) => DioExceptionType.connectionError}, located: true, local: false, locating: false),
      's_gt_locating': (api: const {}, located: false, local: false, locating: true),
      's_gt_noloc': (api: const {}, located: false, local: false, locating: false),
      's_gt_local': (
        api: {
          '/trips/cities/nearest': (_) => {'cityKey': 7, 'available': true, 'name': 'Nainital'},
          '/taxis/browse': (_) => {
                'items': [
                  {'id': 'a', 'driverName': 'Rakesh Singh', 'vehicleTypeName': 'Innova', 'seats': 7, 'cityName': 'Nainital', 'localDayRate': 2400, 'localDayKm': 80, 'createdAt': '2026-11-01T00:00:00Z'},
                  {'id': 'b', 'driverName': 'Sunil Negi', 'vehicleTypeName': 'Dzire', 'seats': 4, 'cityName': 'Nainital', 'localDayRate': 1800, 'localDayKm': 60, 'createdAt': '2026-11-01T00:00:00Z'},
                ],
                'page': 1,
                'pageSize': 3,
                'totalCount': 2,
              },
        },
        located: true, local: true, locating: false),
      's_gt_empty': (
        api: {
          '/trips/cities/nearest': (_) => {'cityKey': 7, 'available': true},
          '/taxis/browse': (_) => {'items': [], 'page': 1, 'pageSize': 3, 'totalCount': 0},
        },
        located: true, local: true, locating: false),
      's_gt_lerror': (api: {'/trips/cities/nearest': (_) => {'cityKey': 7, 'available': true}, '/taxis/browse': (_) => 500}, located: true, local: true, locating: false),
      's_gt_cities': (api: {'/trips/cities/nearest': (_) => 500}, located: true, local: true, locating: false),
      's_gt_nocity': (api: {'/trips/cities/nearest': (_) => {'cityKey': 7, 'available': false}}, located: true, local: true, locating: false),
    };
    cases.forEach((name, c) {
      _tw(name, (t) async {
        _setup(api: c.api, located: c.located, localCity: c.local, locating: c.locating);
        await _gt(t, name);
      });
    });

    _tw('s_gt_load', (t) async {
      final never = Completer<Object?>();
      _setup(api: {'/taxis/ways': (_) => never.future});
      await _gt(t, 's_gt_load');
    });

    _tw('s_gt_ways at 1.3 and 300', (t) async {
      _setup();
      await _stay(t, scale: 1.3, size: const Size(300, 800));
      await _scrollTo(t, find.text('Getting there').first);
      expect(t.takeException(), isNull);
      await shot(t, 's_gt_ways_300_1.3');
    });
  });

  group('taxi detail', () {
    Map<String, _Answer> api(Map<String, dynamic> j) => {'/taxis/': (_) => j};

    _tw('t_main', (t) async {
      _setup(api: api(_taxiJson()));
      await _taxi(t);
      expect(t.takeException(), isNull);
      expect(find.text('Call Driver'), findsOneWidget);
      expect(find.text('WhatsApp'), findsNothing);
      expect(find.textContaining(TaxiOptionSets.safetyLine, findRichText: true), findsOneWidget);
      await shot(t, 't_main');
    });

    _tw('t_main full + scales', (t) async {
      _setup(api: api(_taxiJson()));
      await _taxi(t, size: const Size(360, 2200));
      await shot(t, 't_main_full');
    });

    for (final (name, w, scale) in [('t_main_1.3', 360.0, 1.3), ('t_main_300', 300.0, 1.0), ('t_main_300_1.3', 300.0, 1.3)]) {
      _tw(name, (t) async {
        _setup(api: api(_taxiJson()));
        await _taxi(t, size: Size(w, 2400), scale: scale);
        expect(t.takeException(), isNull);
        await shot(t, name);
      });
    }

    _tw('t_matched + t_scroll', (t) async {
      _setup(api: api(_taxiJson()));
      await _taxi(t, args: {'id': 't1', 'matchedFare': 2400, 'matchedToName': 'Nainital'});
      expect(find.text('TO NAINITAL'), findsOneWidget);
      await shot(t, 't_matched');
      await _scrollTo(t, find.text('Routes and fares'));
      await shot(t, 't_scroll');
    });

    _tw('t_nocontact', (t) async {
      _setup(api: api(_taxiJson(contact: false)));
      await _taxi(t);
      expect(find.text('Call Driver'), findsNothing);
      await shot(t, 't_nocontact');
    });

    _tw('t_reported + t_rep_done', (t) async {
      _setup(api: api(_taxiJson(reported: true)));
      await _taxi(t);
      expect(find.text('Reported'), findsOneWidget);
      await shot(t, 't_reported');
      ToastLane.showInHost(ToastKind.success, 'Report submitted. Thank you for letting us know.');
      await t.pump(const Duration(milliseconds: 400));
      await _scrollTo(t, find.text('Routes and fares'), gap: 190);
      await shot(t, 't_rep_done');
      await t.pump(const Duration(seconds: 5));
    });

    _tw('t_rep flow', (t) async {
      _setup(api: api(_taxiJson()));
      await _taxi(t);
      await _reportFlow(t, 't');
      expect(t.takeException(), isNull);
    });

    _tw('t_share', (t) async {
      _setup(api: api(_taxiJson()));
      await _taxi(t);
      final errorBuilder = ErrorWidget.builder;
      ErrorWidget.builder = (_) => const SizedBox.shrink();
      await t.tap(find.text('Share').first);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Sharing...'), findsOneWidget);
      await shot(t, 't_share');
      ErrorWidget.builder = errorBuilder;
      expect('${t.takeException()}', contains('margin.isNonNegative'));
    });

    _tw('t_owner', (t) async {
      _setup(me: 'd1', api: api(_taxiJson(available: false)));
      await _taxi(t);
      expect(find.text('Hidden from search'), findsOneWidget);
      expect(find.text('Share'), findsNothing);
      expect(find.byType(DetailActionBar), findsNothing);
      await shot(t, 't_owner');
    });

    _tw('t_bus', (t) async {
      _setup(api: api(_taxiJson(bus: true)));
      await _taxi(t, args: 't2');
      expect(find.text('On request'), findsOneWidget);
      expect(find.text('Routes and fares'), findsNothing);
      await shot(t, 't_bus');
    });

    _tw('t_load', (t) async {
      final never = Completer<Object?>();
      _setup(api: {'/taxis/': (_) => never.future});
      await _taxi(t);
      await shot(t, 't_load');
    });

    _tw('t_notfound', (t) async {
      _setup(api: {'/taxis/': (_) => 404});
      await _taxi(t);
      expect(find.text('Taxi not found'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      await shot(t, 't_notfound');
    });

    _tw('t_err', (t) async {
      _setup(api: {'/taxis/': (_) => 500});
      await _taxi(t);
      expect(find.text("Couldn't load the taxi"), findsOneWidget);
      await t.pump(const Duration(milliseconds: 300));
      await shot(t, 't_err');
      await t.pump(const Duration(seconds: 5));
    });
  });

  _tw('bar taps reach callbacks', (t) async {
    var chat = 0, report = 0;
    await pumpPhone(
      t,
      Scaffold(
        bottomNavigationBar: DetailActionBar(ownerPhone: '1', onChat: () => chat++, onReport: () => report++, palette: templateModulePalette),
      ),
    );
    await t.tap(find.text('Chat'));
    await t.tap(find.text('Report this listing'));
    expect((chat, report), (1, 1));
    expect(find.text('Directions'), findsOneWidget);
    expect(find.text('Call Owner'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);
  });
}
