import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/features/trip/trip_navigation.dart';
import 'package:bakhli/features/trip/widgets/trip_home_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  void switchToTab(int index) => tabIndex.value = index;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  test('openTripsTab switches to the Trips tab', () {
    final auth = Get.put<AuthController>(_Auth());
    expect(auth.tabIndex.value, AppTabs.home);
    TripNavigation.openTripsTab();
    expect(auth.tabIndex.value, AppTabs.trips);
  });

  testWidgets('Home trip card tap sets the Trips tab', (tester) async {
    final auth = Get.put<AuthController>(_Auth());
    await tester.pumpWidget(GetMaterialApp(home: Scaffold(body: ListView(children: const [TripHomeCard()]))));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byType(TripHomeCard));
    await tester.pump();
    expect(auth.tabIndex.value, AppTabs.trips);
  });
}
