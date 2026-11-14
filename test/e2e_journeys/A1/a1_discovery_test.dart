import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/screens/trip_where_screen.dart';
import 'package:bakhli/features/trip/screens/trips_discovery_screen.dart';
import 'package:bakhli/features/trip/trip_navigation.dart';
import 'package:bakhli/features/trip/widgets/trip_city_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_city_tile.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:bakhli/utils/network_retry.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../ui_golden/golden_support.dart';

TripCityModel _city(int k, String name, {String state = 'Uttarakhand', bool ready = true, int spots = 5, String? district}) =>
    TripCityModel(
      cityKey: k,
      name: name,
      districtName: district ?? 'District $k',
      stateName: state,
      latitude: 1,
      longitude: 1,
      spotCount: spots,
      status: ready ? TripCityStatus.ready : TripCityStatus.notReady,
    );

class _Catalog extends TripCityCatalog {
  _Catalog(this.list);
  final List<TripCityModel> list;
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => true;
  @override
  Future<List<TripCityModel>> load({bool force = false}) async => list;
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
  _Trips(this.trip);
  final TripSummaryModel? trip;
  @override
  Future<void> ensureLoaded() async {}
  @override
  Future<void> load({bool refresh = false}) async {}
  @override
  List<TripSummaryModel> get continueTrips {
    active.length;
    return [?trip];
  }

}

TripSummaryModel _trip({String title = '', String guideStep = 'taxi'}) => TripSummaryModel.fromJson({
      'id': 'trip-1',
      'title': title,
      'status': 'Planned',
      'cityName': 'Nainital',
      'dayCount': 2,
      'spotCount': 4,
      'category': 'attraction',
      'updatedAt': '2026-11-01T10:00:00Z',
      'progress': {
        'total': 4,
        'done': 1,
        'percent': 25,
        'next': {'kind': 'gettingThere', 'key': 'gettingThere'},
        'guideStep': guideStep,
      },
    });

Future<void> _pump(
  WidgetTester t,
  List<TripCityModel> cities,
  double w, {
  double scale = 1,
  double inset = 0,
  TripSummaryModel? trip,
  bool where = false,
}) async {
  Get.put<TripCityCatalog>(_Catalog(cities), permanent: true);
  Get.put<MyTripsController>(_Trips(trip), permanent: true);
  setGoldenView(t, Size(w, 800));
  await t.pumpWidget(GetMaterialApp(
    theme: ThemeData(fontFamily: 'WorkSans'),
    home: MediaQuery(
      data: MediaQueryData(size: Size(w, 800), textScaler: TextScaler.linear(scale), viewInsets: EdgeInsets.only(bottom: inset)),
      child: where ? const TripWhereScreen() : const TripsDiscoveryScreen(),
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return Directory.systemTemp.createTempSync('a1_gs').path;
    });
    await GetStorage.init();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  group('city tile', () {
    test('line is District and N places, spot count one is singular', () {
      expect(_city(1, 'A', district: 'Nainital', spots: 12).tileLine, 'Nainital · 12 places');
      expect(_city(1, 'A', district: 'Nainital', spots: 1).tileLine, 'Nainital · 1 place');
      expect(_city(1, 'A', district: 'Nainital', spots: 0).tileLine, 'Nainital');
      expect(_city(1, 'A', district: '', spots: 3).tileLine, '3 places');
    });

    testWidgets('300 dp, text scale 2: title wraps to two lines with ellipsis, card grows', (t) async {
      setGoldenView(t, const Size(300, 420));
      final city = _city(7, 'Rishikesh and a very long city name', district: 'Pauri Garhwal district of the hills', spots: 24);
      await t.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'WorkSans'),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(300, 420), textScaler: TextScaler.linear(2)),
          child: Scaffold(
            backgroundColor: goldenBg,
            body: RepaintBoundary(
              key: const ValueKey('tile_root'),
              child: Center(
                child: SingleChildScrollView(child: TripCityTile(city: city, width: 140, onTap: () {})),
              ),
            ),
          ),
        ),
      ));
      await t.pump();
      expect(t.takeException(), isNull);
      final title = t.widget<Text>(find.textContaining(RegExp(r'^Ri.*…$')).first);
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
    });
  });

  group('empty search card', () {
    testWidgets('Show all states appears with a state chip on and brings the grid back', (t) async {
      final cities = [_city(1, 'Nainital'), _city(2, 'Shimla', state: 'Himachal Pradesh')];
      await _pump(t, cities, 360, where: true);
      final chip = find.text('Himachal Pradesh');
      await t.ensureVisible(chip);
      await t.pump();
      await t.tap(chip);
      await t.pump();
      await t.enterText(find.byType(TextField), 'Nainital');
      await t.pump();
      expect(find.text('No city found'), findsOneWidget);
      expect(find.text('Show all states'), findsOneWidget);
      await t.tap(find.text('Show all states'));
      await t.pump();
      expect(find.byType(TripCityTile), findsOneWidget);
      expect(find.text('Show all states'), findsNothing);
    });

    testWidgets('no action when no state chip is on', (t) async {
      await _pump(t, [_city(1, 'Nainital'), _city(2, 'Shimla', state: 'Himachal Pradesh')], 360, where: true);
      await t.enterText(find.byType(TextField), 'zzzz');
      await t.pump();
      expect(find.text('No city found'), findsOneWidget);
      expect(find.text('Show all states'), findsNothing);
    });

    testWidgets('a city with no places is never listed', (t) async {
      final cities = [_city(1, 'Nainital'), _city(2, 'Nainpur', ready: false)];
      await _pump(t, cities, 360, where: true);
      expect(find.text('Nainpur'), findsNothing);
      await t.enterText(find.byType(TextField), 'Nain');
      await t.pump();
      expect(find.byType(TripCityTile), findsOneWidget);
      expect(find.text('Nainital'), findsOneWidget);
      expect(find.text('Nainpur'), findsNothing);
      expect(find.textContaining('No places yet'), findsNothing);
    });

    testWidgets('only a no-places match: just the empty card', (t) async {
      await _pump(t, [_city(1, 'Nainital'), _city(2, 'Zebra Falls', ready: false)], 360, where: true);
      await t.enterText(find.byType(TextField), 'Zebra');
      await t.pump();
      expect(find.text('No city found'), findsOneWidget);
      expect(find.text('Zebra Falls'), findsNothing);
    });
  });

  group('Continue bar and keyboard', () {
    testWidgets('bar shows the heading, the trip name and the saved step', (t) async {
      await _pump(t, [_city(1, 'Nainital')], 360, trip: _trip(title: 'Hills with family'));
      expect(find.textContaining('Hills with family'), findsOneWidget);
      expect(find.textContaining('Local taxi'), findsOneWidget);
      expect(find.text('Continue your trip'), findsOneWidget);
    });

    testWidgets('no title falls back to the route', (t) async {
      await _pump(t, [_city(1, 'Nainital')], 360, trip: _trip());
      expect(find.textContaining('Nainital'), findsWidgets);
      expect(find.textContaining('Local taxi'), findsOneWidget);
    });

    for (final w in [300.0, 360.0]) {
      testWidgets('typing in Where to next with the keyboard open fits and clearing restores Popular @${w.toInt()}', (t) async {
        await _pump(t, [_city(1, 'Nainital')], w, scale: 1.5, inset: 300, where: true);
        expect(find.text('Popular'), findsOneWidget);
        await t.enterText(find.byType(TextField), 'Nain');
        await t.pump();
        expect(find.text('Cities'), findsOneWidget);
        expect(find.text('Popular'), findsNothing);
        expect(find.byType(TripCityTile), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.enterText(find.byType(TextField), '');
        await t.pump();
        expect(find.text('Popular'), findsOneWidget);
      });
    }
  });

  test('withRetry once makes one attempt even on a network error', () async {
    var calls = 0;
    final sw = Stopwatch()..start();
    await expectLater(
      withRetry<int>(() async {
        calls++;
        throw DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError);
      }, once: true),
      throwsA(isA<DioException>()),
    );
    expect(calls, 1);
    expect(sw.elapsed, lessThan(const Duration(seconds: 1)));
  });

  group('tile tap and the draft', () {
    Future<Map?> tapTile(WidgetTester t, TripCityModel city) async {
      Map? args;
      await t.pumpWidget(GetMaterialApp(
        home: const Scaffold(body: SizedBox()),
        getPages: [
          GetPage(
            name: AppRoutes.tripSpots,
            page: () {
              args = Get.arguments as Map?;
              return const Scaffold(body: Text('spots'));
            },
          ),
        ],
      ));
      TripNavigation.startWithCities([city]);
      await t.pumpAndSettle();
      return args;
    }

    testWidgets('same city draft seeds the selection and is kept', (t) async {
      final nainital = _city(1, 'Nainital');
      TripNewDraft.save([TripDraftLeg(nainital, ['a', 'b'])]);
      final args = await tapTile(t, nainital);
      final legs = args!['draftLegs'] as List<TripDraftLeg>;
      expect(legs.single.ids, ['a', 'b']);
      expect(TripNewDraft.read()!.legs.single.ids, ['a', 'b']);
    });

    testWidgets('another city starts clean and clears the old draft', (t) async {
      TripNewDraft.save([TripDraftLeg(_city(1, 'Nainital'), ['a'])]);
      final args = await tapTile(t, _city(2, 'Almora'));
      expect(args!.containsKey('draftLegs'), isFalse);
      expect(StorageService.getTripNewDraft(), isNull);
    });
  });
}
