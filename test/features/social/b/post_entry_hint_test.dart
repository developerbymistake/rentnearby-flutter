import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/b/feed/travel_buddies_screen.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/b/widgets/find_buddies_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../../buddy/sharing/sharing_fixtures.dart' as sf;
import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

final _pages = [
  GetPage(name: AppRoutes.postTrip, page: () => const Scaffold(body: Text('WIZARD'))),
  GetPage(name: AppRoutes.seekerPlus, page: () => const Scaffold(body: Text('PLUS'))),
];

Widget _host(FindBuddiesPostPlace place) => Scaffold(body: SingleChildScrollView(child: FindBuddiesPostCard(place: place)));

Map<String, dynamic> _capped({bool isPlus = false, bool canUpgrade = true}) {
  final me = socialMeWith(isPlus: isPlus, publicUsed: isPlus ? 3 : 1);
  me['limits'] = {...me['limits'] as Map<String, dynamic>, 'canUpgrade': canUpgrade};
  return me;
}

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
  });
  tearDown(Get.reset);

  for (final place in FindBuddiesPostPlace.values) {
    testWidgets('UC20 ${place.name} card: Free at the cap shows Free limit reached. Get Plus. in place of the line; Post opens the Plus prompt', (t) async {
      final server = installServer();
      final me = putSocialMe(server, _capped());
      await t.runAsync(me.load);
      await pumpSocial(t, _host(place), pages: _pages);
      expect(find.text(SocialStringsB.freeLimitHint), findsOneWidget);
      expect(find.text(SocialStringsB.homePostLine), findsNothing);
      expect(find.text(SocialStringsB.myTripsPostLine), findsNothing);
      await t.tap(find.byKey(FindBuddiesPostCard.postKey));
      await settle(t);
      expect(find.byKey(const ValueKey('plus_limit_sheet')), findsOneWidget);
      expect(find.text('WIZARD'), findsNothing);
      await drain(t);
    });
  }

  testWidgets('UC20 below the cap the cards keep their invitation line', (t) async {
    final server = installServer();
    final me = putSocialMe(server, socialMeWith());
    await t.runAsync(me.load);
    await pumpSocial(t, _host(FindBuddiesPostPlace.home), pages: _pages);
    expect(find.text(SocialStringsB.homePostLine), findsOneWidget);
    expect(find.text(SocialStringsB.freeLimitHint), findsNothing);
    await drain(t);
  });

  testWidgets('UC20 the hint follows the server: a post removed elsewhere brings the invitation back without a rebuild', (t) async {
    final server = installServer();
    final me = putSocialMe(server, _capped());
    await t.runAsync(me.load);
    await pumpSocial(t, _host(FindBuddiesPostPlace.home), pages: _pages);
    expect(find.text(SocialStringsB.freeLimitHint), findsOneWidget);
    server.on('GET', '/social/me', socialMeWith());
    await t.runAsync(me.refreshQuiet);
    await settle(t);
    expect(find.text(SocialStringsB.homePostLine), findsOneWidget);
    await drain(t);
  });

  testWidgets('UC20 payment OFF (cannot upgrade) at the cap: a plain live-post line, never Get Plus', (t) async {
    final server = installServer();
    final me = putSocialMe(server, _capped(canUpgrade: false));
    await t.runAsync(me.load);
    await pumpSocial(t, _host(FindBuddiesPostPlace.home), pages: _pages);
    expect(find.text(SocialStringsB.freeLimitHint), findsNothing);
    expect(find.text(SocialStringsB.liveLimitHint(1)), findsOneWidget);
    await drain(t);
  });

  testWidgets('UC20 a tap before the profile loaded waits for it and still shows the Plus prompt', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', _capped());
    final me = putSocialMe(server, _capped());
    me.me.value = null;
    await pumpSocial(t, _host(FindBuddiesPostPlace.myTrips), pages: _pages);
    me.me.value = null;
    await t.tap(find.byKey(FindBuddiesPostCard.postKey));
    await settle(t);
    expect(find.text('WIZARD'), findsNothing);
    expect(find.byKey(const ValueKey('plus_limit_sheet')), findsOneWidget);
    await drain(t);
  });

  testWidgets('abuse guard: 4 publishes this week used: Post shows the calm line with the day, the wizard does not open', (t) async {
    final server = installServer();
    final base = socialMeWith();
    final me = putSocialMe(server, {
      ...base,
      'limits': {...base['limits'] as Map<String, dynamic>, 'publishes': {'limit': 4, 'used': 4}, 'publishNextAt': '2026-12-01T06:00:00Z'},
    });
    await t.runAsync(me.load);
    await pumpSocial(t, _host(FindBuddiesPostPlace.home), pages: _pages);
    await t.tap(find.byKey(FindBuddiesPostCard.postKey));
    await settle(t);
    expect(find.text('WIZARD'), findsNothing);
    expect(find.textContaining('You have posted a lot this week. Try again on'), findsOneWidget);
    await drain(t);
  });

  testWidgets('UC20 Travel groups sticky Post button shows the same hint line under it', (t) async {
    final server = installServer();
    final me = putSocialMe(server, _capped());
    await t.runAsync(me.load);
    stubGroups(server);
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    expect(find.byKey(TravelBuddiesScreen.postHintKey), findsOneWidget);
    expect(find.text(SocialStringsB.freeLimitHint), findsOneWidget);
    await t.tap(find.byKey(TravelBuddiesScreen.postKey));
    await settle(t);
    expect(find.byKey(const ValueKey('plus_limit_sheet')), findsOneWidget);
    await drain(t);
  });

  testWidgets('UC20 trip overview menu row Post your trip shows the hint as its second line', (t) async {
    final server = installServer();
    final me = putSocialMe(server, _capped());
    await t.runAsync(me.load);
    await pumpSocial(t, sf.overview(sf.trip(sharing: sf.aloneBlock()), sf.aloneBlock()), size: const Size(392, 1600), pages: _pages);
    await t.ensureVisible(find.byKey(const ValueKey('overview_menu')));
    await t.tap(find.byKey(const ValueKey('overview_menu')));
    await settle(t);
    expect(find.text(SocialStringsB.postToFindBuddies), findsOneWidget);
    expect(find.text(SocialStringsB.freeLimitHint), findsOneWidget);
    expect(find.text(SocialStringsB.postToFindBuddiesLine), findsNothing);
    await drain(t);
  });

  test('UC20 every post entry goes through the Plus check (Home, My Trips, feed, overview menu, wizard refusal)', () {
    final card = File('lib/features/social/b/widgets/find_buddies_post_card.dart').readAsStringSync();
    expect('PostTripEntry.open(context)'.allMatches(card).length, greaterThanOrEqualTo(2));
    expect(card, contains('PostTripEntry.hint()'));
    final feed = File('lib/features/social/b/feed/travel_buddies_screen.dart').readAsStringSync();
    expect(feed, contains('PostTripEntry.open(context)'));
    expect(feed, contains('SocialStringsB.postEntryHint(l)'));
    final seam = File('lib/features/buddy/sharing/widgets/owner_overview_seam.dart').readAsStringSync();
    expect(seam, contains('SocialStringsB.postEntryHint('));
    expect(seam, contains('PostTripEntry.open(context, tripId: trip.id)'));
    final wizard = File('lib/features/social/b/wizard/post_trip_screen.dart').readAsStringSync();
    expect(wizard, contains('PlusSheets.limitReached(context, errorType: type!'));
  });

  test('a design token, not a raw colour, styles the hint (the primary colour is changing)', () {
    final feed = File('lib/features/social/b/feed/travel_buddies_screen.dart').readAsStringSync();
    final i = feed.indexOf('TravelBuddiesScreen.postHintKey,');
    expect(feed.substring(i, i + 300), contains('Ink3D.grey'));
    expect(feed, isNot(contains('Color(0x')));
    expect(ListingTone.coral, isNotNull);
  });
}
