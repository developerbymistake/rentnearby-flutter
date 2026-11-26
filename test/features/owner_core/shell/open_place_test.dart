import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/navigation/traveller_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';

Future<void> _pumpApp(WidgetTester t) => pumpPhone(
      t,
      const Scaffold(body: Text('home')),
      toastHost: true,
      pages: [
        GetPage(name: AppRoutes.tripWhere, page: () => const Scaffold(body: Text('where'))),
        GetPage(name: AppRoutes.taxiList, page: () => const Scaffold(body: Text('taxi list'))),
      ],
    );

Future<void> _toast(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> _clearToast(WidgetTester t) async {
  await t.pump(const Duration(seconds: 5));
  toastification.dismissAll(delayForAnimation: false);
  await t.pump(const Duration(seconds: 1));
  expect(t.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    await initTestStorage('open_place');
    await loadRealFonts();
  });

  late FakeAuth auth;

  setUp(() {
    toastification.managers.clear();
    Get.testMode = true;
    Get.put<TabConfigController>(FakeTabs());
    auth = FakeAuth();
    Get.put<AuthController>(auth);
  });
  tearDown(Get.reset);

  testWidgets('owner shell: Plan a trip opens nothing and never selects slot 2', (tester) async {
    auth.signIn(role: UserRoleKeys.stayOwner, stayStatus: 'Approved');
    await _pumpApp(tester);
    auth.openPlace(AppPlace.trips);
    await _toast(tester);
    expect(find.text(TravellerGateStrings.line), findsOneWidget);
    expect(find.text('where'), findsNothing);
    expect(auth.tabIndex.value, AppTabs.home);
    await _clearToast(tester);
  });

  testWidgets('owner shell: a taxi detail link does not push the list first', (tester) async {
    auth.signIn(role: UserRoleKeys.taxiDriver, taxiStatus: 'Approved');
    await _pumpApp(tester);
    auth.openPlace(AppPlace.taxi, detail: true);
    await tester.pumpAndSettle();
    expect(find.text('taxi list'), findsNothing);
    expect(auth.tabIndex.value, AppTabs.home);
  });

  testWidgets('seeker shell: places are tab switches as today', (tester) async {
    auth.signIn(role: UserRoleKeys.seeker);
    await _pumpApp(tester);
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
