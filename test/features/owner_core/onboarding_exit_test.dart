import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/owner_core/onboarding/onboarding_exit.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/owner_fakes.dart';

class _Quiet extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

UserModel _user({required bool canCorrect, String? stayStatus, String role = UserRoleKeys.seeker}) => UserModel.fromJson({
      'id': 'u1',
      'phoneNumber': '9876543210',
      'createdAt': '2026-11-22T10:00:00Z',
      'roleConfirmed': true,
      'role': role,
      'canCorrectRole': canCorrect,
      'stayStatus': stayStatus,
    });

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put<TabConfigController>(FakeTabs());
  });
  tearDown(Get.reset);

  test('canCorrectRole follows the user flag', () {
    final a = Get.put<AuthController>(_Quiet());
    expect(OnboardingExit.canCorrectRole, isFalse);
    a.user.value = _user(canCorrect: true);
    expect(OnboardingExit.canCorrectRole, isTrue);
    a.user.value = _user(canCorrect: false);
    expect(OnboardingExit.canCorrectRole, isFalse);
  });

  testWidgets('back on page 1 opens the correction flow only when allowed', (t) async {
    final a = Get.put<AuthController>(_Quiet());
    await t.pumpWidget(GetMaterialApp(
      initialRoute: '/start',
      getPages: [
        GetPage(name: '/start', page: () => const Scaffold(body: Text('start'))),
        GetPage(name: AppRoutes.roleSelect, page: () => Scaffold(body: Text('role ${Get.arguments}'))),
      ],
    ));
    a.user.value = _user(canCorrect: false);
    await OnboardingExit.onBackFromFirstPage(isDraft: true, hasDraft: true).timeout(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
    expect(find.text('start'), findsOneWidget);

    a.user.value = _user(canCorrect: true);
    OnboardingExit.onBackFromFirstPage(isDraft: false, hasDraft: true);
    await t.pumpAndSettle();
    expect(find.text('start'), findsOneWidget);

    OnboardingExit.onBackFromFirstPage(isDraft: true, hasDraft: true);
    await t.pumpAndSettle();
    expect(find.textContaining('role'), findsOneWidget);
    expect(Get.arguments, {'correction': true, 'hasDraft': true});
  });
  group('menu Change role (owner order 2026-11-27: Seekers cannot change role)', () {
    Future<void> openMenu(WidgetTester t, {required bool isDraft}) async {
      await t.pumpWidget(GetMaterialApp(
        initialRoute: '/start',
        getPages: [
          GetPage(
            name: '/start',
            page: () => Scaffold(
              body: Builder(
                builder: (c) => TextButton(onPressed: () => OnboardingExit.openMenu(c, isDraft: isDraft, hasDraft: false), child: const Text('menu')),
              ),
            ),
          ),
          GetPage(name: AppRoutes.roleSelect, page: () => const Scaffold(body: Text('correction'))),
          GetPage(name: AppRoutes.roleChange, page: () => const Scaffold(body: Text('role request'))),
        ],
      ));
      await t.tap(find.text('menu'));
      await t.pumpAndSettle();
    }

    testWidgets('a Seeker sees only Log out', (t) async {
      final a = Get.put<AuthController>(_Quiet());
      a.roleKey.value = UserRoleKeys.seeker;
      a.user.value = _user(canCorrect: false);
      await openMenu(t, isDraft: true);
      expect(find.text('Log out'), findsOneWidget);
      expect(find.text('Change role'), findsNothing);
    });

    testWidgets('R4: a Seeker still allowed the one-time correction keeps it, and it opens the correction, not a request', (t) async {
      final a = Get.put<AuthController>(_Quiet());
      a.roleKey.value = UserRoleKeys.seeker;
      a.user.value = _user(canCorrect: true);
      await openMenu(t, isDraft: true);
      await t.tap(find.text('Change role'));
      await t.pumpAndSettle();
      expect(find.text('correction'), findsOneWidget);
      expect(find.text('role request'), findsNothing);
    });

    testWidgets('a stay owner keeps Change role and it opens the role request', (t) async {
      final a = Get.put<AuthController>(_Quiet());
      a.roleKey.value = UserRoleKeys.stayOwner;
      a.user.value = _user(canCorrect: false, role: UserRoleKeys.stayOwner);
      await openMenu(t, isDraft: false);
      await t.tap(find.text('Change role'));
      await t.pumpAndSettle();
      expect(find.text('role request'), findsOneWidget);
    });

    testWidgets('a draft owner allowed to correct keeps the one-time correction', (t) async {
      final a = Get.put<AuthController>(_Quiet());
      a.roleKey.value = UserRoleKeys.taxiDriver;
      a.user.value = _user(canCorrect: true, role: UserRoleKeys.taxiDriver);
      await openMenu(t, isDraft: true);
      await t.tap(find.text('Change role'));
      await t.pumpAndSettle();
      expect(find.text('correction'), findsOneWidget);
    });
  });
}
