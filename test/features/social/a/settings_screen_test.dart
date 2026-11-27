import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/features/buddy/buddies/controllers/buddy_summary_controller.dart';
import 'package:bakhli/features/social/a/settings/settings_screen.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/social/shared/social_safety_strings.dart';
import 'package:bakhli/features/social/shared/widgets/safety_guidelines_sheet.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';

final _pages = [
  GetPage(name: AppRoutes.seekerPlus, page: () => Scaffold(body: Text('PLUS ${(Get.arguments as Map)['from']}'))),
  GetPage(name: AppRoutes.buddiesBlocked, page: () => const Scaffold(body: Text('BLOCKED'))),
];

const _rows = [
  SocialStringsA.plus,
  SocialStringsA.privateProfile,
  SocialStringsA.whoCanMessage,
  SocialStringsA.blockedPeople,
  SocialStringsA.notifyMessages,
  SocialStringsA.notifyFollows,
  SocialStringsA.notifyTrips,
  SocialStringsA.notifyNearbyTrips,
  SocialStringsA.contactSupport,
  SocialStringsA.rateApp,
  SocialStringsA.shareApp,
  SocialStringsA.privacyPolicy,
  SocialStringsA.terms,
  SocialStringsA.logout,
  SocialStringsA.deleteAccount,
];

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
  });
  tearDown(Get.reset);

  Future<SocialFakeServer> open(WidgetTester t, {double width = 392, double scale = 1.0}) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const SettingsScreen(), size: Size(width, 3400), textScale: scale, pages: _pages);
    return server;
  }

  testWidgets('a verified phone shows the Verified pill; an unverified phone shows Not verified text', (t) async {
    Get.find<AuthController>().profilePhoneVerified.value = true;
    await open(t);
    expect(find.byKey(SettingsScreen.verifiedPillKey), findsOneWidget);
    expect(find.descendant(of: find.byKey(SettingsScreen.verifiedPillKey), matching: find.text(SocialStringsA.verified)), findsOneWidget);
    expect(find.text(SocialStringsA.notVerified), findsNothing);
    Get.find<AuthController>().profilePhoneVerified.value = false;
    await settle(t);
    expect(find.byKey(SettingsScreen.verifiedPillKey), findsNothing);
    expect(find.text(SocialStringsA.notVerified), findsOneWidget);
    await drain(t);
  });

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('every moved row is present, own phone only here ($size, $scale)', (t) async {
        await open(t, width: size.width, scale: scale);
        for (final r in _rows) {
          expect(find.text(r), findsWidgets, reason: r);
        }
        expect(find.text('+91 98xxxxxx45'), findsOneWidget);
        expect(find.text('+91 9897012345'), findsNothing);
        expect(find.text(SocialStringsA.free), findsOneWidget);
        expect(find.text(SocialStringsA.everyone), findsOneWidget);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('R1: a traveller (Seeker) has no Change role or Current role row in Settings', (t) async {
    await open(t);
    expect(find.text('Change role'), findsNothing);
    expect(find.text('Current role'), findsNothing);
    expect(find.textContaining('Now: '), findsNothing);
    await drain(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('private profile switch sends PUT /social/me/privacy', (t) async {
    final server = await open(t);
    server.on('PUT', '/social/me/privacy', myProfileJson(isPrivate: true));
    await t.tap(find.byKey(SettingsScreen.privateKey));
    await settle(t);
    expect((server.calls('PUT', '/social/me/privacy').single.data as Map), {'isPrivate': true});
    expect(SocialMeController.to.profile!.isPrivate, isTrue);
    await drain(t);
  });

  testWidgets('who can message me sheet saves the picked policy', (t) async {
    final server = await open(t);
    server.on('PUT', '/social/me/privacy', myProfileJson(policy: 'Buddies'));
    await t.tap(find.byKey(SettingsScreen.policyKey));
    await settle(t);
    expect(find.text(SocialStringsA.whoCanMessageLine), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('policy_Buddies')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('policy_save')));
    await settle(t);
    expect((server.calls('PUT', '/social/me/privacy').single.data as Map), {'messagePolicy': 'Buddies'});
    expect(find.text(SocialStringsA.buddiesOnly), findsOneWidget);
    await drain(t);
  });

  testWidgets('I-18 the Activity section moved to the profile: no My Trips, Jobs, My Journeys or My Reports here', (t) async {
    await open(t);
    for (final r in [SocialStringsA.activityLabel, SocialStringsA.myTrips, SocialStringsA.jobs, SocialStringsA.myJourneys, SocialStringsA.myReports]) {
      expect(find.text(r), findsNothing, reason: r);
    }
    await drain(t);
  });

  testWidgets('Plus and Blocked people rows are wired', (t) async {
    await open(t);
    await t.tap(find.byKey(SettingsScreen.plusKey));
    await settle(t);
    expect(find.text('PLUS settings'), findsOneWidget);
    Get.back();
    await settle(t);
    await t.tap(find.byKey(SettingsScreen.blockedKey));
    await settle(t);
    expect(find.text('BLOCKED'), findsOneWidget);
    await drain(t);
  });

  testWidgets('profile load failed: Blocked people stays, Retry brings the privacy rows back', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', {'error': {'type': 'Server', 'message': 'Down'}}, status: 500);
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const SettingsScreen(), size: const Size(392, 3400), pages: _pages);
    await settle(t);
    expect(find.byKey(SettingsScreen.profileErrorKey), findsOneWidget);
    expect(find.byKey(SettingsScreen.blockedKey), findsOneWidget);
    expect(find.byKey(SettingsScreen.privateKey), findsNothing);
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
    await t.tap(find.text(SocialStrings.retry));
    await settle(t);
    expect(find.byKey(SettingsScreen.profileErrorKey), findsNothing);
    expect(find.byKey(SettingsScreen.privateKey), findsOneWidget);
    expect(find.text(SocialStringsA.notifyMessages), findsOneWidget);
    await drain(t);
  });

  testWidgets('Blocked people shows the blocked count from the buddy summary', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
    server.on('GET', '/buddies/summary', {'buddies': 6, 'newBuddies': 0, 'receivedPending': 0, 'blocked': 2});
    Get.put(SocialMeController(), permanent: true);
    Get.put(BuddySummaryController(), permanent: true);
    await pumpSocial(t, const SettingsScreen(), size: const Size(392, 3400), pages: _pages);
    expect(find.text(SocialStringsA.blockedCount(2)), findsOneWidget);
    await drain(t);
  });

  testWidgets('no blocked people: no count line', (t) async {
    await open(t);
    expect(find.text(SocialStringsA.blockedCount(0)), findsNothing);
    await drain(t);
  });

  testWidgets('Safety tips row opens the read-only rows with only Close', (t) async {
    await open(t);
    expect(find.text(SocialSafetyStrings.tipsRow), findsOneWidget);
    await t.tap(find.byKey(SettingsScreen.safetyKey));
    await settle(t);
    expect(find.byKey(SafetyGuidelinesSheet.rowsKey), findsOneWidget);
    expect(find.text(SocialSafetyStrings.moneyTitle), findsOneWidget);
    expect(find.byKey(SafetyGuidelinesSheet.understoodKey), findsNothing);
    await t.tap(find.byKey(SafetyGuidelinesSheet.closeKey));
    await settle(t);
    expect(find.byKey(SafetyGuidelinesSheet.rowsKey), findsNothing);
    await drain(t);
  });

  testWidgets('a refused private switch shows the error and the switch stays at the saved value', (t) async {
    final server = await open(t);
    server.refuse('PUT', '/social/me/privacy', status: 400, type: 'InvalidProfile', message: 'Could not save.');
    await t.tap(find.byKey(SettingsScreen.privateKey));
    await settle(t);
    expect(find.text('Could not save.'), findsOneWidget);
    expect(SocialMeController.to.profile!.isPrivate, isFalse);
    expect(t.widget<Switch3D>(find.byKey(SettingsScreen.privateKey)).value, isFalse);
    await drain(t);
  });

  testWidgets('a server error on save keeps the saved state', (t) async {
    final server = await open(t);
    server.on('PUT', '/social/me/privacy', {'error': {'type': 'Server', 'message': 'Down'}}, status: 500);
    await t.tap(find.byKey(SettingsScreen.privateKey));
    await settle(t);
    expect(SocialMeController.to.profile!.isPrivate, isFalse);
    expect(t.widget<Switch3D>(find.byKey(SettingsScreen.privateKey)).value, isFalse);
    await drain(t);
  });

  for (final c in [
    ('notifyMessages', SocialStringsA.notifyMessages),
    ('notifyFollows', SocialStringsA.notifyFollows),
    ('notifyFollowedTrips', SocialStringsA.notifyTrips),
    ('notifyNearbyTrips', SocialStringsA.notifyNearbyTrips),
  ]) {
    testWidgets('notification switch ${c.$1} sends only its key and shows the saved value', (t) async {
      final server = await open(t);
      final saved = {...myProfileJson(), c.$1: false};
      server.on('PUT', '/social/me/privacy', saved);
      final row = find.ancestor(of: find.text(c.$2), matching: find.byType(IconRow3D)).first;
      await t.tap(find.descendant(of: row, matching: find.byType(Switch3D)));
      await settle(t);
      expect((server.calls('PUT', '/social/me/privacy').single.data as Map), {c.$1: false});
      expect(t.widget<Switch3D>(find.descendant(of: row, matching: find.byType(Switch3D))).value, isFalse);
      await drain(t);
    });
  }

  testWidgets('UC21 Trips of people I follow and Trips near me show the server state after a reload', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: {...myProfileJson(), 'notifyFollowedTrips': false, 'notifyNearbyTrips': false}));
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const SettingsScreen(), size: const Size(392, 3400), pages: _pages);
    await settle(t);
    Switch3D rowSwitch(String title) =>
        t.widget<Switch3D>(find.descendant(of: find.ancestor(of: find.text(title), matching: find.byType(IconRow3D)).first, matching: find.byType(Switch3D)));
    expect(rowSwitch(SocialStringsA.notifyTrips).value, isFalse);
    expect(t.widget<Switch3D>(find.byKey(SettingsScreen.nearbyKey)).value, isFalse);
    await t.pumpWidget(const SizedBox.shrink());
    server.on('GET', '/social/me', socialMeJson(profile: {...myProfileJson(), 'notifyFollowedTrips': true, 'notifyNearbyTrips': true}));
    await pumpSocial(t, const SettingsScreen(), size: const Size(392, 3400), pages: _pages);
    await settle(t);
    expect(rowSwitch(SocialStringsA.notifyTrips).value, isTrue);
    expect(t.widget<Switch3D>(find.byKey(SettingsScreen.nearbyKey)).value, isTrue);
    await drain(t);
  });

  test('UC21 copy: Trips of people I follow, Trips near me', () {
    expect(SocialStringsA.notifyTrips, 'Trips of people I follow');
    expect(SocialStringsA.notifyNearbyTrips, 'Trips near me');
  });

  testWidgets('a refused policy save keeps the old policy and shows the error', (t) async {
    final server = await open(t);
    server.refuse('PUT', '/social/me/privacy', status: 400, type: 'InvalidProfile', message: 'Could not save.');
    await t.tap(find.byKey(SettingsScreen.policyKey));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('policy_Buddies')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('policy_save')));
    await settle(t);
    expect(find.text('Could not save.'), findsOneWidget);
    expect(SocialMeController.to.profile!.messagePolicy, 'Everyone');
    expect(find.text(SocialStringsA.everyone), findsOneWidget);
    await drain(t);
  });

  testWidgets('leaving and reopening Settings shows the server state, not a stale copy', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson(isPrivate: true, policy: 'Buddies')));
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const SettingsScreen(), size: const Size(392, 3400), pages: _pages);
    await settle(t);
    expect(t.widget<Switch3D>(find.byKey(SettingsScreen.privateKey)).value, isTrue);
    expect(find.text(SocialStringsA.buddiesOnly), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson(isPrivate: false, policy: 'Following')));
    await pumpSocial(t, const SettingsScreen(), size: const Size(392, 3400), pages: _pages);
    await settle(t);
    expect(t.widget<Switch3D>(find.byKey(SettingsScreen.privateKey)).value, isFalse);
    expect(find.text(SocialStringsA.peopleIFollow), findsOneWidget);
    await drain(t);
  });

  testWidgets('a save that lands while a refresh is in flight is not overwritten by the older answer', (t) async {
    await open(t);
    final me = SocialMeController.to;
    await t.runAsync(() async {
      final f = me.refreshQuiet();
      me.applyProfile(MyProfile.fromJson(myProfileJson(isPrivate: true)));
      await f;
    });
    await settle(t);
    expect(me.profile!.isPrivate, isTrue);
    await drain(t);
  });
}
