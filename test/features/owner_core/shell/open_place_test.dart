import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';

Widget _app() => GetMaterialApp(
      initialRoute: '/home',
      getPages: [
        GetPage(name: '/home', page: () => const Scaffold(body: Text('home'))),
        GetPage(name: AppRoutes.tripWhere, page: () => const Scaffold(body: Text('where'))),
        GetPage(name: AppRoutes.taxiList, page: () => const Scaffold(body: Text('taxi list'))),
      ],
    );

void main() {
  setUpAll(() => initTestStorage('open_place'));

  late FakeAuth auth;

  setUp(() {
    Get.testMode = true;
    Get.put<TabConfigController>(FakeTabs());
    auth = FakeAuth();
    Get.put<AuthController>(auth);
  });
  tearDown(Get.reset);

  testWidgets('owner shell: Plan a trip pushes the city picker and never selects slot 2', (tester) async {
    auth.signIn(role: UserRoleKeys.stayOwner, stayStatus: 'Approved');
    await tester.pumpWidget(_app());
    auth.openPlace(AppPlace.trips);
    await tester.pumpAndSettle();
    expect(find.text('where'), findsOneWidget);
    expect(auth.tabIndex.value, AppTabs.home);
  });

  testWidgets('owner shell: a taxi detail link does not push the list first', (tester) async {
    auth.signIn(role: UserRoleKeys.taxiDriver, taxiStatus: 'Approved');
    await tester.pumpWidget(_app());
    auth.openPlace(AppPlace.taxi, detail: true);
    await tester.pumpAndSettle();
    expect(find.text('taxi list'), findsNothing);
    expect(auth.tabIndex.value, AppTabs.home);
  });

  testWidgets('seeker shell: places are tab switches as today', (tester) async {
    auth.signIn(role: UserRoleKeys.seeker);
    await tester.pumpWidget(_app());
    auth.openPlace(AppPlace.trips);
    await tester.pump();
    expect(auth.tabIndex.value, AppTabs.trips);
    auth.openPlace(AppPlace.taxi);
    expect(auth.tabIndex.value, AppTabs.taxi);
    expect(find.text('where'), findsNothing);
  });

  test('openTab sets an intent the root takes once', () {
    auth.signIn(role: UserRoleKeys.stayOwner, stayStatus: 'Approved');
    auth.openTab(AppTabs.centre, intent: {'enquiryId': 'q1'});
    expect(auth.tabIndex.value, AppTabs.centre);
    expect(auth.takeIntent(AppTabs.hub), isNull);
    expect(auth.takeIntent(AppTabs.centre)?.args['enquiryId'], 'q1');
    expect(auth.takeIntent(AppTabs.centre), isNull);
  });
}
