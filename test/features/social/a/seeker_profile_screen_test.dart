import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_buddy.dart';
import 'package:bakhli/features/buddy/buddy_strings.dart';
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
  GetPage(name: AppRoutes.myFiledReports, page: () => const Scaffold(body: Text('REPORTS'))),
  GetPage(name: AppRoutes.myTrips, page: () => const Scaffold(body: Text('TRIPS'))),
];

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(Get.reset);
  tearDown(Get.reset);

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('my profile shows identity, counters, About, the username row and no chips ($size, $scale)', (t) async {
        final server = installServer();
        server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
        putSeeker();
        Get.put(SocialMeController(), permanent: true);
        await pumpSocial(t, const SeekerProfileScreen(), size: size, textScale: scale, pages: _pages);
        expect(find.text('Rahul Verma'), findsOneWidget);
        expect(find.text('Bakhli#${'me'.hashCode.abs()}'), findsWidgets);
        expect(find.text('Dehradun'), findsOneWidget);
        expect(find.text('128'), findsOneWidget);
        expect(find.text('41'), findsOneWidget);
        expect(find.text(BuddyStrings.myUsername), findsOneWidget);
        expect(find.text(SocialStringsA.editTitle), findsOneWidget);
        expect(find.text(SocialStringsA.myQr), findsNothing);
        expect(find.text('Hills over beaches. Chai at every stop.'), findsOneWidget);
        expect(find.byType(ProfileChipsSection), findsNothing);
        expect(find.text('Photography'), findsNothing);
        expect(find.text('Manali'), findsNothing);
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

  testWidgets('I-11/18/19 About sits in the header card; the username + Edit profile rows, then Activity, then public trips', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
    putSeeker();
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const SeekerProfileScreen(), size: const Size(392, 2400), pages: _pages);
    final hero = find.byType(ProfileHeroCard);
    final about = find.descendant(of: hero, matching: find.byKey(ProfileHeroCard.aboutKey));
    expect(about, findsOneWidget);
    expect(t.getRect(about).bottom, lessThanOrEqualTo(t.getRect(find.byType(ProfileCounters)).top));
    expect(find.byType(ProfileChipsSection), findsNothing);
    final user = t.getRect(find.byKey(SeekerProfileScreen.usernameKey));
    final edit = t.getRect(find.byKey(SeekerProfileScreen.editKey));
    final activity = t.getRect(find.byKey(SeekerProfileScreen.activityKey));
    expect(user.top, greaterThan(t.getRect(hero).bottom));
    expect(edit.top, greaterThanOrEqualTo(user.bottom - 0.5));
    expect(activity.top, greaterThan(edit.bottom));
    expect(find.descendant(of: find.byKey(SeekerProfileScreen.activityKey), matching: find.text(SocialStringsA.activityLabel)), findsOneWidget);
    expect(find.descendant(of: find.byKey(SeekerProfileScreen.activityKey), matching: find.text(SocialStringsA.myReports)), findsOneWidget);
    expect(find.byType(LabeledRowsSection), findsNWidgets(2));
    expect(find.byType(IconRow3D), findsWidgets);
    await drain(t);
  });

  testWidgets('I-18 My Trips and My Reports in the Activity section open their pages', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
    putSeeker();
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const SeekerProfileScreen(), size: const Size(392, 2400), pages: _pages);
    await t.tap(find.text(SocialStringsA.myTrips));
    await settle(t);
    expect(find.text('TRIPS'), findsOneWidget);
    Get.back();
    await settle(t);
    await t.tap(find.text(SocialStringsA.myReports));
    await settle(t);
    expect(find.text('REPORTS'), findsOneWidget);
    await drain(t);
  });

  testWidgets('I-11 the username row has a QR and a Copy round button', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
    putSeeker();
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const SeekerProfileScreen(), pages: _pages);
    final row = find.byKey(SeekerProfileScreen.usernameKey);
    expect(find.descendant(of: row, matching: find.byKey(SeekerProfileScreen.myQrKey)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.byKey(SeekerProfileScreen.copyKey)), findsOneWidget);
    expect(t.widget<BuddyRoundButton>(find.byKey(SeekerProfileScreen.copyKey)).onTap, isNotNull);
    expect(find.descendant(of: row, matching: find.text('Bakhli#${'me'.hashCode.abs()}')), findsOneWidget);
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
  testWidgets('Q1: the QR button opens the QR sheet with my name and username', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
    putSeeker();
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const SeekerProfileScreen(), pages: _pages);
    expect(find.byKey(SeekerProfileScreen.editKey), findsOneWidget);
    await t.tap(find.byKey(SeekerProfileScreen.myQrKey));
    await settle(t);
    expect(find.text(BuddyStrings.qrTitle), findsOneWidget, reason: 'I-11: the My QR pill is gone; only the sheet title says My QR');
    expect(find.text(BuddyStrings.qrSubtitle), findsOneWidget);
    expect(find.bySemanticsLabel(BuddyStrings.qrLabel), findsOneWidget);
    expect(find.text('Bakhli#${'me'.hashCode.abs()}'), findsWidgets);
    expect(find.text('Rahul Verma'), findsNWidgets(2));
    await drain(t);
  });

  testWidgets('Q1: My QR is off while the username is not there yet', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: {...myProfileJson(), 'username': null}));
    putSeeker();
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const SeekerProfileScreen(), pages: _pages);
    await t.tap(find.byKey(SeekerProfileScreen.myQrKey), warnIfMissed: false);
    await settle(t);
    expect(find.text(BuddyStrings.qrSubtitle), findsNothing);
    expect(t.widget<BuddyRoundButton>(find.byKey(SeekerProfileScreen.copyKey)).onTap, isNull);
    await drain(t);
  });
}
