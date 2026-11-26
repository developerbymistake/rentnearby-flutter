import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/buddy/buddies/widgets/block_dialog.dart';
import 'package:bakhli/features/buddy/shared/widgets/segment_tabs.dart';
import 'package:bakhli/features/social/b/models/join_gender_rule.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/b/widgets/find_buddies_post_card.dart';
import 'package:bakhli/features/social/b/widgets/social_widgets_b.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

final _pages = [
  GetPage(name: AppRoutes.postTrip, page: () => const Scaffold(body: Text('WIZARD'))),
];

Widget _host(FindBuddiesPostPlace place) => Scaffold(body: SingleChildScrollView(child: FindBuddiesPostCard(place: place)));

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
  });
  tearDown(Get.reset);

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('Home card: hero-banner look, Going somewhere? / Post your trip / line, Post opens the wizard ($size, $scale)', (t) async {
        final server = installServer();
        putSocialMe(server, socialMeWith());
        await pumpSocial(t, _host(FindBuddiesPostPlace.home), size: size, textScale: scale, pages: _pages);
        expect(find.byKey(FindBuddiesPostCard.homeKey), findsOneWidget);
        expect(find.byType(WorkoutCard), findsOneWidget);
        expect(identical(t.widget<WorkoutCard>(find.byType(WorkoutCard)).tone, ListingTone.coral), isTrue);
        expect(t.widget<WorkoutCard>(find.byType(WorkoutCard)).actionLabel, 'Post');
        expect(find.text('Going somewhere?'), findsOneWidget);
        expect(find.text('Post your trip'), findsOneWidget);
        expect(find.text('Travellers can ask to join you.'), findsOneWidget);
        expect(find.textContaining('buddies'), findsNothing);
        final art = t.widget<Art3D>(find.byType(Art3D));
        expect(art.asset, ListingArt.backpack);
        await t.tap(find.byKey(FindBuddiesPostCard.postKey));
        await settle(t);
        expect(find.text('WIZARD'), findsOneWidget);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('My Trips card: Post your trip · Travellers can ask to join you; a tap on the card opens the wizard', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    await pumpSocial(t, _host(FindBuddiesPostPlace.myTrips), pages: _pages);
    expect(find.byKey(FindBuddiesPostCard.myTripsKey), findsOneWidget);
    expect(find.text(SocialStringsB.myTripsPostTitle), findsOneWidget);
    expect(find.text(SocialStringsB.myTripsPostLine), findsOneWidget);
    expect(find.text('Post your trip'), findsOneWidget);
    expect(find.text('Travellers can ask to join you'), findsOneWidget);
    expect(find.textContaining('buddies'), findsNothing);
    expect(t.widget<Art3D>(find.byType(Art3D)).asset, ListingArt.backpack);
    expect(find.text(SocialStringsB.post), findsOneWidget);
    expect(identical(t.widget<GradientPillButton>(find.byKey(FindBuddiesPostCard.postKey)).tone, ListingTone.coral), isTrue);
    final tile = t.widget<Container>(find.ancestor(of: find.byType(Art3D), matching: find.byType(Container)).first);
    expect((tile.decoration! as BoxDecoration).gradient, ListingTone.coral.gradient);
    await t.tap(find.text(SocialStringsB.myTripsPostTitle));
    await settle(t);
    expect(find.text('WIZARD'), findsOneWidget);
    await drain(t);
  });

  testWidgets('public trip cap used: Post opens the Plus limit sheet, not the wizard', (t) async {
    final server = installServer();
    final me = putSocialMe(server, socialMeWith(publicUsed: 1));
    await t.runAsync(me.load);
    expect(me.limits.publicTrips.reached, isTrue);
    await pumpSocial(t, _host(FindBuddiesPostPlace.home), pages: _pages);
    await t.tap(find.byKey(FindBuddiesPostCard.postKey));
    await settle(t);
    expect(find.text('WIZARD'), findsNothing);
    expect(find.byKey(const ValueKey('plus_limit_sheet')), findsOneWidget);
    await drain(t);
  });

  testWidgets('an owner account sees no card', (t) async {
    Get.reset();
    putSeeker(role: UserRoleKeys.stayOwner);
    installServer();
    await pumpSocial(t, _host(FindBuddiesPostPlace.home), pages: _pages);
    expect(find.byKey(FindBuddiesPostCard.homeKey), findsNothing);
    await drain(t);
  });

  test('posting copy never says buddies (spec 23.7 / 24); the Find buddies browse label stays', () {
    expect(SocialStringsB.wizardTitle, 'Post your trip');
    expect(SocialStringsB.postToFindBuddies, 'Post your trip');
    expect(SocialStringsB.feedEmptyBody, 'Post your trip and travellers can ask to join.');
    expect(SocialStringsB.windowNote(2), 'Your post shows “within 2 months”, never a date.');
    expect(SocialStringsB.withinRowSub, 'Travellers see a window');
    expect(SocialStringsB.aboutTitle, 'Tell travellers about it');
    for (final s in [
      SocialStringsB.wizardTitle,
      SocialStringsB.postToFindBuddies,
      SocialStringsB.postToFindBuddiesLine,
      SocialStringsB.feedEmptyBody,
      SocialStringsB.windowNote(2),
      SocialStringsB.withinRowSub,
      SocialStringsB.whenAndHowLong,
      SocialStringsB.aboutTitle,
      SocialStringsB.homePostEyebrow,
      SocialStringsB.homePostTitle,
      SocialStringsB.homePostLine,
      SocialStringsB.myTripsPostTitle,
      SocialStringsB.myTripsPostLine,
    ]) {
      expect(s.toLowerCase(), isNot(contains('budd')), reason: s);
    }
    expect(SocialStringsB.findBuddies, 'Find buddies');
  });

  test('My Trips puts the card on top, before the shared trips and the list', () {
    final src = File('lib/features/trip/screens/my_trips_screen.dart').readAsStringSync();
    final card = src.indexOf('FindBuddiesPostCard(place: FindBuddiesPostPlace.myTrips');
    expect(card, greaterThan(src.indexOf('HubHeader(')));
    expect(card, lessThan(src.indexOf('const SharedWithMeSection()')));
    expect(card, lessThan(src.indexOf('_buildBody(context),')));
  });

  test('the trip menu row Post your trip carries the same 3D backpack as the other Post your trip entries and the grey second line', () {
    final seam = File('lib/features/buddy/sharing/widgets/owner_overview_seam.dart').readAsStringSync();
    expect(seam, contains('art: ListingArt.backpack'));
    expect(seam, isNot(contains('HubArt.womanRaising')));
    final overview = File('lib/features/trip/screens/trip_overview_screen.dart').readAsStringSync();
    expect(overview, contains('Art3D(asset: extraMenuItems[i].art!'));
  });

  group('JoinGenderRule (spec 22): the server notOpen flag on a gender-limited post', () {
    PublicTrip trip(String g, {bool notOpen = true, bool mine = false, bool sample = false}) =>
        PublicTrip.fromJson(publicTripJson(joinGender: g, notOpen: notOpen, isMine: mine, sample: sample));

    test('Women only / Men only with notOpen block; without the flag they do not', () {
      expect(JoinGenderRule.blocks(trip('F')), isTrue);
      expect(JoinGenderRule.blocks(trip('M')), isTrue);
      expect(JoinGenderRule.blocks(trip('F', notOpen: false)), isFalse);
      expect(JoinGenderRule.blocks(trip('M', notOpen: false)), isFalse);
    });

    test('Anyone, my own post and sample cards never block', () {
      expect(JoinGenderRule.blocks(trip('A')), isFalse);
      expect(JoinGenderRule.blocks(trip('F', mine: true)), isFalse);
      expect(JoinGenderRule.blocks(trip('F', sample: true)), isFalse);
    });

    test('copy for the disabled line and the 3-option control', () {
      expect(SocialStringsB.onlyFor('F'), 'This trip is for women only');
      expect(SocialStringsB.onlyFor('M'), 'This trip is for men only');
      expect(SocialStringsB.joinLabels, ['Anyone', 'Men', 'Women']);
      expect(SocialStringsB.joinCodes[SocialStringsB.womenIndex], 'F');
      expect(SocialStringsB.genderLockTitle, 'Women-only trips are a Plus feature.');
    });
  });

  testWidgets('SegmentTabs lock slot: a lock only on the locked segment, no lock by default', (t) async {
    await pumpSocial(
      t,
      Scaffold(
        body: Column(children: [
          SegmentTabs(key: const ValueKey('locked'), labels: const ['Anyone', 'Men', 'Women'], selected: 0, tone: ListingTone.indigo, locked: const {2}, onTap: (_) {}),
          SegmentTabs(key: const ValueKey('plain'), labels: const ['1', '2'], selected: 0, tone: ListingTone.indigo, onTap: (_) {}),
        ]),
      ),
    );
    expect(find.descendant(of: find.byKey(const ValueKey('locked')), matching: find.byIcon(Icons.lock_rounded)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('plain')), matching: find.byIcon(Icons.lock_rounded)), findsNothing);
    expect(find.bySemanticsLabel('Women, Plus'), findsOneWidget);
  });

  testWidgets('TickRow hint slot: the label stays bold, (optional) is grey regular; no hint keeps one plain text', (t) async {
    await pumpSocial(
      t,
      Scaffold(
        body: Column(children: [
          TickRow(key: const ValueKey('hint'), label: 'Also add to My Buddies', hint: '(optional)', checked: false, onTap: () {}),
          TickRow(key: const ValueKey('plain'), label: 'Also block', checked: false, onTap: () {}),
        ]),
      ),
    );
    final rich = t.widget<Text>(find.descendant(of: find.byKey(const ValueKey('hint')), matching: find.byType(Text)));
    final spans = (rich.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.first.text, 'Also add to My Buddies ');
    expect(spans.last.text, '(optional)');
    expect(spans.last.style!.fontWeight, FontWeight.w400);
    expect(spans.last.style!.color, Ink3D.grey);
    expect(spans.first.style!.fontWeight, FontWeight.w600);
    expect(find.text('Also block'), findsOneWidget);
  });

  testWidgets('RadioMark: a ring when off, the gradient check when on', (t) async {
    await pumpSocial(
      t,
      Scaffold(
        body: Column(children: [
          RadioMark(key: const ValueKey('off'), selected: false, tone: ListingTone.indigo),
          RadioMark(key: const ValueKey('on'), selected: true, tone: ListingTone.indigo),
        ]),
      ),
    );
    expect(find.descendant(of: find.byKey(const ValueKey('off')), matching: find.byIcon(Icons.check_rounded)), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('on')), matching: find.byIcon(Icons.check_rounded)), findsOneWidget);
    final off = t.widget<Container>(find.descendant(of: find.byKey(const ValueKey('off')), matching: find.byType(Container)).first);
    expect((off.decoration! as BoxDecoration).border, isNotNull);
  });
}
