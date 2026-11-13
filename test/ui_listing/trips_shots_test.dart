import 'dart:async';

import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/screens/my_trips_screen.dart';
import 'package:bakhli/features/trip/screens/trips_discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/real_phone.dart';

TripCityModel _city(int k, String name, String state, int spots, {bool ready = true, String? cover}) => TripCityModel(
      cityKey: k,
      name: name,
      districtName: 'District',
      stateName: state,
      latitude: 1,
      longitude: 1,
      spotCount: spots,
      coverUrl: cover,
      status: ready ? TripCityStatus.ready : TripCityStatus.notReady,
    );

class _Catalog extends TripCityCatalog {
  _Catalog(this.list, {this.fail = false});
  final List<TripCityModel> list;
  final bool fail;
  bool has = true;
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => has;
  @override
  Future<List<TripCityModel>> load({bool force = false}) async {
    if (fail) {
      has = false;
      throw Exception('x');
    }
    return list;
  }

  @override
  List<TripCityModel> ready(String q, {String? stateName}) => [
        for (final c in q.trim().isEmpty ? list : TripCitySearch.filter(list, q))
          if (c.isReady && (stateName == null || c.stateName == stateName)) c,
      ];
  @override
  List<String> liveStates() => ({for (final c in list.where((c) => c.isReady)) c.stateName}.toList())..sort();
}

TripSummaryModel _trip(String id, String title, {int pct = 60, int done = 3, int total = 5, int wait = 1, String? state, List<String>? legs}) =>
    TripSummaryModel.fromJson({
      'id': id,
      'title': title,
      'status': 'draft',
      'cityName': legs?.first ?? 'Nainital',
      'dayCount': 3,
      'spotCount': 8,
      'startDate': '2026-11-20',
      'updatedAt': '2026-11-10T00:00:00Z',
      'bookingState': state ?? 'confirming',
      'legCount': legs?.length ?? 1,
      'legCities': legs,
      'progress': {
        'total': total,
        'done': done,
        'inProgress': wait,
        'percent': pct,
        'next': {'kind': 'taxi', 'key': 'taxi'},
      },
    });

class _Trips extends MyTripsController {
  _Trips(this.trip, {this.list = const []});
  final TripSummaryModel? trip;
  final List<TripSummaryModel> list;
  @override
  Future<void> ensureLoaded() async {}
  @override
  Future<void> load({bool refresh = false}) async {
    active.assignAll(list);
    isLoading.value = false;
  }

  @override
  Future<void> refreshIfStale() async {}
  @override
  TripSummaryModel? get continueTrip {
    active.length;
    return trip;
  }

  @override
  int get openTripCount {
    active.length;
    return 2;
  }
}

final _cities = [
  _city(1, 'Nainital', 'Uttarakhand', 24),
  _city(2, 'Mussoorie', 'Uttarakhand', 18),
  _city(3, 'Manali', 'Himachal Pradesh', 20),
  _city(4, 'Rishikesh', 'Uttarakhand', 16),
  _city(5, 'Kasol', 'Himachal Pradesh', 0, ready: false),
  _city(6, 'Auli', 'Uttarakhand', 0, ready: false),
];

final _long = [
  _city(11, 'Very long city name that keeps going on', 'A state with a really long name', 1),
  _city(12, 'Dharamshala McLeod Ganj', 'Himachal Pradesh', 0),
  _city(13, 'Kausani', 'Uttarakhand', 7),
];

Future<void> _discovery(WidgetTester t, String name, {double w = 360, double scale = 1, List<TripCityModel>? cities, TripSummaryModel? trip, bool fail = false, double h = 1500}) async {
  Get.reset();
  Get.put<TripCityCatalog>(_Catalog(cities ?? _cities, fail: fail), permanent: true);
  Get.put<MyTripsController>(_Trips(trip), permanent: true);
  debugDisableShadows = false;
  await pumpPhone(t, const TripsDiscoveryScreen(), size: Size(w, h), textScale: scale);
  await settlePhone(t);
  await t.pump(const Duration(seconds: 1));
  await shot(t, name);
  expect(t.takeException(), isNull);
  debugDisableShadows = true;
}

void main() {
  setUp(() => shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\trips');
  tearDown(Get.reset);

  final cont = _trip('a', 'Nainital to Almora');

  testWidgets('trips 360', (t) => _discovery(t, 'trips_1.0_360', trip: cont));
  testWidgets('trips 360 x1.3', (t) => _discovery(t, 'trips_1.3_360', trip: cont, scale: 1.3, h: 1900));
  testWidgets('trips 300', (t) => _discovery(t, 'trips_1.0_300', trip: cont, w: 300));
  testWidgets('trips long', (t) => _discovery(t, 'trips_long_1.3_300', w: 300, scale: 1.3, cities: _long, h: 1700,
      trip: _trip('b', 'A very long trip name from Dehradun all the way to Pithoragarh', pct: 100, done: 6, total: 6, wait: 0)));
  testWidgets('trips loading', (t) async {
    Get.reset();
    Get.put<TripCityCatalog>(_Pending(), permanent: true);
    Get.put<MyTripsController>(_Trips(null), permanent: true);
    debugDisableShadows = false;
    await pumpPhone(t, const TripsDiscoveryScreen(), size: const Size(360, 1000));
    await t.pump(const Duration(milliseconds: 300));
    await shot(t, 'trips_loading');
    debugDisableShadows = true;
  });
  testWidgets('trips error', (t) => _discovery(t, 'trips_error', cities: const [], fail: true, h: 900));
  testWidgets('trips search', (t) async {
    Get.reset();
    Get.put<TripCityCatalog>(_Catalog(_cities), permanent: true);
    Get.put<MyTripsController>(_Trips(cont), permanent: true);
    debugDisableShadows = false;
    await pumpPhone(t, const TripsDiscoveryScreen(), size: const Size(360, 1000));
    await settlePhone(t);
    await t.enterText(find.byType(TextField), 'zzz');
    await t.pump();
    await shot(t, 'trips_search_empty');
    await t.tap(find.byTooltip('Clear search'));
    await t.pump();
    expect(find.text('Where to next?'), findsOneWidget);
    debugDisableShadows = true;
  });

  for (final s in [1.0, 1.3]) {
    testWidgets('my trips $s', (t) async {
      Get.reset();
      Get.put<MyTripsController>(
          _Trips(null, list: [
            cont,
            _trip('c', '', legs: ['Rishikesh', 'Mussoorie', 'Dehradun'], pct: 20, done: 1, total: 5, wait: 0, state: 'draft'),
            _trip('d', 'Done and dusted', pct: 100, done: 4, total: 4, wait: 0, state: 'confirmed'),
          ]),
          permanent: true);
      debugDisableShadows = false;
      await pumpPhone(t, const MyTripsScreen(), size: const Size(360, 1400), textScale: s);
      await settlePhone(t);
      await t.pump(const Duration(seconds: 1));
      await shot(t, 'my_trips_$s');
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });
  }
}

class _Pending extends _Catalog {
  _Pending() : super(const []) {
    has = false;
  }
  @override
  Future<List<TripCityModel>> load({bool force = false}) => Completer<List<TripCityModel>>().future;
}
