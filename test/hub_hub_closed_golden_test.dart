import 'dart:io';
import 'dart:ui' as ui;
import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/screens/trips_discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'ui_golden/golden_support.dart';

const _out = String.fromEnvironment('HUB_OUT', defaultValue: 'build/hub_closed.png');

TripCityModel _city(int k, String name, int spots) => TripCityModel(
      cityKey: k,
      name: name,
      districtName: name,
      stateName: 'Uttarakhand',
      latitude: 1,
      longitude: 1,
      spotCount: spots,
      status: TripCityStatus.ready,
    );

class _Catalog extends TripCityCatalog {
  final list = [_city(1, 'Nainital', 24), _city(2, 'Mussoorie', 18), _city(3, 'Rishikesh', 21), _city(4, 'Jim Corbett', 12)];
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => true;
  @override
  Future<List<TripCityModel>> load({bool force = false}) async => list;
}

TripSummaryModel _trip(String id, String title, List<String> cities, int percent, {String? guide, bool past = false}) =>
    TripSummaryModel.fromJson({
      'id': id,
      'title': title,
      'status': past ? 'Completed' : 'Planned',
      'cityName': cities.first,
      'legCount': cities.length,
      'legCities': cities,
      'dayCount': 2,
      'spotCount': 4,
      'category': 'attraction',
      'startDate': past ? '2020-01-10' : '2030-01-10',
      'endDate': past ? '2020-01-12' : '2030-01-12',
      'updatedAt': '2026-11-01T10:00:00Z',
      'progress': {'total': 4, 'done': percent ~/ 25, 'percent': percent, 'guideStep': ?guide},
    });

class _Trips extends MyTripsController {
  _Trips() {
    active.assignAll([
      _trip('a', 'Nainital & Mukteshwar', ['Nainital', 'Mukteshwar'], 50, guide: 'stay:1'),
      _trip('b', 'Jim Corbett', ['Jim Corbett'], 0),
      _trip('c', 'Mussoorie', ['Mussoorie'], 100, past: true),
    ]);
  }
  @override
  Future<void> ensureLoaded() async {}
  @override
  Future<void> load({bool refresh = false}) async {}
  @override
  List<TripSummaryModel> get continueTrips => active.toList();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  testWidgets('hub with the Continue bar closed renders', (t) async {
    Get.put<TripCityCatalog>(_Catalog(), permanent: true);
    Get.put<MyTripsController>(_Trips(), permanent: true);
    setGoldenView(t, const Size(400, 1500));
    final key = GlobalKey();
    await t.pumpWidget(GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Poppins'),
      getPages: [GetPage(name: AppRoutes.myTrips, page: () => const Scaffold())],
      home: RepaintBoundary(
        key: key,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(392, 1500), padding: EdgeInsets.only(top: 44)),
          child: const Align(alignment: Alignment.topCenter, child: SizedBox(width: 392, child: TripsDiscoveryScreen())),
        ),
      ),
    ));
    await settleGolden(t);
    expect(t.takeException(), isNull);
    await t.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      File(_out).writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
