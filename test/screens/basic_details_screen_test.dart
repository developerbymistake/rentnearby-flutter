import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/basic_details_strings.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/profile_photo_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_auth.dart';
import 'package:bakhli/design/extra/ext_buddy.dart';
import 'package:bakhli/features/social/a/onboarding/onboarding_steps.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/screens/basic_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/onboarding_walk.dart';
import '../support/owner_fakes.dart';
import '../support/real_phone.dart';

const _phone = '9876543210';
const _username = 'Bakhli#48291736';

// Records every argument so "name only" can be checked; on success the session user is a name-only new account.
class _Auth extends AuthController {
  final calls = <Map<String, Object?>>[];
  bool createOk = true;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<bool> createOnboardingAccount({
    required String phone,
    required String name,
    String? gender,
    int? birthMonth,
    int? birthYear,
    List<String>? interests,
    List<String>? skills,
    List<String>? places,
    String? about,
    String? homeCityName,
    String? homeStateName,
  }) async {
    calls.add({
      'phone': phone,
      'name': name,
      'gender': gender,
      'birthMonth': birthMonth,
      'birthYear': birthYear,
      'interests': interests,
      'skills': skills,
      'places': places,
      'about': about,
      'homeCityName': homeCityName,
      'homeStateName': homeStateName,
    });
    if (!createOk) return false;
    user.value = UserModel(id: 'new', phoneNumber: phone, name: name, username: _username, createdAt: DateTime(2026), roleConfirmed: false, profileCompleted: false);
    return true;
  }
}

late _Auth _auth;

void _setup() {
  Get.testMode = true;
  Get.put<TabConfigController>(FakeTabs());
  _auth = _Auth();
  Get.put<AuthController>(_auth);
  _auth.signupUsername.value = _username;
  Get.put(ProfilePhotoController(pick: (_) async => null, offline: () async => false));
}

final _pages = [
  for (final r in [AppRoutes.roleSelect, AppRoutes.onboarding, AppRoutes.main, AppRoutes.login, AppRoutes.profilePhoto])
    GetPage(name: r, page: () => Scaffold(body: Text('page $r'))),
];

Future<void> _open(WidgetTester t, {Size size = phoneSize, double scale = 1.0}) async {
  await pumpPhone(t, const SizedBox(), size: size, textScale: scale, toastHost: true, pages: _pages);
  Get.to<void>(() => const BasicDetailsScreen(), arguments: {'phone': _phone}, transition: Transition.noTransition, duration: Duration.zero);
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
  await settlePhone(t);
}

Future<void> _tapStart(WidgetTester t) async {
  await t.ensureVisible(OnboardingWalk.finish);
  await t.pump();
  await t.tap(OnboardingWalk.finish, warnIfMissed: false);
  await t.pump();
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> _drain(WidgetTester t) async {
  await t.pump(const Duration(seconds: 5));
  await t.pump(const Duration(seconds: 1));
}

GradientPillButton _button(WidgetTester t) => t.widget<GradientPillButton>(OnboardingWalk.finish);

void main() {
  setUpAll(() async {
    await initTestStorage('basic_details');
    await loadRealFonts();
  });
  tearDown(Get.reset);

  for (final (size, scale) in [(phoneSize, 1.0), (const Size(320, 700), 1.3)]) {
    testWidgets('renders Fill basic details, the subtitle, Get Started, the verified phone and the locked username ($size, $scale)', (t) async {
      _setup();
      await _open(t, size: size, scale: scale);
      expect(find.text(BasicDetailsStrings.title), findsOneWidget);
      expect(find.text(BasicDetailsStrings.subtitle), findsOneWidget);
      expect(find.text(BasicDetailsStrings.button), findsOneWidget);
      expect(find.text(BasicDetailsStrings.fullName), findsOneWidget);
      expect(find.byType(OnboardingStepDots), findsNothing, reason: 'one page, no step dots');
      expect(find.byType(OnboardingPhotoRow), findsOneWidget);
      expect(find.byType(AuthVerifiedRow), findsOneWidget);
      expect(find.text('+91 $_phone'), findsOneWidget);
      expect(find.byType(UsernameLockedPill), findsOneWidget);
      expect(find.text(_username), findsOneWidget);
      expect(find.byKey(OnboardingWalk.basicNameKey), findsOneWidget);
      await _drain(t);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('Get Started is off with an empty or blank name and a tap creates nothing', (t) async {
    _setup();
    await _open(t);
    expect(_button(t).enabled, isFalse);
    await OnboardingWalk.basicName(t, '   ');
    expect(_button(t).enabled, isFalse);
    await _tapStart(t);
    expect(_auth.calls, isEmpty);
    expect(find.text(BasicDetailsStrings.title), findsOneWidget);
    await OnboardingWalk.basicName(t, 'Rahul Mehra');
    expect(_button(t).enabled, isTrue);
    await _drain(t);
  });

  testWidgets('Get Started calls createOnboardingAccount once with the phone and the trimmed name only', (t) async {
    _setup();
    await _open(t);
    await OnboardingWalk.basicName(t, '  Rahul Mehra  ');
    await _tapStart(t);
    expect(_auth.calls, hasLength(1));
    final call = _auth.calls.single;
    expect(call['phone'], _phone);
    expect(call['name'], 'Rahul Mehra');
    for (final k in ['gender', 'birthMonth', 'birthYear', 'interests', 'skills', 'places', 'about', 'homeCityName', 'homeStateName']) {
      expect(call[k], isNull, reason: '$k must not be sent from Fill basic details');
    }
    await _drain(t);
  });

  testWidgets('after the account is made it leaves through postLoginRoute (role select for a new account)', (t) async {
    _setup();
    await _open(t);
    await OnboardingWalk.basicName(t, 'Rahul Mehra');
    await _tapStart(t);
    await t.pumpAndSettle();
    expect(_auth.postLoginRoute, AppRoutes.roleSelect);
    expect(Get.currentRoute, AppRoutes.roleSelect);
    expect(find.text('page ${AppRoutes.roleSelect}'), findsOneWidget);
    expect(find.byType(BasicDetailsScreen), findsNothing);
    await _drain(t);
  });

  testWidgets('a failed create stays on the page', (t) async {
    _setup();
    _auth.createOk = false;
    await _open(t);
    await OnboardingWalk.basicName(t, 'Rahul Mehra');
    await _tapStart(t);
    expect(_auth.calls, hasLength(1));
    expect(find.byType(BasicDetailsScreen), findsOneWidget);
    expect(find.text(BasicDetailsStrings.button), findsOneWidget);
    await _drain(t);
  });

  testWidgets('system back before the account exists goes back to login', (t) async {
    _setup();
    await _open(t);
    await t.binding.handlePopRoute();
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 700));
    expect(find.byType(BasicDetailsScreen), findsNothing);
    expect(find.text('page ${AppRoutes.login}'), findsOneWidget);
    await _drain(t);
  });

  testWidgets('skip after a failed photo drops the failed photo', (t) async {
    _setup();
    final photo = Get.find<ProfilePhotoController>();
    photo.localPath.value = 'missing.jpg';
    photo.failed.value = true;
    photo.discard();
    expect(photo.localPath.value, isNull);
    expect(photo.failed.value, isFalse);
  });
}
