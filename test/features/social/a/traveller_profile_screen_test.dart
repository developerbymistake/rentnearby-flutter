import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/social/a/people/discover/discover_card.dart';
import 'package:bakhli/features/social/a/people/discover/discover_rail.dart';
import 'package:bakhli/features/social/a/profile/profile_sections.dart';
import 'package:bakhli/features/social/a/profile/traveller_profile_screen.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/a/widgets/social_section_card.dart';
import 'package:bakhli/features/social/b/post/join_request_sheet.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/shared/social_error_types.dart';
import 'package:bakhli/features/social/shared/social_live.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:bakhli/features/social/shared/widgets/follow_button.dart';
import 'package:bakhli/features/social/shared/widgets/follow_limit_sheet.dart';
import 'package:bakhli/features/social/shared/widgets/trip_join_card.dart';
import 'package:bakhli/features/trip/widgets/trip_plan_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../b/social_b_test_kit.dart';
import '../shared/social_test_support.dart';

final _pages = [
  GetPage(name: AppRoutes.dmRoom, page: () => Scaffold(body: Text('DM ${(Get.arguments as Map)['userId']}'))),
  GetPage(name: AppRoutes.people, page: () => Scaffold(body: Text('PEOPLE ${(Get.arguments as Map)['tab']}'))),
];

const _path = '/social/travellers/kavya';
const _similar = '/social/discover/similar/kavya';

Map<String, dynamic> _suggest(String id, String name, Map<String, dynamic> reason) =>
    {...personJson(id, name), 'followsMe': false, 'iFollow': false, 'followRequested': false, 'isPrivate': false, 'reason': reason};

Map<String, dynamic> _similarItems() => {
      'items': [
        _suggest('mehak', 'Mehak Rao', {'kind': 'sameTrip', 'cityName': 'Manali'}),
        _suggest('priya', 'Priya Nair', {'kind': 'mutual', 'mutualCount': 1}),
      ],
    };

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
      testWidgets('a public traveller: Follow + Message, mutuals line, About ($size, $scale)', (t) async {
        final server = installServer();
        server.on('GET', _path, travellerJson());
        await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), size: size, textScale: scale, pages: _pages);
        expect(find.text('Kavya Sharma'), findsOneWidget);
        expect(find.text('Kavya S.'), findsNothing);
        expect(find.text(SocialStrings.follow), findsOneWidget);
        expect(find.text(SocialStrings.message), findsOneWidget);
        expect(find.text('Followed by Aman and 3 others you know'), findsOneWidget);
        expect(find.text('Mountains, chai and long walks.'), findsOneWidget);
        expect(find.byKey(TravellerProfileScreen.buddyKey), findsNothing);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('a clear top bar: round back + menu over the page, no gradient band, Follow back kept', (t) async {
    final server = installServer();
    server.on('GET', _path, travellerJson(followsMe: true));
    await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
    final bar = find.byKey(TravellerProfileScreen.topBarKey);
    expect(bar, findsOneWidget);
    expect(find.descendant(of: bar, matching: find.byKey(TravellerProfileScreen.backKey)), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.byKey(TravellerProfileScreen.menuKey)), findsOneWidget);
    expect(find.byType(TripFlowHeader), findsNothing);
    expect(find.text(SocialStrings.followBack), findsOneWidget);
    await drain(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('the buddy star shows only when they follow me, and toggles with PUT then DELETE', (t) async {
    final server = installServer();
    server.on('GET', _path, travellerJson(followsMe: true, iFollow: true));
    server.on('PUT', '/social/buddies/kavya', {'isBuddy': true});
    server.on('DELETE', '/buddies/kavya', {});
    await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
    expect(find.text(SocialStrings.followEachOther), findsOneWidget);
    expect(find.text(SocialStrings.addToBuddies), findsOneWidget);
    await t.tap(find.byKey(TravellerProfileScreen.buddyKey));
    await settle(t);
    expect(server.calls('PUT', '/social/buddies/kavya'), hasLength(1));
    expect(find.text(SocialStrings.buddy), findsNWidgets(2));
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    await drain(t);
    await t.tap(find.byKey(TravellerProfileScreen.buddyKey));
    await settle(t);
    expect(server.calls('DELETE', '/buddies/kavya'), hasLength(1));
    expect(find.text(SocialStrings.addToBuddies), findsOneWidget);
    await drain(t);
  });

  testWidgets('NotFollower refusal rolls the star back', (t) async {
    final server = installServer();
    server.on('GET', _path, travellerJson(followsMe: true));
    server.refuse('PUT', '/social/buddies/kavya', status: 409, type: 'NotFollower', message: 'You can add only people who follow you.');
    await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
    await t.tap(find.byKey(TravellerProfileScreen.buddyKey));
    await settle(t);
    expect(find.text(SocialStrings.addToBuddies), findsOneWidget);
    await drain(t);
  });

  testWidgets('follow on a private profile turns into Requested', (t) async {
    final server = installServer();
    server.on('GET', _path, travellerJson(privateLocked: true, mutualCount: 0));
    server.on('PUT', '$_path/follow', {'state': 'requested'});
    await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
    expect(find.textContaining(SocialStringsA.privateTitle), findsOneWidget);
    expect(find.text('Mountains, chai and long walks.'), findsNothing);
    await t.tap(find.text(SocialStrings.follow));
    await settle(t);
    expect(find.text(SocialStrings.requested), findsOneWidget);
    await drain(t);
  });

  testWidgets('Message opens the direct chat route', (t) async {
    final server = installServer();
    server.on('GET', _path, travellerJson());
    await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
    await t.tap(find.byKey(TravellerProfileScreen.messageKey));
    await settle(t);
    expect(find.text('DM kavya'), findsOneWidget);
    await drain(t);
  });

  testWidgets('an unknown or blocked person shows the not-found state', (t) async {
    final server = installServer();
    server.refuse('GET', _path, status: 404, type: 'PersonNotFound');
    await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
    expect(find.text(SocialStringsA.travellerGone), findsOneWidget);
    expect(find.byKey(TravellerProfileScreen.menuKey), findsNothing);
    await drain(t);
  });

  testWidgets('same layout as my profile: About in the header card, section cards below Follow / Message', (t) async {
    final server = installServer();
    server.on('GET', _path, travellerJson());
    await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), size: const Size(392, 2400), pages: _pages);
    final about = find.descendant(of: find.byType(ProfileHeroCard), matching: find.byKey(ProfileHeroCard.aboutKey));
    expect(about, findsOneWidget);
    expect(t.getRect(about).bottom, lessThanOrEqualTo(t.getRect(find.byType(ProfileCounters)).top));
    final keys = [ProfileChipsSection.interestsKey, ProfileChipsSection.placesKey, ProfileChipsSection.skillsKey];
    for (final k in keys) {
      expect(find.descendant(of: find.byKey(k), matching: find.byType(SocialSectionHeader)), findsOneWidget);
    }
    // Visible card box (the keyed Container's rect also covers its top margin).
    final firstCard = find.descendant(of: find.byKey(keys.first), matching: find.byType(DecoratedBox)).first;
    expect(t.getRect(find.byKey(TravellerProfileScreen.messageKey)).bottom, lessThan(t.getRect(firstCard).top));
    await drain(t);
  });

  testWidgets('a private locked profile shows no About in the header and no section cards', (t) async {
    final server = installServer();
    server.on('GET', _path, travellerJson(privateLocked: true, mutualCount: 0));
    await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
    expect(find.byKey(ProfileHeroCard.aboutKey), findsNothing);
    expect(find.byType(SocialSectionCard), findsNothing);
    await drain(t);
  });
  group('B2 Similar travellers', () {
    testWidgets('an accepted follow opens the strip under the buttons, loaded once with limit 5', (t) async {
      final server = installServer();
      server.on('GET', _path, travellerJson(mutualCount: 0));
      server.on('PUT', '$_path/follow', {'state': 'following'});
      server.on('GET', _similar, _similarItems());
      await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), size: const Size(392, 2400), pages: _pages);
      expect(find.byKey(TravellerProfileScreen.similarKey), findsNothing);
      await t.tap(find.text(SocialStrings.follow));
      await settle(t);
      final strip = find.byKey(TravellerProfileScreen.similarKey);
      expect(strip, findsOneWidget);
      expect(find.text(SocialStringsA.youFollowLine('Kavya', 'Female')), findsOneWidget);
      expect(find.text(SocialStringsA.similarTravellers), findsOneWidget);
      expect(find.text('Also Manali'), findsOneWidget);
      expect(find.text('Kavya follows'), findsOneWidget);
      // The keyed Column starts at the buttons' bottom; its first visible box sits below its top margin.
      final line = find.text(SocialStringsA.youFollowLine('Kavya', 'Female'));
      expect(t.getTopLeft(line).dy, greaterThan(t.getRect(find.byKey(TravellerProfileScreen.messageKey)).bottom));
      final calls = server.calls('GET', _similar);
      expect(calls, hasLength(1));
      expect(calls.single.queryParameters['limit'], 5);
      await t.tap(find.byKey(DiscoverRail.seeAllKey));
      await settle(t);
      expect(find.text('PEOPLE discover'), findsOneWidget);
      await drain(t);
    });

    testWidgets('unfollow closes the strip', (t) async {
      final server = installServer();
      server.on('GET', _path, travellerJson(mutualCount: 0));
      server.on('PUT', '$_path/follow', {'state': 'following'});
      server.on('DELETE', '$_path/follow', {});
      server.on('GET', _similar, _similarItems());
      await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), size: const Size(392, 2400), pages: _pages);
      await t.tap(find.text(SocialStrings.follow));
      await settle(t);
      expect(find.byKey(TravellerProfileScreen.similarKey), findsOneWidget);
      await t.tap(find.byType(FollowButton).first);
      await settle(t);
      expect(server.calls('DELETE', '$_path/follow'), hasLength(1));
      expect(find.byKey(TravellerProfileScreen.similarKey), findsNothing);
      await drain(t);
    });

    testWidgets('hidden on Requested: no similar call for a private profile', (t) async {
      final server = installServer();
      server.on('GET', _path, travellerJson(privateLocked: true, mutualCount: 0));
      server.on('PUT', '$_path/follow', {'state': 'requested'});
      server.on('GET', _similar, _similarItems());
      await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
      await t.tap(find.text(SocialStrings.follow));
      await settle(t);
      expect(find.text(SocialStrings.requested), findsOneWidget);
      expect(find.byKey(TravellerProfileScreen.similarKey), findsNothing);
      expect(server.calls('GET', _similar), isEmpty);
      await drain(t);
    });

    testWidgets('hidden when the similar list is empty', (t) async {
      final server = installServer();
      server.on('GET', _path, travellerJson(mutualCount: 0));
      server.on('PUT', '$_path/follow', {'state': 'following'});
      server.on('GET', _similar, {'items': []});
      await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
      await t.tap(find.text(SocialStrings.follow));
      await settle(t);
      expect(find.byKey(TravellerProfileScreen.similarKey), findsNothing);
      await drain(t);
    });

    testWidgets('a refused follow (limit or block) makes no similar call and shows no strip', (t) async {
      final server = installServer();
      server.on('GET', _path, travellerJson(mutualCount: 0));
      server.refuse('PUT', '$_path/follow', status: 429, type: 'TryLater');
      server.on('GET', _similar, _similarItems());
      await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), size: const Size(392, 2400), pages: _pages);
      await t.tap(find.text(SocialStrings.follow));
      await settle(t);
      expect(server.calls('PUT', '$_path/follow'), hasLength(1));
      expect(server.calls('GET', _similar), isEmpty);
      expect(find.byKey(TravellerProfileScreen.similarKey), findsNothing);
      expect(find.text(SocialStrings.follow), findsOneWidget);
      await t.tap(find.byKey(FollowLimitSheet.okKey));
      await settle(t);
      await drain(t);
    });

    testWidgets('a follow made on another screen flips the card in the strip', (t) async {
      final server = installServer();
      server.on('GET', _path, travellerJson(mutualCount: 0));
      server.on('PUT', '$_path/follow', {'state': 'following'});
      server.on('GET', _similar, _similarItems());
      await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), size: const Size(392, 2400), pages: _pages);
      await t.tap(find.text(SocialStrings.follow));
      await settle(t);
      final mehak = find.byKey(DiscoverCard.keyOf('mehak'));
      expect(find.descendant(of: mehak, matching: find.text(SocialStrings.follow)), findsOneWidget);
      SocialLive.followChange.trigger(('mehak', true, false));
      await settle(t);
      expect(find.descendant(of: mehak, matching: find.text(SocialStrings.following)), findsOneWidget);
      await drain(t);
    });

    testWidgets('no strip and no call when the profile opens already followed', (t) async {
      final server = installServer();
      server.on('GET', _path, travellerJson(iFollow: true, mutualCount: 0));
      server.on('GET', _similar, _similarItems());
      await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
      expect(find.byKey(TravellerProfileScreen.similarKey), findsNothing);
      expect(server.calls('GET', _similar), isEmpty);
      await drain(t);
    });
  });

  group('Public trips use the join card', () {
    Widget section(List<PublicTrip> trips) => Scaffold(body: SingleChildScrollView(child: ProfileTripsSection(title: 'Public trips · 1', trips: trips)));

    testWidgets('no poster row, Join turns into Requested after sending', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('POST', '/social/trips/trip-1/join-requests', {'id': 'jr-1', 'status': 'Waiting'});
      await pumpSocial(t, section([PublicTrip.fromJson(publicTripJson())]), pages: _pages);
      expect(find.byType(TripJoinCard), findsOneWidget);
      expect(find.text('Kavya S.'), findsNothing);
      expect(find.byKey(TripJoinCard.followKey), findsNothing);
      expect(find.text(SocialStringsB.join), findsOneWidget);
      await t.tap(find.byKey(TripJoinCard.actionKey('trip-1')));
      await settle(t);
      await t.tap(find.byKey(JoinRequestSheet.sendKey));
      await settle(t);
      expect(find.text(SocialStringsB.requested), findsOneWidget);
      await drain(t);
    });

    testWidgets('a refused request for a full post shows Full', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.refuse('POST', '/social/trips/trip-1/join-requests', status: 409, type: SocialErrorTypes.tripRequestsFull);
      await pumpSocial(t, section([PublicTrip.fromJson(publicTripJson())]), pages: _pages);
      await t.tap(find.byKey(TripJoinCard.actionKey('trip-1')));
      await settle(t);
      await t.tap(find.byKey(JoinRequestSheet.sendKey));
      await settle(t);
      expect(find.byKey(TripJoinCard.fullKey), findsOneWidget);
      await drain(t);
    });

    testWidgets('an empty list shows nothing', (t) async {
      installServer();
      await pumpSocial(t, section(const []), pages: _pages);
      expect(find.byType(TripJoinCard), findsNothing);
      expect(find.text('Public trips · 1'), findsNothing);
    });
  });
}
