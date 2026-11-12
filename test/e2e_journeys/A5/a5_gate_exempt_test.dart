import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/widgets/global_location_gates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  // Real life: a traveller outside any live district (no GPS) opens the Trips tab to plan a trip for another place.
  test('Trips tab root is exempt from the GPS and district gates', () {
    final auth = Get.put<AuthController>(_Auth());
    auth.tabIndex.value = AppTabs.trips;
    expect(GlobalLocationGates.locationExempt(AppRoutes.main), isTrue);
  });

  test('other tabs at the main root are still gated', () {
    final auth = Get.put<AuthController>(_Auth());
    auth.tabIndex.value = AppTabs.stays;
    expect(GlobalLocationGates.locationExempt(AppRoutes.main), isFalse);
    auth.tabIndex.value = AppTabs.home;
    expect(GlobalLocationGates.locationExempt(AppRoutes.main), isFalse);
  });

  test('trip pages stay exempt and an unrelated page is gated', () {
    Get.put<AuthController>(_Auth());
    expect(GlobalLocationGates.locationExempt(AppRoutes.tripPlan), isTrue);
    expect(GlobalLocationGates.locationExempt(AppRoutes.myTrips), isTrue);
    expect(GlobalLocationGates.locationExempt(AppRoutes.notifications), isFalse);
  });
}
