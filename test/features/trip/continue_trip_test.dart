import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/screens/trips_discovery_screen.dart';
import 'package:bakhli/features/trip/trip_navigation.dart';
import 'package:bakhli/features/trip/widgets/hub/hub_continue_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../e2e_journeys/nearby/nearby_support.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Trips extends MyTripsController {
  int loads = 0;
  final List<TripSummaryModel> rows;
  _Trips([this.rows = const []]);
  @override
  Future<void> ensureLoaded() async {}
  @override
  Future<void> load({bool refresh = false}) async => loads++;
  @override
  List<TripSummaryModel> get continueTrips {
    isLoading.value;
    return rows;
  }
}

class _Catalog extends TripCityCatalog {
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => true;
  @override
  Future<List<TripCityModel>> load({bool force = false}) async => const [];
}

TripSummaryModel _summary(String id) => TripSummaryModel.fromJson({
      'id': id,
      'title': 'Hills',
      'status': 'Planned',
      'cityName': 'Nainital',
      'dayCount': 2,
      'spotCount': 4,
      'category': 'attraction',
      'updatedAt': '2026-11-01T10:00:00Z',
      'progress': {'total': 4, 'done': 0, 'percent': 0},
    });

Widget _app(Widget home) => GetMaterialApp(
      getPages: [
        GetPage(name: AppRoutes.tripOverview, page: () => const Scaffold(body: Text('overview'))),
        GetPage(name: AppRoutes.tripPlan, page: () => const Scaffold(body: Text('plan'))),
      ],
      home: home,
    );

String _src(String path) => File(path).readAsStringSync();

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('continue_gs').path);
    await GetStorage.init();
  });
  tearDown(Get.reset);

  testWidgets('continueTrip opens the Trip overview with the trip id, never the plan', (t) async {
    await t.pumpWidget(_app(const Scaffold()));
    TripNavigation.continueTrip('trip-1');
    await t.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.tripOverview);
    expect(Get.arguments, {'tripId': 'trip-1'});
    expect(find.text('plan'), findsNothing);
  });

  testWidgets('empty id does nothing', (t) async {
    await t.pumpWidget(_app(const Scaffold()));
    final before = Get.currentRoute;
    await TripNavigation.continueTrip('');
    await t.pumpAndSettle();
    expect(Get.currentRoute, before);
  });

  testWidgets('the trip list reloads after the overview closes', (t) async {
    final trips = _Trips();
    Get.put<MyTripsController>(trips);
    await t.pumpWidget(_app(const Scaffold()));
    var done = false;
    TripNavigation.continueTrip('trip-1').then((_) => done = true);
    await t.pumpAndSettle();
    expect(trips.loads, 0);
    Get.back();
    await t.pumpAndSettle();
    expect(done, isTrue);
    expect(trips.loads, 1);
  });

  testWidgets('Trips tab Continue card opens the Trip overview', (t) async {
    Get.put<TabConfigController>(_Tabs());
    Get.put<AuthController>(JAuth());
    Get.put<LocationController>(JLoc());
    Get.put<TripCityCatalog>(_Catalog(), permanent: true);
    Get.put<MyTripsController>(_Trips([_summary('trip-7')]), permanent: true);
    await t.pumpWidget(_app(const TripsDiscoveryScreen()));
    await t.pump(const Duration(milliseconds: 300));
    final bar = t.widget<HubContinueBar>(find.byType(HubContinueBar));
    bar.onContinue(bar.trips.first);
    await t.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.tripOverview);
    expect(Get.arguments, {'tripId': 'trip-7'});
  });

  group('every Continue entry goes through TripNavigation.continueTrip', () {
    const entries = {
      'bottom bar': 'lib/features/trip/widgets/trip_bar.dart',
      'Trips tab card': 'lib/features/trip/screens/trips_discovery_screen.dart',
      'My trips': 'lib/features/trip/screens/my_trips_screen.dart',
      'saved journey strip': 'lib/features/taxi/journeys/widgets/journey_trip_strip.dart',
    };
    for (final e in entries.entries) {
      test(e.key, () {
        final s = _src(e.value);
        expect(s, contains('TripNavigation.continueTrip('));
        expect(s, isNot(contains('AppRoutes.tripPlan')));
        expect(s, isNot(contains('continueArgs')));
      });
    }

    test('My trips: card tap of an active trip continues, past trip keeps the plan, button opens the overview for ready/past', () {
      final s = _src('lib/features/trip/screens/my_trips_screen.dart');
      expect(s, contains('onOpen: () => _open(t, past: past)'));
      expect(RegExp(r'void _open\(TripSummaryModel t, \{bool past = false\}\) \{\s+if \(!past\) \{\s+TripNavigation\.continueTrip\(t\.id\);').hasMatch(s), isTrue);
      expect(RegExp(r'if \(past \|\| TripBarRules\.isReady\(t\)\) \{\s+TripNavigation\.openOverview\(tripId: t\.id\)').hasMatch(s), isTrue);
    });

    test('no file under lib opens the plan with a bare trip id outside the allow list', () {
      const allowed = {
        'trip_navigation.dart',
        'trip_routes.dart',
        'trip_spots_screen.dart',
        'notification_service.dart',
        'my_trips_screen.dart',
      };
      final bad = <String>[];
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        final s = f.readAsStringSync();
        expect(s.contains('continueArgs'), isFalse, reason: f.path);
        final name = f.uri.pathSegments.last;
        if (allowed.contains(name)) continue;
        if (s.contains('toNamed(AppRoutes.tripPlan') || s.contains('TripNavigation.openPlan(tripId:')) bad.add(f.path);
      }
      expect(bad, isEmpty);
    });
  });
}
