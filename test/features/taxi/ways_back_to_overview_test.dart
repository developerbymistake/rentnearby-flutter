import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/taxi/ways/way_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

GetPage _page(String name) => GetPage(name: name, page: () => Scaffold(body: Text(name)));

Future<void> _app(WidgetTester t, List<String> stack) async {
  await t.pumpWidget(GetMaterialApp(
    initialRoute: AppRoutes.main,
    getPages: [
      _page(AppRoutes.main),
      _page(AppRoutes.tripOverview),
      _page(AppRoutes.tripPlan),
      _page(AppRoutes.tripStay),
      _page(AppRoutes.taxiWays),
    ],
  ));
  for (final r in stack) {
    Get.toNamed(r);
    await t.pumpAndSettle();
  }
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('ways opened from the stay list return to the trip overview, not main', (t) async {
    await _app(t, [AppRoutes.tripOverview, AppRoutes.tripStay, AppRoutes.taxiWays]);
    WayActions.backToPlan();
    await t.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.tripOverview);
  });

  testWidgets('ways opened from the day plan still return to the day plan', (t) async {
    await _app(t, [AppRoutes.tripOverview, AppRoutes.tripPlan, AppRoutes.taxiWays]);
    WayActions.backToPlan();
    await t.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.tripPlan);
  });

  testWidgets('ways opened outside a trip go back to main', (t) async {
    await _app(t, [AppRoutes.taxiWays]);
    WayActions.backToPlan();
    await t.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.main);
  });
}
