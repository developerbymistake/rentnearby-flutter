import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/real_phone.dart';

class _Tabs extends TabConfigController {
  final off = <String>{};
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  bool isActive(String tabKey) {
    version.value;
    return !off.contains(tabKey);
  }
}

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

Future<_Tabs> _open(WidgetTester t, {bool driver = false, Set<String> tabsOff = const {}}) async {
  final tabs = _Tabs()..off.addAll(tabsOff);
  final a = _Auth();
  Get.put<TabConfigController>(tabs);
  Get.put<AuthController>(a);
  a.canListTaxis.value = driver;
  Get.put(PlanController()).myPlan.value = MyPlanModel(paymentEnabled: false);
  a.profileName.value = 'Rahul Sharma';
  a.profilePhone.value = '9876543210';
  await pumpPhone(t, const ProfileScreen());
  await settlePhone(t);
  return tabs;
}

List<String> _activity(WidgetTester t) {
  const labels = ['My Trips', 'Jobs', 'My Journeys', 'My Reports'];
  final found = <MapEntry<String, double>>[];
  for (final l in labels) {
    final f = find.text(l);
    if (f.evaluate().isNotEmpty) found.add(MapEntry(l, t.getTopLeft(f.first).dy));
  }
  found.sort((a, b) => a.value.compareTo(b.value));
  return [for (final e in found) e.key];
}

void main() {
  setUpAll(loadRealFonts);
  tearDown(Get.reset);

  testWidgets('Seeker with the Taxi tab on sees My Trips first, then Jobs, My Journeys, My Reports', (t) async {
    await _open(t);
    expect(_activity(t), ['My Trips', 'Jobs', 'My Journeys', 'My Reports']);
  });

  testWidgets('Seeker with the Taxi tab off does not see My Journeys', (t) async {
    await _open(t, tabsOff: {AppTabKeys.taxi});
    expect(_activity(t), ['My Trips', 'Jobs', 'My Reports']);
  });

  testWidgets('Seeker with Stays off loses Jobs but keeps My Trips and My Journeys', (t) async {
    await _open(t, tabsOff: {AppTabKeys.stays});
    expect(_activity(t), ['My Trips', 'My Journeys', 'My Reports']);
  });

  testWidgets('Taxi driver sees the same rows', (t) async {
    await _open(t, driver: true);
    expect(_activity(t), ['My Trips', 'Jobs', 'My Journeys', 'My Reports']);
  });

  testWidgets('My Journeys follows the route guard, not the driver role', (t) async {
    final tabs = await _open(t);
    final auth = Get.find<AuthController>();
    expect(auth.canListTaxis.value, isFalse);
    expect(auth.canOpenRoute(AppRoutes.myJourneys), isTrue);
    tabs.off.add(AppTabKeys.taxi);
    expect(auth.canOpenRoute(AppRoutes.myJourneys), isFalse);
  });
}
