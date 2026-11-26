import 'dart:async';
import 'dart:io';

import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/config/profile_photo_strings.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/profile_photo_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/screens/onboarding_screen.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/onboarding_walk.dart';
import '../support/owner_fakes.dart';
import '../support/real_phone.dart';

// CF-adversarial (profile DP): failing tests for the defects listed in
// F:/Dhasu/Buddy_resume/profile_dp/CONFIRM_CF-adversarial.md (A1, A2).

class _Auth extends AuthController {
  final created = <String>[];

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  String get postLoginRoute => '/done-route';

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
    created.add(name);
    return true;
  }

  @override
  Future<void> refreshProfile() async {}
}

void main() {
  group('A1 admin removal notice refreshes the session user', () {
    String src(String p) => File(p).readAsStringSync();

    test('the notice type has a key in NotificationTypeKeys', () {
      expect(src('lib/config/notification_types.dart'), contains("'profile_photo_removed'"),
          reason: 'server type ProfilePhotoRemoved (wire profile_photo_removed) is unknown to the app');
    });

    test('hub and FCM handlers refresh the profile on the notice, so the gate fires mid-session', () {
      for (final file in ['lib/services/notification_hub_service.dart', 'lib/services/notification_service.dart']) {
        final s = src(file);
        final hit = RegExp(r'profilePhotoRemoved\w*\)?\s*\{?[^}]{0,200}refreshProfile\(\)', dotAll: true).hasMatch(s);
        expect(hit, isTrue, reason: '$file: a ProfilePhotoRemoved push must call AuthController.refreshProfile()');
      }
    });
  });

  group('A2 onboarding double submit', () {
    setUpAll(() async {
      await initTestStorage('cf_adv_dp');
      await loadRealFonts();
    });
    tearDown(Get.reset);

    testWidgets('two taps on Finish while the connectivity check runs create ONE account', (t) async {
      Get.testMode = true;
      Get.put<TabConfigController>(FakeTabs());
      final auth = _Auth();
      Get.put<AuthController>(auth);
      auth.signupUsername.value = 'Bakhli#48291736';

      final dir = Directory.systemTemp.createTempSync('cf_adv_dp');
      final file = File('${dir.path}/face.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
      var offlineCalls = 0;
      final hold = Completer<bool>();
      final sent = <String>[];
      Get.put(ProfilePhotoController(
        pick: (_) async => file,
        send: (path, _) async {
          sent.add(path);
          return {
            'data': {'id': 'u1', 'phoneNumber': '9876543210', 'createdAt': '2026-11-22T10:00:00Z', 'roleConfirmed': true, 'profilePhotoUrl': 'https://x/a.jpg'},
          };
        },
        offline: () {
          offlineCalls++;
          return offlineCalls == 1 ? Future.value(false) : hold.future;
        },
      ));

      t.view.devicePixelRatio = 3;
      t.view.physicalSize = const Size(392 * 3, 2400 * 3);
      addTearDown(t.view.reset);
      await t.pumpWidget(GetMaterialApp(
        theme: AppTheme.theme,
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: Stack(fit: StackFit.expand, children: [Positioned.fill(child: c!), Overlay(key: AppToast.overlayKey)]),
        ),
        initialRoute: '/',
        getPages: [
          GetPage(name: '/', page: () => const SizedBox()),
          GetPage(name: '/done-route', page: () => const Scaffold(body: Text('done page'))),
        ],
      ));
      await t.pump();
      Get.to<void>(() => const OnboardingScreen(), arguments: {'phone': '9876543210'}, transition: Transition.noTransition, duration: Duration.zero);
      await t.pump();
      await t.pump(const Duration(milliseconds: 700));
      await settlePhone(t);

      await t.tap(find.bySemanticsLabel(ProfilePhotoStrings.semProfilePhoto), warnIfMissed: false);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await OnboardingWalk.toFinish(t, name: 'Rahul Mehra');

      await t.tap(find.text(SocialStringsA.finish), warnIfMissed: false);
      await t.pump();
      await t.tap(find.text(SocialStringsA.finish), warnIfMissed: false);
      await t.pump();
      hold.complete(false);
      await t.pump();
      await t.pump(const Duration(seconds: 2));

      expect(auth.created, hasLength(1), reason: 'the second tap passed the guard while online() was pending and sent complete-onboarding again');
      dir.deleteSync(recursive: true);
    });
  });
}
