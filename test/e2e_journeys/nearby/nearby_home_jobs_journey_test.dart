import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/chat_controller.dart';
import 'package:bakhli/controllers/home_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/jobs/v2/jobs_city_sheet_v2.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/models/home_feed_model_v2.dart';
import 'package:bakhli/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../ui_golden/golden_support.dart';
import 'nearby_support.dart';

class _Auth extends JAuth {}

class _Home extends HomeController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> reloadDistrict() async {}
}

class _Notif extends NotificationController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Chat extends ChatController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Plan extends PlanController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  bool get isStaysActive {
    version.value;
    return true;
  }

  @override
  bool get isTaxiActive {
    version.value;
    return true;
  }
}

Map<String, dynamic> _stay(String id, double km, String label, String city) => {
      'id': id,
      'userId': 'u',
      'name': 'Stay $id',
      'cityName': city,
      'districtName': 'Nainital',
      'stateName': 'Uttarakhand',
      'minPricePerNight': 1200,
      'distanceKm': km,
      'labelKey': label,
    };

Map<String, dynamic> _taxi(String id, double km, String label, String city) => {
      'id': id,
      'driverName': 'Driver $id',
      'vehicleTypeName': 'Sedan',
      'plateDisplay': 'UK04',
      'routeCount': 2,
      'createdAt': '2026-11-01T00:00:00Z',
      'cityName': city,
      'stateName': 'Uttarakhand',
      'distanceKm': km,
      'labelKey': label,
    };

Future<_Home> _openHome(WidgetTester t, Map<String, dynamic> feedJson, {required double w, double s = 1}) async {
  Get.reset();
  Get.put<TabConfigController>(_Tabs());
  Get.put<AuthController>(_Auth());
  Get.put<LocationController>(JLoc());
  final home = Get.put<HomeController>(_Home()) as _Home;
  Get.put<NotificationController>(_Notif());
  Get.put<ChatController>(_Chat());
  Get.put<PlanController>(_Plan());
  final feed = HomeFeedModelV2.fromJson(feedJson);
  home.farAway.value = feed.header.farAway;
  home.stays.assignAll(feed.stays ?? const []);
  home.taxis.assignAll(feed.taxis ?? const []);
  home.staysLoading.value = false;
  home.taxisLoading.value = false;
  home.recentlyAddedStaysLoading.value = false;
  setGoldenView(t, Size(w, 2600));
  await t.pumpWidget(GetMaterialApp(
    theme: AppTheme.theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(s)),
      child: child!,
    ),
    home: const HomeScreen(),
  ));
  await t.pump(const Duration(seconds: 1));
  await t.pump(const Duration(seconds: 1));
  return home;
}

TripCityModel _city(int k, String n, String state, {bool ready = true}) => TripCityModel(
      cityKey: k,
      name: n,
      districtName: 'D$k',
      stateName: state,
      latitude: 29,
      longitude: 79,
      status: ready ? TripCityStatus.ready : TripCityStatus.notReady,
    );

class _Cached extends TripCityCatalog {
  final list = [_city(1, 'Nainital', 'Uttarakhand'), _city(2, 'Manali', 'Himachal Pradesh'), _city(3, 'Hidden', 'Uttarakhand', ready: false)];
  int loads = 0;
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => true;
  @override
  Future<List<TripCityModel>> load({bool force = false}) async {
    loads++;
    throw Exception('offline');
  }

  @override
  List<TripCityModel> ready(String q, {String? stateName}) => [
        for (final c in q.trim().isEmpty ? list : TripCitySearch.filter(list, q))
          if (c.isReady && (stateName == null || c.stateName == stateName)) c,
      ];
  @override
  List<String> liveStates() => ['Himachal Pradesh', 'Uttarakhand'];
}

class _Empty extends TripCityCatalog {
  bool online = false;
  bool _has = false;
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => _has;
  @override
  Future<List<TripCityModel>> load({bool force = false}) async {
    if (!online) throw Exception('offline');
    _has = true;
    return [_city(1, 'Nainital', 'Uttarakhand')];
  }

  @override
  List<TripCityModel> ready(String q, {String? stateName}) => [_city(1, 'Nainital', 'Uttarakhand')];
  @override
  List<String> liveStates() => ['Uttarakhand'];
}

Future<void> _openSheet(WidgetTester t, double w, double s) async {
  setGoldenView(t, Size(w, 1400));
  await t.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'WorkSans'),
    home: MediaQuery(
      data: MediaQueryData(size: Size(w, 1400), textScaler: TextScaler.linear(s)),
      child: const Scaffold(body: JobsCitySheetV2()),
    ),
  ));
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  group('home rails', () {
    test('the home feed header is parsed', () {
      final f = HomeFeedModelV2.fromJson({
        'header': {'farAway': true, 'livesIn': 'We are live in Uttarakhand and Himachal Pradesh'},
        'stays': [_stay('a', 210, 'far', 'Haridwar')],
      });
      expect(f.header.farAway, true);
      expect(HomeFeedModelV2.fromJson(const {}).header.farAway, false);
    });

    testWidgets('near user: rails say near you with distance labels', (t) async {
      await _openHome(t, {
        'header': {'farAway': false},
        'stays': [_stay('a', 3, 'near', 'Nainital')],
        'taxis': [_taxi('t', 5, 'near', 'Haldwani')],
      }, w: 360);
      expect(find.text('Stays near you'), findsOneWidget);
      expect(find.text('Taxis near you'), findsOneWidget);
      expect(find.text('Nainital. About 3 km away'), findsOneWidget);
      expect(find.text('Based near Haldwani. About 5 km away'), findsOneWidget);
    });

    testWidgets('far user: rails are honest, no near you, far label on cards', (t) async {
      await _openHome(t, {
        'header': {'farAway': true, 'livesIn': 'We are live in Uttarakhand and Himachal Pradesh'},
        'stays': [_stay('a', 210, 'far', 'Haridwar')],
        'taxis': [_taxi('t', 420, 'far', 'Haldwani')],
      }, w: 360);
      expect(find.text('Nearest stays'), findsOneWidget);
      expect(find.text('Nearest taxis'), findsOneWidget);
      expect(find.text('Stays near you'), findsNothing);
      expect(find.text('Taxis near you'), findsNothing);
      expect(find.text('Haridwar, Uttarakhand. About 210 km away'), findsOneWidget);
      expect(find.text('Haldwani, Uttarakhand. About 420 km away'), findsOneWidget);
    });

    for (final w in journeyWidths) {
      for (final s in journeyScales) {
        testWidgets('far rails fit at ${w.toInt()} dp, text scale $s', (t) async {
          await _openHome(t, {
            'header': {'farAway': true},
            'stays': [for (var i = 0; i < 4; i++) _stay('a$i', 210.0 + i, 'far', 'Haridwar')],
            'taxis': [for (var i = 0; i < 4; i++) _taxi('t$i', 420.0 + i, 'far', 'Haldwani')],
          }, w: w, s: s);
          expect(find.text('Nearest stays'), findsOneWidget);
          expect(t.takeException(), isNull);
        });
      }
    }
  });

  group('jobs city sheet offline', () {
    for (final w in journeyWidths) {
      for (final s in journeyScales) {
        testWidgets('cached cities list and search without a network at ${w.toInt()} dp, scale $s', (t) async {
          final c = _Cached();
          Get.put<TripCityCatalog>(c, permanent: true);
          await _openSheet(t, w, s);
          expect(find.text('Nainital'), findsOneWidget);
          expect(find.text('Hidden'), findsNothing);
          await t.enterText(find.byType(TextField), 'mana');
          await t.pump(const Duration(milliseconds: 300));
          expect(find.text('Manali'), findsOneWidget);
          expect(find.text('Nainital'), findsNothing);
          expect(c.loads, 0);
          expect(t.takeException(), isNull);
        });
      }
    }

    testWidgets('no cache and no network: honest message, retry brings the list', (t) async {
      final c = _Empty();
      Get.put<TripCityCatalog>(c, permanent: true);
      await _openSheet(t, 360, 1);
      expect(find.text('Nainital'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      c.online = true;
      await t.tap(find.text('Try again'));
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Nainital'), findsOneWidget);
    });
  });
}
