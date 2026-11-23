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
  Future<void> reload() async {}
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

Future<void> _openHome(WidgetTester t, {required double w, double s = 1}) async {
  Get.reset();
  Get.put<TabConfigController>(_Tabs());
  Get.put<AuthController>(_Auth());
  Get.put<LocationController>(JLoc());
  Get.put<HomeController>(_Home());
  Get.put<NotificationController>(_Notif());
  Get.put<ChatController>(_Chat());
  Get.put<PlanController>(_Plan());
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

    for (final w in journeyWidths) {
      for (final s in journeyScales) {
        testWidgets('Change 7: Home shows no stays or taxi rail at ${w.toInt()} dp, text scale $s', (t) async {
          await _openHome(t, w: w, s: s);
          for (final title in ['Stays near you', 'Taxis near you', 'Nearest stays', 'Nearest taxis', 'Recently added stays']) {
            expect(find.text(title), findsNothing, reason: title);
          }
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
