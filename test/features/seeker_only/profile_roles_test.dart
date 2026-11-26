import 'package:bakhli/config/shell_kind.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/buddy/buddies/buddies_strings.dart';
import 'package:bakhli/features/buddy/buddy_strings.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import '../../support/real_phone.dart';

const _username = 'Bakhli#48291736';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  bool isActive(String tabKey) {
    version.value;
    return true;
  }
}

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> refreshProfile() async {}
}

void _setUp(String role, ShellKind shell) {
  Get.reset();
  Get.put<TabConfigController>(_Tabs());
  final a = Get.put<AuthController>(_Auth());
  a.roleKey.value = role;
  final caps = RoleCapabilities.of(role);
  a.canListStays.value = caps.canListStays;
  a.canListTaxis.value = caps.canListTaxis;
  a.shellKind.value = shell;
  a.profileName.value = 'Meena Bisht';
  a.profilePhone.value = '9897012345';
  a.user.value = UserModel(id: 'u', phoneNumber: '9897012345', name: 'Meena Bisht', username: _username, createdAt: DateTime(2026), role: role, roleConfirmed: true);
  Get.put(PlanController()).myPlan.value = MyPlanModel(paymentEnabled: false);
}

Future<void> _open(WidgetTester t) async {
  await pumpPhone(t, const ProfileScreen(), size: const Size(392, 2600), toastHost: true);
  await settlePhone(t);
}

Future<void> _finish(WidgetTester t) async {
  await t.pump(const Duration(seconds: 5));
  toastification.dismissAll(delayForAnimation: false);
  await t.pump(const Duration(seconds: 1));
  expect(t.takeException(), isNull);
}

const _travellerTexts = [BuddyStrings.sectionBuddies, _username, BuddiesStrings.title, 'My Trips', 'My Journeys'];

void main() {
  setUpAll(loadRealFonts);
  tearDown(Get.reset);

  testWidgets('seeker sees BUDDIES, username, Buddies, My Trips and My Journeys', (t) async {
    _setUp(UserRoleKeys.seeker, ShellKind.seeker);
    await _open(t);
    for (final text in _travellerTexts) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    await _finish(t);
  });

  for (final (name, role, shell) in [
    ('stay owner', UserRoleKeys.stayOwner, ShellKind.stayOwner),
    ('taxi driver', UserRoleKeys.taxiDriver, ShellKind.taxiDriver),
    ('stay owner in the seeker shell', UserRoleKeys.stayOwner, ShellKind.seeker),
    ('taxi driver in the seeker shell', UserRoleKeys.taxiDriver, ShellKind.seeker),
  ]) {
    testWidgets('$name sees no traveller entry and keeps ACCOUNT, My Reports and Logout', (t) async {
      _setUp(role, shell);
      await _open(t);
      for (final text in [..._travellerTexts, BuddyStrings.usernameLabel, 'Plan a trip', 'Travel as a guest']) {
        expect(find.text(text), findsNothing, reason: text);
      }
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('My Reports'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
      if (shell == ShellKind.taxiDriver) expect(find.text('My rating'), findsOneWidget);
      await _finish(t);
    });
  }
}
