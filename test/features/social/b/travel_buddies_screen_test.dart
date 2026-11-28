import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/a/people/discover/discover_card.dart';
import 'package:bakhli/features/social/a/people/discover/discover_rail.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/b/feed/travel_buddies_screen.dart';
import 'package:bakhli/features/social/b/post/join_request_sheet.dart';
import 'package:bakhli/features/social/b/post/own_post_menu.dart';
import 'package:bakhli/features/social/b/social_nav_b.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/b/widgets/sliding_tabs.dart';
import 'package:bakhli/features/social/shared/social_formats.dart';
import 'package:bakhli/features/social/shared/social_live.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:bakhli/features/social/shared/widgets/follow_button.dart';
import 'package:bakhli/features/social/shared/widgets/plus_widgets.dart';
import 'package:bakhli/features/social/shared/widgets/trip_join_card.dart';
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
  GetPage(name: AppRoutes.tripTravellers, page: () => Scaffold(body: Text('TRAVELLERS ${(Get.arguments as Map)['tripId']}'))),
];

const _discover = '/social/discover';

Map<String, dynamic> _suggest(String id, String name, String kind) =>
    {...personJson(id, name), 'followsMe': false, 'iFollow': false, 'followRequested': false, 'isPrivate': false, 'reason': {'kind': kind}};

Map<String, dynamic> _suggestions() => {
      'items': [_suggest('rohit', 'Rohit Rana', 'mutual'), _suggest('sneha', 'Sneha Joshi', 'near')],
      'nextCursor': null,
    };

final _three = [
  publicTripJson(id: 'trip-1'),
  publicTripJson(id: 'trip-2', ownerId: 'aman', ownerName: 'Aman Kumar', cities: ['Spiti']),
  publicTripJson(id: 'trip-3', ownerId: 'mehak', ownerName: 'Mehak Rao', cities: ['Manali']),
];

Map<String, dynamic> _myPost({String id = 'mine-1', String city = 'Manali', int waiting = 0}) =>
    publicTripJson(id: id, ownerId: 'me', ownerName: 'Rahul Verma', cities: [city], isMine: true, waitingRequests: waiting);

const _tall = Size(392, 4000);

GradientPillButton _pill(WidgetTester t, String id) => t.widget<GradientPillButton>(find.byKey(TripJoinCard.actionKey(id), skipOffstage: false));

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
      testWidgets('Travel groups opens on Explore: others only, Join and Requested, sticky Post your trip ($size, $scale)', (t) async {
        final server = installServer();
        putSocialMe(server, socialMeWith());
        stubGroups(
          server,
          feed: [publicTripJson(id: 'trip-1'), publicTripJson(id: 'trip-2', ownerId: 'aman', ownerName: 'Aman Kumar', cities: ['Spiti'], myJoin: 'requested')],
          mine: [_myPost()],
        );
        await pumpSocial(t, const TravelBuddiesScreen(), size: size, textScale: scale, pages: _pages);
        expect(find.text(SocialStringsB.travelGroups), findsOneWidget);
        expect(find.text(SocialStringsB.travelGroupsSub), findsOneWidget);
        expect(find.byKey(TravelBuddiesScreen.tabsKey), findsOneWidget);
        expect(find.text(SocialStringsB.tabExplore), findsOneWidget);
        expect(find.text(SocialStringsB.tabMyPosts), findsOneWidget);
        expect(find.byKey(TravelBuddiesScreen.exploreKey), findsOneWidget);
        expect(find.byKey(TravelBuddiesScreen.searchKey), findsOneWidget);
        expect(find.text(SocialStringsB.postYourTrip), findsOneWidget);
        expect(find.text('Free: 1 public trip, 1 join request a month'), findsOneWidget);
        expect(find.byKey(TripJoinCard.cardKey('mine-1')), findsNothing);
        expect(find.text('Manali'), findsNothing);
        expect(_pill(t, 'trip-1').label, SocialStringsB.join);
        expect(find.descendant(of: find.byKey(TripJoinCard.actionKey('trip-2'), skipOffstage: false), matching: find.text(SocialStringsB.requested, skipOffstage: false)), findsOneWidget);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('the tabs switch Explore and My posts; search shows only on Explore', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server, feed: [publicTripJson(id: 'trip-1')], mine: [_myPost(waiting: 2)]);
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    expect(find.byKey(TravelBuddiesScreen.searchKey), findsOneWidget);
    expect(find.byKey(TripJoinCard.cardKey('trip-1')), findsOneWidget);
    await t.tap(find.byKey(SlidingTabs.tabKey(TravelBuddiesScreen.tabMine)));
    await settle(t);
    expect(find.byKey(TravelBuddiesScreen.searchKey), findsNothing);
    expect(find.byKey(TravelBuddiesScreen.filterKey), findsNothing);
    expect(find.byKey(TravelBuddiesScreen.mineKey), findsOneWidget);
    expect(find.byKey(TripJoinCard.cardKey('mine-1')), findsOneWidget);
    expect(find.byKey(TripJoinCard.cardKey('trip-1')), findsNothing);
    expect(find.text(SocialStringsB.you), findsOneWidget);
    expect(find.byKey(TravelBuddiesScreen.postKey), findsOneWidget);
    await t.tap(find.byKey(SlidingTabs.tabKey(TravelBuddiesScreen.tabExplore)));
    await settle(t);
    expect(find.byKey(TravelBuddiesScreen.searchKey), findsOneWidget);
    expect(find.byKey(TripJoinCard.cardKey('trip-1')), findsOneWidget);
    expect(server.calls('GET', minePath), hasLength(1));
    expect(server.calls('GET', feedPath), hasLength(1));
    await drain(t);
  });

  group('I-38 own post menu on My posts', () {
    tearDown(() => OwnPostMenu.debugDelete = null);

    testWidgets('a delete from the card menu removes the card from My posts', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      stubGroups(server, mine: [{..._myPost(), 'members': 0}]);
      final deleted = <String>[];
      OwnPostMenu.debugDelete = (_, id) async {
        deleted.add(id);
        server.on('GET', minePath, minePage());
        return true;
      };
      await pumpSocial(t, const TravelBuddiesScreen(myPosts: true), pages: _pages);
      expect(find.byKey(TripJoinCard.cardKey('mine-1')), findsOneWidget);
      await t.tap(find.byKey(TripJoinCard.menuKey));
      await settle(t);
      await t.tap(find.byKey(OwnPostMenu.deleteKey));
      await settle(t);
      expect(deleted, ['mine-1']);
      expect(find.byKey(TripJoinCard.cardKey('mine-1')), findsNothing);
      expect(find.byKey(TravelBuddiesScreen.mineEmptyKey), findsOneWidget);
      await drain(t);
    });

    testWidgets('after Members removes someone the card menu shows the new count, and the delete block clears at 0', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      stubGroups(server, mine: [{..._myPost(), 'members': 2}]);
      var deletes = 0;
      OwnPostMenu.debugDelete = (_, id) async {
        deletes++;
        return false;
      };
      await pumpSocial(t, const TravelBuddiesScreen(myPosts: true), pages: _pages);
      await t.tap(find.byKey(TripJoinCard.menuKey));
      await settle(t);
      expect(find.text('Members · 2'), findsOneWidget);
      expect(find.text(SocialStringsB.deleteTripBlocked), findsOneWidget);
      await t.tap(find.byKey(OwnPostMenu.membersKey));
      await settle(t);
      expect(find.text('TRAVELLERS mine-1'), findsOneWidget);
      server.on('GET', minePath, minePage([{..._myPost(), 'members': 1}]));
      Get.back<void>();
      await settle(t);
      await t.tap(find.byKey(TripJoinCard.menuKey));
      await settle(t);
      expect(find.text('Members · 1'), findsOneWidget);
      expect(find.text(SocialStringsB.deleteTripBlocked), findsOneWidget);
      await t.tap(find.byKey(OwnPostMenu.membersKey));
      await settle(t);
      server.on('GET', minePath, minePage([{..._myPost(), 'members': 0}]));
      Get.back<void>();
      await settle(t);
      await t.tap(find.byKey(TripJoinCard.menuKey));
      await settle(t);
      expect(find.text('Members'), findsOneWidget);
      expect(find.text(SocialStringsB.deleteTripBlocked), findsNothing);
      await t.tap(find.byKey(OwnPostMenu.deleteKey));
      await settle(t);
      expect(deletes, 1, reason: 'with nobody left the delete flow runs');
      await drain(t);
    });
  });

  testWidgets('myPosts: true opens on My posts', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server, feed: [publicTripJson(id: 'trip-1')], mine: [_myPost()]);
    await pumpSocial(t, const TravelBuddiesScreen(myPosts: true), pages: _pages);
    expect(find.byKey(TravelBuddiesScreen.mineKey), findsOneWidget);
    expect(find.byKey(TravelBuddiesScreen.searchKey), findsNothing);
    expect(find.byKey(TripJoinCard.cardKey('mine-1')), findsOneWidget);
    expect(find.byKey(TravelBuddiesScreen.liveKey), findsNothing);
    await drain(t);
  });

  testWidgets('My posts lists /social/trips/mine in the server order with N requests and No requests', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server, mine: [_myPost(id: 'mine-2', city: 'Kedarnath', waiting: 3), _myPost()]);
    await pumpSocial(t, const TravelBuddiesScreen(myPosts: true), size: _tall, pages: _pages);
    expect(t.getTopLeft(find.byKey(TripJoinCard.cardKey('mine-2'))).dy, lessThan(t.getTopLeft(find.byKey(TripJoinCard.cardKey('mine-1'))).dy));
    expect(_pill(t, 'mine-2').label, SocialStringsB.requests(3));
    final none = _pill(t, 'mine-1');
    expect(none.label, SocialStringsB.noRequests);
    expect(none.enabled, isFalse);
    await drain(t);
  });

  testWidgets('waiting requests on my post open Join requests', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server, mine: [_myPost(waiting: 3)]);
    await pumpSocial(t, const TravelBuddiesScreen(myPosts: true), pages: _pages);
    await t.tap(find.text(SocialStringsB.requests(3)));
    await settle(t);
    expect(find.text('REQUESTS mine-1'), findsOneWidget);
    await drain(t);
  });

  testWidgets('back from Join requests after declining all: My posts reloads and shows No requests', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server, mine: [_myPost(waiting: 3)]);
    await pumpSocial(t, const TravelBuddiesScreen(myPosts: true), pages: _pages);
    await t.tap(find.text(SocialStringsB.requests(3)));
    await settle(t);
    server.on('GET', minePath, minePage([_myPost()]));
    Get.back();
    await settle(t);
    expect(server.calls('GET', minePath), hasLength(2));
    expect(_pill(t, 'mine-1').label, SocialStringsB.noRequests);
    await drain(t);
  });

  testWidgets('My posts empty: the empty state, and the sticky Post your trip opens the wizard', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server, feed: [publicTripJson(id: 'trip-1')]);
    await pumpSocial(t, const TravelBuddiesScreen(myPosts: true), pages: _pages);
    expect(find.byKey(TravelBuddiesScreen.mineEmptyKey), findsOneWidget);
    expect(find.text(SocialStringsB.myPostsEmptyTitle), findsOneWidget);
    expect(find.text(SocialStringsB.myPostsEmptyBody), findsOneWidget);
    await t.tap(find.byKey(TravelBuddiesScreen.postKey));
    await settle(t);
    expect(find.text('WIZARD'), findsOneWidget);
    await drain(t);
  });

  testWidgets('My posts failed shows Retry and loads again', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', feedPath, feedPage());
    server.refuse('GET', minePath, status: 400, type: 'Bad');
    await pumpSocial(t, const TravelBuddiesScreen(myPosts: true), pages: _pages);
    expect(find.text(SocialStrings.retry), findsOneWidget);
    server.on('GET', minePath, minePage([_myPost()]));
    await t.tap(find.text(SocialStrings.retry));
    await settle(t);
    expect(find.byKey(TripJoinCard.cardKey('mine-1')), findsOneWidget);
    await drain(t);
  });

  testWidgets('the Plus banner sits on Explore when My posts is loaded and empty', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server, feed: [publicTripJson(id: 'trip-1')]);
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    expect(find.byType(PlusBanner), findsOneWidget);
    await drain(t);
  });

  testWidgets('no Plus banner on Explore when I have a post', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server, feed: [publicTripJson(id: 'trip-1')], mine: [_myPost()]);
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    expect(find.byType(PlusBanner), findsNothing);
    await drain(t);
  });

  testWidgets('after posting: My posts opens with a two-line live card for the newest post, with a close button', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server, mine: [_myPost(), _myPost(id: 'mine-0', city: 'Shimla')]);
    await pumpSocial(t, const TravelBuddiesScreen(posted: true), pages: _pages);
    expect(find.byKey(TravelBuddiesScreen.mineKey), findsOneWidget);
    expect(find.byKey(TravelBuddiesScreen.liveKey), findsOneWidget);
    expect(find.text(SocialStringsB.liveTitle('Manali')), findsOneWidget);
    expect(find.text(SocialStringsB.liveBody), findsOneWidget);
    expect(find.byType(PlusBanner), findsNothing);
    await t.tap(find.byKey(TravelBuddiesScreen.liveCloseKey));
    await t.pump();
    expect(find.byKey(TravelBuddiesScreen.liveKey), findsNothing);
    await drain(t);
  });

  testWidgets('a post made while Travel groups is open switches to My posts, reloads it and shows the live card', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server, feed: [publicTripJson(id: 'trip-1')]);
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    expect(find.byKey(TravelBuddiesScreen.exploreKey), findsOneWidget);
    server.on('GET', minePath, minePage([_myPost(city: 'Kasol')]));
    SocialNavB.posted.value++;
    await settle(t);
    expect(find.byKey(TravelBuddiesScreen.mineKey), findsOneWidget);
    expect(find.byKey(TripJoinCard.cardKey('mine-1')), findsOneWidget);
    expect(find.text(SocialStringsB.liveTitle('Kasol')), findsOneWidget);
    expect(server.calls('GET', minePath), hasLength(2));
    await drain(t);
  });

  testWidgets('the Post your trip bar stays fixed under a long Explore list', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server, feed: _three);
    const size = Size(392, 760);
    await pumpSocial(t, const TravelBuddiesScreen(), size: size, pages: _pages);
    final post = find.byKey(TravelBuddiesScreen.postKey);
    expect(post.hitTestable(), findsOneWidget);
    final top = t.getTopLeft(post).dy;
    expect(t.getBottomLeft(post).dy, lessThanOrEqualTo(size.height));
    await t.drag(find.byKey(TravelBuddiesScreen.exploreKey), const Offset(0, -500));
    await settle(t);
    expect(t.getTopLeft(post).dy, top);
    await drain(t);
  });

  testWidgets('Join sends the note and turns the button into Requested', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server, feed: [publicTripJson(id: 'trip-1')]);
    server.on('POST', '/social/trips/trip-1/join-requests', {'id': 'jr-1', 'status': 'Waiting'});
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    await t.tap(find.byKey(TripJoinCard.actionKey('trip-1')));
    await settle(t);
    expect(find.text('Free: 1 join request a month. This one is it.'), findsOneWidget);
    await t.enterText(find.byKey(JoinRequestSheet.noteKey), 'Happy to split the cab.');
    server.on('GET', feedPath, feedPage(items: [publicTripJson(id: 'trip-1', myJoin: 'requested')]));
    await t.tap(find.byKey(JoinRequestSheet.sendKey));
    await settle(t);
    final sent = server.calls('POST', '/social/trips/trip-1/join-requests');
    expect(sent, hasLength(1));
    expect((sent.single.data as Map)['note'], 'Happy to split the cab.');
    expect((sent.single.data as Map)['clientRequestId'], isNotEmpty);
    expect(find.descendant(of: find.byKey(TripJoinCard.actionKey('trip-1')), matching: find.text(SocialStringsB.requested)), findsOneWidget);
    await drain(t);
  });

  testWidgets('a card tap opens the trip', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server, feed: [publicTripJson(id: 'trip-1')]);
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    await t.tap(find.text('Rishikesh'));
    await settle(t);
    expect(find.text('POST trip-1'), findsOneWidget);
    await drain(t);
  });

  testWidgets('a follow made anywhere flips Follow on every Explore card of that poster', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server, feed: [publicTripJson(id: 'trip-1'), publicTripJson(id: 'trip-2', cities: ['Kasol'])]);
    await pumpSocial(t, const TravelBuddiesScreen(), size: _tall, pages: _pages);
    final follows = find.byKey(TripJoinCard.followKey);
    expect(follows, findsNWidgets(2));
    expect(t.widgetList<FollowButton>(follows).every((b) => !b.iFollow), isTrue);
    SocialLive.followChange.trigger(('kavya', true, false));
    await settle(t);
    expect(t.widgetList<FollowButton>(follows).every((b) => b.iFollow), isTrue);
    await drain(t);
  });

  testWidgets('an empty feed shows the empty state', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server);
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    expect(find.text(SocialStringsB.feedEmptyTitle), findsOneWidget);
    await drain(t);
  });

  testWidgets('a failed feed shows Retry and loads again', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', minePath, minePage());
    server.refuse('GET', feedPath, status: 400, type: 'Bad');
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    expect(find.text(SocialStrings.retry), findsOneWidget);
    server.on('GET', feedPath, feedPage(items: [publicTripJson(id: 'trip-1')]));
    await t.tap(find.text(SocialStrings.retry));
    await settle(t);
    expect(find.text('Rishikesh'), findsOneWidget);
    await drain(t);
  });

  testWidgets('with the free public trip used, Post your trip opens the limit sheet', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith(publicUsed: 1));
    stubGroups(server);
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
    stubGroups(server);
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    await t.tap(find.byKey(TravelBuddiesScreen.postKey));
    await settle(t);
    expect(find.text('WIZARD'), findsOneWidget);
    expect(find.byKey(const ValueKey('plus_limit_sheet')), findsNothing);
    await drain(t);
  });

  for (final gender in ['Male', 'Other']) {
    testWidgets('a Women-only trip flagged notOpen for $gender: the card shows, a calm disabled lock button replaces Join (spec 22)', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith(gender: gender));
      stubGroups(server, feed: [publicTripJson(id: 'w-1', cities: ['Kasol'], joinGender: 'F', notOpen: true), publicTripJson(id: 'a-1', ownerId: 'aman', cities: ['Spiti'])]);
      await pumpSocial(t, const TravelBuddiesScreen(), size: _tall, pages: _pages);
      expect(find.text('Kasol'), findsOneWidget);
      final b = _pill(t, 'w-1');
      expect(b.enabled, isFalse);
      expect(b.onTap, isNull);
      expect(b.icon, Icons.lock_rounded);
      expect(b.label, SocialFormats.whoCanJoin('F'));
      expect(_pill(t, 'a-1').label, SocialStringsB.join);
      await drain(t);
    });
  }

  testWidgets('a Women-only trip seen by a woman shows Join; a Men-only trip is locked for her', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith(gender: 'Female'));
    stubGroups(server, feed: [publicTripJson(id: 'w-1', cities: ['Kasol'], joinGender: 'F'), publicTripJson(id: 'm-1', ownerId: 'aman', cities: ['Spiti'], joinGender: 'M', notOpen: true)]);
    await pumpSocial(t, const TravelBuddiesScreen(), size: _tall, pages: _pages);
    expect(_pill(t, 'w-1').label, SocialStringsB.join);
    final m = _pill(t, 'm-1');
    expect(m.enabled, isFalse);
    expect(m.label, SocialFormats.whoCanJoin('M'));
    await drain(t);
  });

  testWidgets('mock D9b: the header bell is the 3D bell art and opens Notifications', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    stubGroups(server);
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
      stubGroups(server, feed: _three);
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
      stubGroups(server, feed: _three);
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
      stubGroups(server, feed: _three);
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
      stubGroups(server, feed: _three);
      server.on('GET', _discover, {'items': [], 'nextCursor': null});
      await pumpSocial(t, const TravelBuddiesScreen(), size: _tall, pages: _pages);
      expect(find.byKey(TravelBuddiesScreen.railKey), findsNothing);
      await drain(t);
    });

    testWidgets('hidden when the call fails, the feed still shows', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      stubGroups(server, feed: _three);
      server.refuse('GET', _discover, status: 400, type: 'Bad');
      await pumpSocial(t, const TravelBuddiesScreen(), size: _tall, pages: _pages);
      expect(find.byKey(TravelBuddiesScreen.railKey), findsNothing);
      expect(find.byKey(const ValueKey('feed-trip-3')), findsOneWidget);
      await drain(t);
    });

    testWidgets('hidden while a search is typed', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      stubGroups(server, feed: _three);
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
