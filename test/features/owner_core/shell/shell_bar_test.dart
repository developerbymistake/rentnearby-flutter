import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/config/tab_shell.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/extra/template_nav.dart';
import 'package:bakhli/features/stay_owner/home/stay_owner_home_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_sizes.dart';

Widget _bar(ShellKind kind, {int selected = AppTabs.home}) {
  final items = [
    for (final s in TabShell.slots(kind))
      if (s.active())
        TemplateNavItem(
          index: s.index,
          image: s.image,
          label: s.label,
          center: s.center,
          activeColor: s.activeColor,
          badge: s.badge?.call(),
          badgeColor: s.badgeColor,
        ),
  ];
  return Scaffold(
    body: const SizedBox.expand(),
    bottomNavigationBar: TemplateBottomBar(items: items, selectedIndex: selected, onTap: (_) {}, bottomInset: 0),
  );
}

void main() {
  setUpAll(() => initTestStorage('shell_bar_test'));
  late FakeAuth auth;

  void setUpShell({required String role, String? stay, String? taxi, int badge = 0, Set<String> off = const {}}) {
    Get.reset();
    Get.testMode = true;
    Get.put<TabConfigController>(FakeTabs(off: {...off}));
    auth = FakeAuth();
    Get.put<AuthController>(auth);
    auth.signIn(role: role, stayStatus: stay, taxiStatus: taxi);
    Get.put(StayOwnerHomeController()).centreBadge.value = badge;
  }

  tearDown(Get.reset);

  for (final badge in [0, 3, 12]) {
    testOwnerSizes(
      'stay owner bar, badge $badge',
      () => _bar(ShellKind.stayOwner, selected: AppTabs.centre),
      setUpEach: () => setUpShell(role: UserRoleKeys.stayOwner, stay: 'Approved', badge: badge),
      check: (tester, size, scale) async {
        for (final l in ['Home', 'My Stay', 'Enquiries', 'Jobs', 'Profile']) {
          expect(find.text(l), findsOneWidget);
        }
        expect(find.byKey(const ValueKey('nav_badge')), badge == 0 ? findsNothing : findsOneWidget);
        if (badge > 0) expect(find.text('$badge'), findsOneWidget);
      },
    );
  }

  testOwnerSizes(
    'stay owner 4-tab bar without Jobs',
    () => _bar(ShellKind.stayOwner),
    setUpEach: () => setUpShell(role: UserRoleKeys.stayOwner, stay: 'Approved', off: {AppTabKeys.jobs}),
    check: (tester, size, scale) async {
      expect(find.text('Jobs'), findsNothing);
      expect(find.text('Enquiries'), findsOneWidget);
    },
  );

  testOwnerSizes(
    'taxi driver bar',
    () => _bar(ShellKind.taxiDriver, selected: AppTabs.fourth),
    setUpEach: () => setUpShell(role: UserRoleKeys.taxiDriver, taxi: 'Approved'),
    check: (tester, size, scale) async {
      for (final l in ['Home', 'My Taxi', 'Requests', 'Bookings', 'Profile']) {
        expect(find.text(l), findsOneWidget);
      }
    },
  );

  testOwnerSizes(
    'seeker bar unchanged',
    () => _bar(ShellKind.seeker),
    setUpEach: () => setUpShell(role: UserRoleKeys.seeker),
    check: (tester, size, scale) async {
      for (final l in ['Home', 'Stays', 'Trips', 'Taxi', 'Profile']) {
        expect(find.text(l), findsOneWidget);
      }
    },
  );
}
