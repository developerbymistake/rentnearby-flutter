import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/a/profile/profile_sections.dart';
import 'package:bakhli/features/social/a/profile/seeker_profile_screen.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/a/widgets/social_section_card.dart';
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

  testWidgets('the Profile header shows only the settings gear (no bell, chat or enquiries)', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
    putSeeker();
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const SeekerProfileScreen(), pages: _pages);
    expect(find.byKey(SeekerProfileScreen.settingsKey), findsOneWidget);
    expect(find.bySemanticsLabel('Notifications'), findsNothing);
    expect(find.bySemanticsLabel('Chats'), findsNothing);
    expect(find.bySemanticsLabel('Enquiries'), findsNothing);
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

  testWidgets('About sits inside the header card above the counters; Interests, Places and Skills are separate section cards', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
    putSeeker();
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const SeekerProfileScreen(), size: const Size(392, 2400), pages: _pages);
    final hero = find.byType(ProfileHeroCard);
    final about = find.descendant(of: hero, matching: find.byKey(ProfileHeroCard.aboutKey));
    expect(about, findsOneWidget);
    expect(t.getRect(about).bottom, lessThanOrEqualTo(t.getRect(find.byType(ProfileCounters)).top));
    expect(t.getRect(about).top, greaterThanOrEqualTo(t.getRect(find.text('Dehradun')).bottom));
    final cards = [ProfileChipsSection.interestsKey, ProfileChipsSection.placesKey, ProfileChipsSection.skillsKey];
    for (final k in cards) {
      expect(find.descendant(of: find.byKey(k), matching: find.byType(SocialSectionHeader)), findsOneWidget);
    }
    // Visible card box (the keyed Container's rect also covers its top margin).
    final rects = [for (final k in cards) t.getRect(find.descendant(of: find.byKey(k), matching: find.byType(DecoratedBox)).first)];
    for (final r in rects) {
      expect(r.left, closeTo(rects.first.left, 0.5));
      expect(r.width, closeTo(rects.first.width, 0.5));
    }
    expect(rects[1].top, greaterThan(rects[0].bottom));
    expect(rects[2].top, greaterThan(rects[1].bottom));
    expect(t.getRect(find.byKey(SeekerProfileScreen.editKey)).bottom, lessThan(rects.first.top));
    await drain(t);
  });

  testWidgets('the Profile avatar has no pencil badge and the gear is coral', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
    putSeeker();
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const SeekerProfileScreen(), pages: _pages);
    expect(find.byIcon(Icons.edit_rounded), findsNothing);
    expect(find.bySemanticsLabel(SocialStringsA.changePhoto), findsNothing);
    final gear = t.widget<RoundIconButton3D>(find.descendant(of: find.byKey(SeekerProfileScreen.settingsKey), matching: find.byType(RoundIconButton3D)));
    expect(gear.tint, ListingPalette.coral.g1);
    await drain(t);
  });
}
