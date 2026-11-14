import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/chat_controller.dart';
import 'package:bakhli/controllers/home_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  group('home rails', () {
    test('the home feed header is parsed', () {
      final f = HomeFeedModelV2.fromJson({
        'header': {'farAway': true},
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
      expect(find.text('Nainital'), findsOneWidget);
      expect(find.text('3 km away'), findsOneWidget);
      expect(find.textContaining('About'), findsNothing);
      expect(find.textContaining('Based near'), findsNothing);
    });

    testWidgets('far user: rails are honest, no near you, far label on cards', (t) async {
      await _openHome(t, {
        'header': {'farAway': true},
        'stays': [_stay('a', 210, 'far', 'Haridwar')],
        'taxis': [_taxi('t', 420, 'far', 'Haldwani')],
      }, w: 360);
      expect(find.text('Nearest stays'), findsOneWidget);
      expect(find.text('Nearest taxis'), findsOneWidget);
      expect(find.text('Stays near you'), findsNothing);
      expect(find.text('Taxis near you'), findsNothing);
      expect(find.text('Haridwar'), findsOneWidget);
      expect(find.text('210 km away'), findsOneWidget);
      expect(find.textContaining('Haldwani, Uttarakhand'), findsNothing);
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
}
