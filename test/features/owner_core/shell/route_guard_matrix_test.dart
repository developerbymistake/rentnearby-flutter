import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';

enum _Who { seeker, stay, taxi }

void main() {
  setUpAll(() => initTestStorage('route_guard_matrix_test'));
  late FakeTabs tabs;
  late FakeAuth auth;

  setUp(() {
    Get.testMode = true;
    tabs = FakeTabs();
    Get.put<TabConfigController>(tabs);
    auth = FakeAuth();
    Get.put<AuthController>(auth);
  });
  tearDown(Get.reset);

  void as(_Who who) => switch (who) {
        _Who.seeker => auth.signIn(role: UserRoleKeys.seeker),
        _Who.stay => auth.signIn(role: UserRoleKeys.stayOwner, stayStatus: 'Approved'),
        _Who.taxi => auth.signIn(role: UserRoleKeys.taxiDriver, taxiStatus: 'Approved'),
      };

  void expectOpen(String route, Map<_Who, bool> want, {Set<String> off = const {}}) {
    tabs.setOff(off);
    for (final e in want.entries) {
      as(e.key);
      expect(auth.canOpenRoute(route), e.value, reason: '$route as ${e.key} off=$off');
    }
  }

  test('stay hub and enquiries open as tabs for a Stay Owner, also with STAYS off', () {
    for (final off in [<String>{}, {AppTabKeys.stays}]) {
      for (final r in [AppRoutes.myStays, AppRoutes.stayEnquiries]) {
        expectOpen(r, {_Who.seeker: false, _Who.stay: true, _Who.taxi: false}, off: off);
      }
    }
  });

  test('my-jobs: Stay Owner only while the Jobs slot shows', () {
    expectOpen(AppRoutes.myJobs, {_Who.seeker: false, _Who.stay: true, _Who.taxi: false});
    expectOpen(AppRoutes.myJobs, {_Who.stay: false}, off: {AppTabKeys.jobs});
    expectOpen(AppRoutes.myJobs, {_Who.stay: false}, off: {AppTabKeys.stays});
  });

  test('new stay routes push for a Stay Owner, also with STAYS off', () {
    for (final r in AppRoutes.stayOwnerNewRoutes) {
      expectOpen(r, {_Who.seeker: false, _Who.stay: true, _Who.taxi: false}, off: {AppTabKeys.stays});
    }
  });

  test('taxi tab routes open for a Taxi Driver, also with TAXI off', () {
    for (final r in [AppRoutes.myTaxi, AppRoutes.taxiRequests, AppRoutes.tripLeads, AppRoutes.taxiBookings]) {
      expectOpen(r, {_Who.seeker: false, _Who.stay: false, _Who.taxi: true}, off: {AppTabKeys.taxi});
    }
  });

  test('ring, detail, ready, rating keep the TAXI tab key', () {
    for (final r in [AppRoutes.taxiRequestDetail, AppRoutes.taxiRequestRing, AppRoutes.taxiReady, AppRoutes.taxiRating]) {
      expectOpen(r, {_Who.seeker: false, _Who.stay: false, _Who.taxi: true});
      expectOpen(r, {_Who.taxi: false}, off: {AppTabKeys.taxi});
    }
  });

  test('new taxi routes push for a Taxi Driver', () {
    for (final r in AppRoutes.taxiDriverNewRoutes) {
      expectOpen(r, {_Who.seeker: false, _Who.stay: false, _Who.taxi: true}, off: {AppTabKeys.taxi});
    }
  });

  test('plans for owners, traveller routes for everyone, unregistered for nobody', () {
    expectOpen(AppRoutes.plansBilling, {_Who.seeker: false, _Who.stay: true, _Who.taxi: true});
    for (final r in [AppRoutes.tripReplies, AppRoutes.tripView, AppRoutes.chatConversation]) {
      expectOpen(r, {_Who.seeker: true, _Who.stay: true, _Who.taxi: true});
    }
    expectOpen('/my-listings', {_Who.seeker: false, _Who.stay: false, _Who.taxi: false});
  });

  test('switchToTab falls back to Home for a hidden owner slot', () {
    as(_Who.stay);
    tabs.setOff({AppTabKeys.jobs});
    auth.switchToTab(AppTabs.fourth);
    expect(auth.tabIndex.value, AppTabs.home);
    auth.switchToTab(AppTabs.centre);
    expect(auth.tabIndex.value, AppTabs.centre);
  });
}
