import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/screens/trips_discovery_screen.dart';
import 'package:bakhli/features/trip/widgets/trip_city_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'ui_golden/golden_support.dart';

TripCityModel _city(int k, {String? state, bool ready = true, int spots = 5}) => TripCityModel(
      cityKey: k,
      name: 'City number $k with a long name',
      districtName: 'District $k',
      stateName: state ?? 'Uttarakhand',
      latitude: 1,
      longitude: 1,
      spotCount: spots,
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
    has = true;
    return list;
  }

  @override
  List<TripCityModel> search(String q) => TripCitySearch.filter(list, q);
  @override
  List<TripCityModel> ready(String q, {String? stateName}) => [
        for (final c in q.trim().isEmpty ? list : search(q))
          if (c.isReady && (stateName == null || c.stateName == stateName)) c,
      ];
  @override
  List<String> liveStates() => ({for (final c in list.where((c) => c.isReady)) c.stateName}.toList())..sort();
}

class _Trips extends MyTripsController {
  _Trips({this.openCount = 0});
  final int openCount;
  @override
  Future<void> ensureLoaded() async {}
  @override
  Future<void> load({bool refresh = false}) async {}
  @override
  TripSummaryModel? get continueTrip {
    active.length;
    return null;
  }

  @override
  int get openTripCount {
    active.length;
    return openCount;
  }

}

Future<void> _pump(WidgetTester t, TripCityCatalog catalog, double w, double scale, {MyTripsController? trips}) async {
  Get.put<TripCityCatalog>(catalog, permanent: true);
  Get.put<MyTripsController>(trips ?? _Trips(), permanent: true);
  setGoldenView(t, Size(w, 800));
  await t.pumpWidget(GetMaterialApp(
    theme: ThemeData(fontFamily: 'WorkSans'),
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
      testWidgets('grid shows without overflow @${w.toInt()} x$scale', (t) async {
        final cities = [for (var i = 0; i < 60; i++) _city(i)];
        await _pump(t, _Catalog(cities), w, scale);
        expect(find.text('Where to next?'), findsOneWidget);
        expect(find.byType(TripCityTile), findsWidgets);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('grid is lazy: built tiles are fewer than the list', (t) async {
    final cities = [for (var i = 0; i < 120; i++) _city(i)];
    await _pump(t, _Catalog(cities), 360, 1);
    final built = find.byType(TripCityTile).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(cities.length ~/ 2));
  });

  testWidgets('every tile is repaint isolated and decode cap is small', (t) async {
    await _pump(t, _Catalog([for (var i = 0; i < 6; i++) _city(i)]), 360, 1);
    for (final e in find.byType(TripCityTile).evaluate()) {
      expect(find.descendant(of: find.byWidget(e.widget), matching: find.byType(RepaintBoundary)), findsWidgets);
    }
    expect(KitPhoto.maxDecodePx, lessThanOrEqualTo(480));
  });

  testWidgets('not ready cities are hidden', (t) async {
    await _pump(t, _Catalog([_city(1), _city(2, ready: false), _city(3)]), 360, 1);
    expect(find.byType(TripCityTile), findsNWidgets(2));
  });

  testWidgets('search is a plain match and shows the empty state', (t) async {
    await _pump(t, _Catalog([_city(1), _city(2)]), 360, 1);
    await t.enterText(find.byType(TextField), 'number 2');
    await t.pump();
    expect(find.byType(TripCityTile), findsOneWidget);
    await t.enterText(find.byType(TextField), 'zzzz');
    await t.pump();
    expect(find.text('No city found'), findsOneWidget);
    expect(find.text('Try another name'), findsOneWidget);
  });

  testWidgets('state chips only with two or more live states', (t) async {
    await _pump(t, _Catalog([_city(1), _city(2)]), 360, 1);
    expect(find.text('All'), findsNothing);
  });

  testWidgets('state chips filter the grid when two states are live', (t) async {
    await _pump(t, _Catalog([_city(1), _city(2, state: 'Himachal Pradesh')]), 360, 1);
    expect(find.text('All'), findsOneWidget);
    await t.tap(find.text('Himachal Pradesh'));
    await t.pump();
    expect(find.byType(TripCityTile), findsOneWidget);
  });

  testWidgets('My trips pill shows the count', (t) async {
    await _pump(t, _Catalog([_city(1)]), 360, 1, trips: _Trips(openCount: 3));
    expect(find.text('My trips · 3'), findsOneWidget);
  });

  testWidgets('error state offers Try again', (t) async {
    await _pump(t, _Catalog(const [], fail: true), 360, 1);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Could not load cities'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
