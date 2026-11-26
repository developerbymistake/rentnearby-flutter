import 'dart:io';

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

import '../../support/owner_fakes.dart';
import '../../support/real_phone.dart';

Future<void> _pumpApp(WidgetTester t) => pumpPhone(
      t,
      const Scaffold(body: Text('home')),
      toastHost: true,
      pages: [GetPage(name: AppRoutes.tripWhere, page: () => const Scaffold(body: Text('where')))],
    );

Future<void> _toast(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() async {
    await initTestStorage('deep_link_guard_test');
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

  test('deep links carry only the stay and taxi types, no trip or buddy link exists', () {
    final src = File('lib/services/deep_link_service.dart').readAsStringSync();
    final types = RegExp(r"'(\w+)':\s*_DeepLinkTypeConfig\(").allMatches(src).map((m) => m.group(1)).toSet();
    expect(types, {'s', 't'});
  });

  for (final (name, role, status) in [
    ('stay owner', UserRoleKeys.stayOwner, 'Approved'),
    ('taxi driver', UserRoleKeys.taxiDriver, 'Approved'),
    ('stay owner in the seeker shell', UserRoleKeys.stayOwner, 'Draft'),
  ]) {
    testWidgets('$name: opening the trips place pushes nothing and keeps Home', (t) async {
      auth.signIn(role: role, stayStatus: role == UserRoleKeys.stayOwner ? status : null, taxiStatus: role == UserRoleKeys.taxiDriver ? status : null);
      await _pumpApp(t);
      auth.openPlace(AppPlace.trips);
      await _toast(t);
      expect(find.text(TravellerGateStrings.line), findsOneWidget);
      expect(find.text('where'), findsNothing);
      expect(auth.tabIndex.value, AppTabs.home);
      await t.pump(const Duration(seconds: 5));
      toastification.dismissAll(delayForAnimation: false);
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('seeker: opening the trips place switches to the Trips tab', (t) async {
    auth.signIn(role: UserRoleKeys.seeker);
    await _pumpApp(t);
    auth.openPlace(AppPlace.trips);
    await t.pump();
    expect(auth.tabIndex.value, AppTabs.trips);
  });

  test('a push naming a traveller route is refused for owners, so it falls back to the inbox', () {
    for (final route in [AppRoutes.tripOverview, AppRoutes.tripInvite, AppRoutes.myEnquiries]) {
      for (final (role, status) in [(UserRoleKeys.stayOwner, 'Approved'), (UserRoleKeys.taxiDriver, 'Approved')]) {
        auth.signIn(role: role, stayStatus: status, taxiStatus: status);
        expect(auth.canOpenRoute(route), isFalse, reason: '$route as $role');
      }
      auth.signIn(role: UserRoleKeys.seeker);
      expect(auth.canOpenRoute(route), isTrue, reason: '$route as seeker');
    }
  });
}
