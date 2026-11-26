import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/social/b/feed/travel_buddies_screen.dart';
import 'package:bakhli/features/social/b/post/join_request_sheet.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:bakhli/features/social/shared/widgets/plus_widgets.dart';
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
];

const _feed = '/social/trips/feed';

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

  testWidgets('with the active trip slot full, Post your trip opens the trip limit sheet before the wizard', (t) async {
    final server = installServer();
    final me = socialMeWith();
    (me['limits'] as Map)['activeTrips'] = {'limit': 1, 'used': 1};
    putSocialMe(server, me);
    server.on('GET', _feed, _page());
    await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
    await t.tap(find.byKey(TravelBuddiesScreen.postKey));
    await settle(t);
    expect(find.text('WIZARD'), findsNothing);
    expect(find.byKey(const ValueKey('plus_limit_sheet')), findsOneWidget);
    await drain(t);
  });
}
