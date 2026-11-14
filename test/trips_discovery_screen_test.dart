import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/screens/trips_discovery_screen.dart';
import 'package:bakhli/features/trip/widgets/hub/hub_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'ui_golden/golden_support.dart';

class _Catalog extends TripCityCatalog {
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => true;
  @override
  Future<List<TripCityModel>> load({bool force = false}) async => const [];
}

class _Trips extends MyTripsController {
  _Trips([List<TripSummaryModel> trips = const []]) {
    active.assignAll(trips);
  }
  @override
  Future<void> ensureLoaded() async {}
  @override
  Future<void> load({bool refresh = false}) async {}
  @override
  List<TripSummaryModel> get continueTrips => active.isEmpty ? const [] : super.continueTrips;
}

TripSummaryModel _trip(int n, {bool done = false, int day = 0}) {
  final d = day == 0 ? n : day;
  return TripSummaryModel.fromJson({
    'id': 'trip-$n',
    'title': 'Trip number $n',
    'status': done ? 'Completed' : 'Planned',
    'cityName': 'Nainital',
    'dayCount': 2,
    'spotCount': 4,
    'category': 'attraction',
    'startDate': '2030-01-${(10 + d).toString().padLeft(2, '0')}',
    'endDate': '2030-01-${(12 + d).toString().padLeft(2, '0')}',
    'updatedAt': '2026-11-01T10:00:00Z',
    'progress': {'total': 4, 'done': 1, 'percent': 25},
  });
}

Future<void> _pump(WidgetTester t, double w, double scale, {MyTripsController? trips}) async {
  Get.put<TripCityCatalog>(_Catalog(), permanent: true);
  Get.put<MyTripsController>(trips ?? _Trips(), permanent: true);
  setGoldenView(t, Size(w, 800));
  await t.pumpWidget(GetMaterialApp(
    theme: ThemeData(fontFamily: 'Poppins'),
    getPages: [
      GetPage(name: AppRoutes.myTrips, page: () => const Scaffold(body: Text('my trips page'))),
      GetPage(name: AppRoutes.tripWhere, page: () => const Scaffold(body: Text('where page'))),
    ],
    home: MediaQuery(
      data: MediaQueryData(size: Size(w, 800), textScaler: TextScaler.linear(scale)),
      child: const TripsDiscoveryScreen(),
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  for (final w in [300.0, 360.0, 412.0, 560.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('hub shows without overflow @${w.toInt()} x$scale', (t) async {
        await _pump(t, w, scale, trips: _Trips([_trip(1), _trip(2)]));
        expect(find.text('Trips'), findsOneWidget);
        expect(find.byType(HubTile, skipOffstage: false), findsNWidgets(5));
        expect(find.text('Continue your trip'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('hub has no city grid or search', (t) async {
    await _pump(t, 360, 1);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Where to next?'), findsNothing);
  });

  testWidgets('the live tile opens Where to next', (t) async {
    await _pump(t, 360, 1);
    await t.tap(find.byType(HubTile).first);
    await t.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.tripWhere);
  });

  testWidgets('a coming soon tile does not navigate', (t) async {
    await _pump(t, 360, 1);
    final tile = find.byType(HubTile).at(1);
    await t.ensureVisible(tile);
    await t.pump();
    await t.tap(tile, warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 400));
    expect(Get.currentRoute, isNot(AppRoutes.tripWhere));
    await t.pumpAndSettle(const Duration(seconds: 6));
  });

  Finder dots() => find.byKey(const ValueKey('hub-dots'));
  Finder dotBoxes() => find.descendant(of: dots(), matching: find.byType(AnimatedContainer));

  for (final n in [1, 2, 3, 5]) {
    testWidgets('continue shows $n incomplete trips as one bar${n == 1 ? '' : ' with dots'}', (t) async {
      await _pump(t, 360, 1, trips: _Trips([for (var i = 1; i <= n; i++) _trip(i)]));
      final shown = n > 3 ? 3 : n;
      expect(find.text('Continue your trip'), findsOneWidget);
      expect(find.textContaining('Trip number'), findsOneWidget);
      expect(dots(), n == 1 ? findsNothing : findsOneWidget);
      if (n > 1) expect(dotBoxes(), findsNWidgets(shown));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('continue takes the soonest three and never completed ones', (t) async {
    final trips = _Trips([
      _trip(1, done: true, day: 1),
      _trip(2, day: 20),
      _trip(3, day: 5),
      _trip(4, day: 25),
      _trip(5, day: 8),
    ]);
    await _pump(t, 360, 1, trips: trips);
    expect([for (final c in trips.continueTrips) c.id], ['trip-3', 'trip-5', 'trip-2']);
    expect(find.textContaining('Trip number 3'), findsOneWidget);
    expect(find.textContaining('Trip number 1'), findsNothing);
  });

  testWidgets('only completed trips show no continue bar', (t) async {
    await _pump(t, 360, 1, trips: _Trips([_trip(1, done: true)]));
    expect(find.text('Continue your trip'), findsNothing);
    expect(dots(), findsNothing);
  });

  testWidgets('View all shows only when the bar is open, has no count and opens My trips', (t) async {
    await _pump(t, 360, 1, trips: _Trips([for (var i = 1; i <= 5; i++) _trip(i)]));
    expect(find.text('View all'), findsNothing);
    await t.tap(find.text('Continue your trip'));
    await t.pumpAndSettle();
    expect(find.text('View all'), findsOneWidget);
    expect(find.textContaining('('), findsNothing);
    await t.tap(find.text('View all'));
    await t.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.myTrips);
  });

  testWidgets('swiping the bar moves the active dot', (t) async {
    await _pump(t, 360, 1, trips: _Trips([for (var i = 1; i <= 3; i++) _trip(i)]));
    double w(int i) => t.getSize(dotBoxes().at(i)).width;
    expect(w(0), greaterThan(w(1)));
    await t.fling(find.text('Continue your trip'), const Offset(-250, 0), 800);
    await t.pumpAndSettle();
    expect(w(1), greaterThan(w(0)));
    expect(w(1), greaterThan(w(2)));
    expect(find.textContaining('Trip number 2'), findsOneWidget);
  });
}
