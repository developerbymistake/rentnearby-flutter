import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/social/a/profile/seeker_profile_screen.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';

final _pages = [
  GetPage(name: AppRoutes.people, page: () => Scaffold(body: Text('PEOPLE ${(Get.arguments as Map)['tab']}'))),
  GetPage(name: AppRoutes.settings, page: () => const Scaffold(body: Text('SETTINGS'))),
  GetPage(name: AppRoutes.editProfile, page: () => const Scaffold(body: Text('EDIT'))),
];

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(Get.reset);
  tearDown(Get.reset);

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('my profile shows identity, counters, About and the chips ($size, $scale)', (t) async {
        final server = installServer();
        server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
        putSeeker();
        Get.put(SocialMeController(), permanent: true);
        await pumpSocial(t, const SeekerProfileScreen(), size: size, textScale: scale, pages: _pages);
        expect(find.text('Rahul Verma'), findsOneWidget);
        expect(find.text('Bakhli#${'me'.hashCode.abs()}'), findsOneWidget);
        expect(find.text('Dehradun'), findsOneWidget);
        expect(find.text('128'), findsOneWidget);
        expect(find.text('41'), findsOneWidget);
        expect(find.text(SocialStringsA.editProfileBtn), findsOneWidget);
        expect(find.text('Hills over beaches. Chai at every stop.'), findsOneWidget);
        expect(find.text('Photography'), findsOneWidget);
        expect(find.text('Manali'), findsOneWidget);
        expect(find.text('Driver'), findsOneWidget);
        expect(find.text('9897012345'), findsNothing);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('counters open People, the gear opens Settings, Edit Profile opens the editor', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
    putSeeker();
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const SeekerProfileScreen(), pages: _pages);
    await t.tap(find.text(SocialStringsA.followers));
    await settle(t);
    expect(find.text('PEOPLE followers'), findsOneWidget);
    Get.back();
    await settle(t);
    await t.tap(find.byKey(SeekerProfileScreen.settingsKey));
    await settle(t);
    expect(find.text('SETTINGS'), findsOneWidget);
    Get.back();
    await settle(t);
    await t.tap(find.byKey(SeekerProfileScreen.editKey));
    await settle(t);
    expect(find.text('EDIT'), findsOneWidget);
    await drain(t);
  });

  testWidgets('a load failure shows Retry', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', null, status: 500);
    putSeeker();
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const SeekerProfileScreen(), pages: _pages);
    expect(find.text(SocialStringsA.profileLoadFailed), findsOneWidget);
    await drain(t);
  });

  testWidgets('an owner shell keeps the old ProfileScreen', (t) async {
    installServer();
    putSeeker(role: UserRoleKeys.stayOwner);
    Get.put(PlanController()).myPlan.value = MyPlanModel(paymentEnabled: false);
    await pumpSocial(t, const SeekerProfileScreen(), pages: _pages);
    expect(find.byType(ProfileScreen), findsOneWidget);
    await drain(t);
  });
}
