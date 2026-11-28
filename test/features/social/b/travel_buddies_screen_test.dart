import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/a/people/discover/discover_card.dart';
import 'package:bakhli/features/social/a/people/discover/discover_rail.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/b/feed/travel_buddies_screen.dart';
import 'package:bakhli/features/social/b/post/join_request_sheet.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/shared/social_live.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:bakhli/features/social/shared/widgets/plus_widgets.dart';
import 'package:bakhli/features/social/shared/widgets/public_trip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

final _pages = [
  GetPage(name: AppRoutes.tripPost, page: () => Scaffold(body: Text('POST ${(Get.arguments as Map)['tripId']}'))),
  GetPage(name: AppRoutes.joinRequests, page: () => Scaffold(body: Text('REQUESTS ${(Get.arguments as Map)['tripId']}'))),
  GetPage(name: AppRoutes.postTrip, page: () => const Scaffold(body: Text('WIZARD'))),
  GetPage(name: AppRoutes.people, page: () => Scaffold(body: Text('PEOPLE ${(Get.arguments as Map)['tab']}'))),
];

const _feed = '/social/trips/feed';
const _discover = '/social/discover';

Map<String, dynamic> _suggest(String id, String name, String kind) =>
    {...personJson(id, name), 'followsMe': false, 'iFollow': false, 'followRequested': false, 'isPrivate': false, 'reason': {'kind': kind}};

Map<String, dynamic> _suggestions() => {
      'items': [_suggest('rohit', 'Rohit Rana', 'mutual'), _suggest('sneha', 'Sneha Joshi', 'near')],
      'nextCursor': null,
    };

final _threePosts = _page(items: [
  publicTripJson(id: 'trip-1'),
  publicTripJson(id: 'trip-2', ownerId: 'aman', ownerName: 'Aman Kumar', cities: ['Spiti']),
  publicTripJson(id: 'trip-3', ownerId: 'mehak', ownerName: 'Mehak Rao', cities: ['Manali']),
]);

const _tall = Size(392, 4000);

Map<String, dynamic> _page({List<Map<String, dynamic>> mine = const [], List<Map<String, dynamic>> items = const []}) =>
    {'mine': mine, 'items': items, 'nextCursor': null};

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
      testWidgets('my post sits on top, then posts with Request to join and Requested ($size, $scale)', (t) async {
        final server = installServer();
        putSocialMe(server, socialMeWith());
        server.on('GET', _feed, _page(
          mine: [publicTripJson(id: 'mine-1', ownerId: 'me', ownerName: 'Rahul Verma', cities: ['Manali'], isMine: true, waitingRequests: 0)],
          items: [publicTripJson(id: 'trip-1'), publicTripJson(id: 'trip-2', ownerId: 'aman', ownerName: 'Aman Kumar', cities: ['Spiti'], myJoin: 'requested')],
        ));
        await pumpSocial(t, const TravelBuddiesScreen(), size: size, textScale: scale, pages: _pages);
        expect(find.text(SocialStringsB.travelBuddies), findsOneWidget);
        expect(find.text(SocialStringsB.postYourTrip), findsOneWidget);
        expect(find.text('Free: 1 public trip, 1 join request a month'), findsOneWidget);
        expect(find.text(SocialStringsB.yourPost), findsOneWidget);
        expect(find.text(SocialStringsB.noRequestsYet), findsOneWidget);
        final mineTop = t.getTopLeft(find.text('Manali')).dy;
        final otherTop = t.getTopLeft(find.text('Rishikesh', skipOffstage: false)).dy;
        expect(mineTop, lessThan(otherTop));
        expect(find.text(SocialStringsB.requestToJoin, skipOffstage: false), findsOneWidget);
        expect(find.text(SocialStringsB.requested, skipOffstage: false), findsOneWidget);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('after posting: a two-line live card with a close button, my post right under Post your trip, no Plus banner', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _feed, _page(mine: [publicTripJson(id: 'mine-1', ownerId: 'me', ownerName: 'Rahul Verma', cities: ['Manali'], isMine: true, waitingRequests: 0)]));
    await pumpSocial(t, const TravelBuddiesScreen(posted: true), pages: _pages);
    expect(find.byKey(TravelBuddiesScreen.liveKey), findsOneWidget);
    expect(find.text(SocialStringsB.liveTitle('Manali')), findsOneWidget);
    expect(find.text(SocialStringsB.liveBody), findsOneWidget);
    expect(find.byType(PlusBanner), findsNothing);
    await t.tap(find.byKey(TravelBuddiesScreen.liveCloseKey));
    await t.pump();
    expect(find.byKey(TravelBuddiesScreen.liveKey), findsNothing);
    await drain(t);
  });

  testWidgets('waiting requests on my post open Join requests', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _feed, _page(mine: [publicTripJson(id: 'mine-1', isMine: true, waitingRequests: 3)]));
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    await t.tap(find.text(SocialStringsB.requests(3)));
    await settle(t);
    expect(find.text('REQUESTS mine-1'), findsOneWidget);
    await drain(t);
  });

  testWidgets('Request to join sends the note and turns the button into Requested', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _feed, _page(items: [publicTripJson(id: 'trip-1')]));
    server.on('POST', '/social/trips/trip-1/join-requests', {'id': 'jr-1', 'status': 'Waiting'});
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    await t.tap(find.byKey(const ValueKey('feed_request_trip-1')));
    await settle(t);
    expect(find.text('Free: 1 join request a month. This one is it.'), findsOneWidget);
    await t.enterText(find.byKey(JoinRequestSheet.noteKey), 'Happy to split the cab.');
    server.on('GET', _feed, _page(items: [publicTripJson(id: 'trip-1', myJoin: 'requested')]));
    await t.tap(find.byKey(JoinRequestSheet.sendKey));
    await settle(t);
    final sent = server.calls('POST', '/social/trips/trip-1/join-requests');
    expect(sent, hasLength(1));
    expect((sent.single.data as Map)['note'], 'Happy to split the cab.');
    expect((sent.single.data as Map)['clientRequestId'], isNotEmpty);
    expect(find.text(SocialStringsB.requested), findsOneWidget);
    await drain(t);
  });

  testWidgets('an empty feed shows the empty state', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _feed, _page());
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    expect(find.text(SocialStringsB.feedEmptyTitle), findsOneWidget);
    await drain(t);
  });

  testWidgets('a failed feed shows Retry and loads again', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.refuse('GET', _feed, status: 400, type: 'Bad');
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    expect(find.text(SocialStrings.retry), findsOneWidget);
    server.on('GET', _feed, _page(items: [publicTripJson(id: 'trip-1')]));
    await t.tap(find.text(SocialStrings.retry));
    await settle(t);
    expect(find.text('Rishikesh'), findsOneWidget);
    await drain(t);
  });

  testWidgets('Post your trip opens the wizard, and the limit sheet when the free post is used', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _feed, _page());
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    await t.tap(find.byKey(TravelBuddiesScreen.postKey));
    await settle(t);
    expect(find.text('WIZARD'), findsOneWidget);
    await drain(t);
  });

  testWidgets('with the free public trip used, Post your trip opens the limit sheet', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith(publicUsed: 1));
    server.on('GET', _feed, _page());
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    await t.tap(find.byKey(TravelBuddiesScreen.postKey));
    await settle(t);
    expect(find.text('WIZARD'), findsNothing);
    expect(find.byKey(const ValueKey('plus_limit_sheet')), findsOneWidget);
    await drain(t);
  });

  testWidgets('posts are not limited by active trips: active slot full but a free public slot opens the wizard', (t) async {
    final server = installServer();
    final me = socialMeWith();
    (me['limits'] as Map)['activeTrips'] = {'limit': 1, 'used': 1};
    (me['limits'] as Map)['publicTrips'] = {'limit': 1, 'used': 0};
    putSocialMe(server, me);
    server.on('GET', _feed, _page());
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    await t.tap(find.byKey(TravelBuddiesScreen.postKey));
    await settle(t);
    expect(find.text('WIZARD'), findsOneWidget);
    expect(find.byKey(const ValueKey('plus_limit_sheet')), findsNothing);
    await drain(t);
  });

  for (final gender in ['Male', 'Other']) {
    testWidgets('a Women-only trip flagged notOpen for $gender: the full post shows, a calm disabled line replaces Request to join (spec 22)', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith(gender: gender));
      server.on('GET', _feed, _page(items: [publicTripJson(id: 'w-1', cities: ['Kasol'], joinGender: 'F', notOpen: true), publicTripJson(id: 'a-1', ownerId: 'aman', cities: ['Spiti'])]));
      await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
      expect(find.text('Kasol'), findsOneWidget);
      final only = find.byKey(const ValueKey('feed_only_for_w-1'), skipOffstage: false);
      expect(only, findsOneWidget);
      expect(find.text('This trip is for women only', skipOffstage: false), findsOneWidget);
      final b = t.widget<GradientPillButton>(only);
      expect(b.enabled, isFalse);
      expect(b.onTap, isNull);
      expect(b.offLabelColor, isNotNull);
      expect(b.icon, Icons.lock_rounded);
      expect(find.byKey(const ValueKey('feed_request_w-1'), skipOffstage: false), findsNothing);
      expect(find.byKey(const ValueKey('feed_request_a-1'), skipOffstage: false), findsOneWidget);
      await drain(t);
    });
  }

  testWidgets('a Women-only trip seen by a woman shows Request to join; a Men-only trip says for men only', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith(gender: 'Female'));
    server.on('GET', _feed, _page(items: [publicTripJson(id: 'w-1', cities: ['Kasol'], joinGender: 'F'), publicTripJson(id: 'm-1', ownerId: 'aman', cities: ['Spiti'], joinGender: 'M', notOpen: true)]));
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    expect(find.byKey(const ValueKey('feed_request_w-1'), skipOffstage: false), findsOneWidget);
    expect(find.byKey(const ValueKey('feed_only_for_w-1'), skipOffstage: false), findsNothing);
    expect(find.byKey(const ValueKey('feed_only_for_m-1'), skipOffstage: false), findsOneWidget);
    expect(find.text('This trip is for men only', skipOffstage: false), findsOneWidget);
    await drain(t);
  });

  testWidgets('I-3: my own post card has no menu (Remove from Travel buddies is gone); the post goes only by deleting the trip', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _feed, _page(mine: [publicTripJson(id: 'mine-1', ownerId: 'me', ownerName: 'Rahul Verma', cities: ['Manali'], isMine: true, waitingRequests: 0)]));
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    expect(find.text(SocialStringsB.yourPost), findsOneWidget);
    expect(find.byKey(PublicTripCard.menuKey), findsNothing);
    expect(find.text('Remove from Travel buddies'), findsNothing);
    await drain(t);
  });

  testWidgets('mock D9b: the header bell is the 3D bell art and opens Notifications', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _feed, _page());
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    final bell = find.byKey(TravelBuddiesScreen.bellKey);
    expect(bell, findsOneWidget);
    expect(find.descendant(of: bell, matching: find.byWidgetPredicate((w) => w is Art3D && w.asset == ListingArt.bell)), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    await drain(t);
  });
  group('B1 Travellers you may know rail', () {
    testWidgets('one rail right after the 2nd post, loaded once with limit 5', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', _feed, _threePosts);
      server.on('GET', _discover, _suggestions());
      await pumpSocial(t, const TravelBuddiesScreen(), size: _tall, pages: _pages);
      final rail = find.byKey(TravelBuddiesScreen.railKey);
      expect(rail, findsOneWidget);
      expect(find.byType(DiscoverRail), findsOneWidget);
      expect(find.text(SocialStringsA.mayKnow), findsOneWidget);
      expect(find.text(SocialStringsA.nearYou), findsOneWidget);
      final top = t.getTopLeft(rail).dy;
      expect(top, greaterThan(t.getTopLeft(find.byKey(const ValueKey('feed-trip-2'))).dy));
      expect(top, lessThan(t.getTopLeft(find.byKey(const ValueKey('feed-trip-3'))).dy));
      final calls = server.calls('GET', _discover);
      expect(calls, hasLength(1));
      expect(calls.single.queryParameters['limit'], TravelBuddiesScreen.railSize);
      await drain(t);
      expect(t.takeException(), isNull);
    });

    testWidgets('a follow made on another screen flips the rail card', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', _feed, _threePosts);
      server.on('GET', _discover, _suggestions());
      await pumpSocial(t, const TravelBuddiesScreen(), size: _tall, pages: _pages);
      final rohit = find.byKey(DiscoverCard.keyOf('rohit'));
      expect(find.descendant(of: rohit, matching: find.text(SocialStrings.follow)), findsOneWidget);
      SocialLive.followChange.trigger(('rohit', true, false));
      await settle(t);
      expect(find.descendant(of: rohit, matching: find.text(SocialStrings.following)), findsOneWidget);
      expect(server.calls('GET', _discover), hasLength(1));
      await drain(t);
    });

    testWidgets('See all opens the Discover tab', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', _feed, _threePosts);
      server.on('GET', _discover, _suggestions());
      await pumpSocial(t, const TravelBuddiesScreen(), size: _tall, pages: _pages);
      await t.tap(find.byKey(DiscoverRail.seeAllKey));
      await settle(t);
      expect(find.text('PEOPLE discover'), findsOneWidget);
      await drain(t);
    });

    testWidgets('hidden when nobody is suggested', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', _feed, _threePosts);
      server.on('GET', _discover, {'items': [], 'nextCursor': null});
      await pumpSocial(t, const TravelBuddiesScreen(), size: _tall, pages: _pages);
      expect(find.byKey(TravelBuddiesScreen.railKey), findsNothing);
      await drain(t);
    });

    testWidgets('hidden when the call fails, the feed still shows', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', _feed, _threePosts);
      server.refuse('GET', _discover, status: 400, type: 'Bad');
      await pumpSocial(t, const TravelBuddiesScreen(), size: _tall, pages: _pages);
      expect(find.byKey(TravelBuddiesScreen.railKey), findsNothing);
      expect(find.byKey(const ValueKey('feed-trip-3')), findsOneWidget);
      await drain(t);
    });

    testWidgets('hidden while a search is typed', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', _feed, _threePosts);
      server.on('GET', _discover, _suggestions());
      await pumpSocial(t, const TravelBuddiesScreen(), size: _tall, pages: _pages);
      expect(find.byKey(TravelBuddiesScreen.railKey), findsOneWidget);
      await t.enterText(find.descendant(of: find.byKey(TravelBuddiesScreen.searchKey), matching: find.byType(TextField)), 'Spiti');
      await t.pump(const Duration(milliseconds: 500));
      await settle(t);
      expect(find.byKey(TravelBuddiesScreen.railKey), findsNothing);
      await drain(t);
    });
  });
}
