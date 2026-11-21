import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/config/tab_shell.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';

const _statuses = <String?>[null, 'Draft', 'PendingReview', 'Approved', 'Rejected', 'Banana'];
const _shellStatuses = {'PendingReview', 'Approved', 'Rejected'};

void main() {
  setUpAll(() => initTestStorage('tab_shell_rules_test'));
  group('kindFor', () {
    for (final role in [UserRoleKeys.seeker, UserRoleKeys.stayOwner, UserRoleKeys.taxiDriver, 'RENT_OWNER']) {
      for (final status in _statuses) {
        for (final empty in [false, true]) {
          test('$role / $status / empty=$empty', () {
            final stay = TabShell.kindFor(roleKey: role, stayStatus: status, taxiStatus: null, emptyShell: empty);
            final taxi = TabShell.kindFor(roleKey: role, stayStatus: null, taxiStatus: status, emptyShell: empty);
            final owner = _shellStatuses.contains(status) || empty;
            ShellKind want(bool ownStatus) {
              final shell = ownStatus ? owner : empty;
              if (role == UserRoleKeys.stayOwner && shell) return ShellKind.stayOwner;
              if (role == UserRoleKeys.taxiDriver && shell) return ShellKind.taxiDriver;
              return ShellKind.seeker;
            }

            expect(stay, role == UserRoleKeys.stayOwner ? want(true) : want(false));
            expect(taxi, role == UserRoleKeys.taxiDriver ? want(true) : want(false));
          });
        }
      }
    }
  });

  group('slots', () {
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

    test('every kind has 5 slots in index order and exactly one centre', () {
      for (final kind in ShellKind.values) {
        final s = TabShell.slots(kind);
        expect(s.map((e) => e.index), [0, 1, 2, 3, 4], reason: '$kind');
        expect(s.where((e) => e.center), hasLength(1), reason: '$kind');
        expect(s[AppTabs.centre].center, isTrue);
      }
    });

    test('labels follow the frames', () {
      expect(TabShell.slots(ShellKind.stayOwner).map((s) => s.label), ['Home', 'My Stay', 'Enquiries', 'Jobs', 'Profile']);
      expect(TabShell.slots(ShellKind.taxiDriver).map((s) => s.label), ['Home', 'My Taxi', 'Requests', 'Bookings', 'Profile']);
      expect(TabShell.slots(ShellKind.seeker).map((s) => s.label), ['Home', 'Stays', 'Trips', 'Taxi', 'Profile']);
    });

    test('stay Jobs slot only with JOBS on, STAYS on and a stay', () {
      for (final jobs in [true, false]) {
        for (final stays in [true, false]) {
          for (final exists in [true, false]) {
            tabs.setOff({if (!jobs) AppTabKeys.jobs, if (!stays) AppTabKeys.stays});
            auth.signIn(role: UserRoleKeys.stayOwner, stayStatus: exists ? 'Approved' : null, listingDeleted: !exists);
            expect(auth.shellKind.value, ShellKind.stayOwner);
            expect(TabShell.isActive(ShellKind.stayOwner, AppTabs.fourth), jobs && stays && exists, reason: 'jobs=$jobs stays=$stays exists=$exists');
            for (final i in [0, 1, 2, 4]) {
              expect(TabShell.isActive(ShellKind.stayOwner, i), isTrue);
            }
          }
        }
      }
    });

    test('taxi slots never depend on a tab switch', () {
      tabs.setOff({AppTabKeys.taxi, AppTabKeys.stays, AppTabKeys.jobs});
      for (var i = 0; i < AppTabs.count; i++) {
        expect(TabShell.isActive(ShellKind.taxiDriver, i), isTrue);
      }
    });

    test('seeker activity equals isActiveForIndex', () {
      for (final off in [<String>{}, {AppTabKeys.stays}, {AppTabKeys.taxi}, {AppTabKeys.stays, AppTabKeys.taxi}]) {
        tabs.setOff(off);
        for (var i = 0; i < AppTabs.count; i++) {
          expect(TabShell.isActive(ShellKind.seeker, i), tabs.isActiveForIndex(i), reason: '$off $i');
        }
      }
    });

    test('tabForRoute table', () {
      auth.signIn(role: UserRoleKeys.stayOwner, stayStatus: 'Approved');
      expect(TabShell.tabForRoute(ShellKind.stayOwner, AppRoutes.myStays, null), AppTabs.hub);
      expect(TabShell.tabForRoute(ShellKind.stayOwner, AppRoutes.stayEnquiries, null), AppTabs.centre);
      expect(TabShell.tabForRoute(ShellKind.stayOwner, AppRoutes.myJobs, null), AppTabs.fourth);
      tabs.setOff({AppTabKeys.jobs});
      expect(TabShell.tabForRoute(ShellKind.stayOwner, AppRoutes.myJobs, null), isNull);
      expect(TabShell.tabForRoute(ShellKind.stayOwner, AppRoutes.stayCalendar, null), isNull);
      expect(TabShell.tabForRoute(ShellKind.stayOwner, AppRoutes.myTaxi, null), isNull);
      expect(TabShell.tabForRoute(ShellKind.taxiDriver, AppRoutes.myTaxi, null), AppTabs.hub);
      expect(TabShell.tabForRoute(ShellKind.taxiDriver, AppRoutes.taxiRequests, null), AppTabs.centre);
      expect(TabShell.tabForRoute(ShellKind.taxiDriver, AppRoutes.tripLeads, null), AppTabs.centre);
      expect(TabShell.tabForRoute(ShellKind.taxiDriver, AppRoutes.taxiBookings, null), AppTabs.fourth);
      expect(TabShell.tabForRoute(ShellKind.taxiDriver, AppRoutes.myStays, null), isNull);
      for (final r in [AppRoutes.myStays, AppRoutes.myTaxi, AppRoutes.taxiRequests, AppRoutes.myJobs]) {
        expect(TabShell.tabForRoute(ShellKind.seeker, r, null), isNull);
      }
    });

    test('shell follows the user: empty shell, listing deleted, logout fields', () {
      auth.signIn(role: UserRoleKeys.stayOwner, stayStatus: null);
      expect(auth.shellKind.value, ShellKind.seeker);
      auth.signIn(role: UserRoleKeys.stayOwner, stayStatus: null, listingDeleted: true);
      expect(auth.shellKind.value, ShellKind.stayOwner);
      expect(auth.ownerShellEmpty.value, isTrue);
      expect(TabShell.isActive(ShellKind.stayOwner, AppTabs.fourth), isFalse);
      auth.signIn(role: UserRoleKeys.taxiDriver, taxiStatus: 'PendingReview');
      expect(auth.shellKind.value, ShellKind.taxiDriver);
    });
  });
}
