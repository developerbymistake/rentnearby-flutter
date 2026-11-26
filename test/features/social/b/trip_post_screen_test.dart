import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/social/b/post/join_request_sheet.dart';
import 'package:bakhli/features/social/b/post/trip_post_screen.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

final _pages = [
  GetPage(name: AppRoutes.joinRequests, page: () => Scaffold(body: Text('REQUESTS ${(Get.arguments as Map)['tripId']}'))),
  GetPage(name: AppRoutes.travelBuddies, page: () => const Scaffold(body: Text('FEED'))),
  GetPage(name: AppRoutes.traveller, page: () => const Scaffold(body: Text('PROFILE'))),
];

const _path = '/social/trips/trip-1';

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
      testWidgets('an open post: owner, mutuals, facts, text, safety line, Request to join ($size, $scale)', (t) async {
        final server = installServer();
        putSocialMe(server, socialMeWith());
        server.on('GET', _path, publicTripJson(mutuals: {'count': 1, 'names': ['Aman'], 'photoUrls': []}));
        await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), size: size, textScale: scale, pages: _pages);
        expect(find.text(SocialStringsB.tripPost), findsOneWidget);
        expect(find.text(SocialStringsB.byOwner('Kavya S.')), findsOneWidget);
        expect(find.text('Kavya Sharma'), findsOneWidget);
        expect(find.text('Followed by Aman'), findsOneWidget);
        expect(find.text('Uttarakhand'), findsOneWidget);
        expect(find.text('December'), findsOneWidget);
        expect(find.text('5 days'), findsOneWidget);
        expect(find.text('2 left'), findsOneWidget);
        expect(find.text(SocialStrings.safetyMeet), findsOneWidget);
        expect(find.byKey(TripPostScreen.requestKey), findsOneWidget);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('Request to join -> Requested with Cancel request; cancel goes back', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson());
    server.on('POST', '$_path/join-requests', {'id': 'jr-1', 'status': 'Waiting'});
    server.on('DELETE', '$_path/join-requests/mine', {});
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    await t.tap(find.byKey(TripPostScreen.requestKey));
    await settle(t);
    server.on('GET', _path, publicTripJson(myJoin: 'requested'));
    await t.tap(find.byKey(JoinRequestSheet.sendKey));
    await settle(t);
    expect(find.text(SocialStringsB.requested), findsOneWidget);
    expect(find.byKey(TripPostScreen.cancelKey), findsOneWidget);
    server.on('GET', _path, publicTripJson());
    await t.tap(find.byKey(TripPostScreen.cancelKey));
    await settle(t);
    expect(server.calls('DELETE', '$_path/join-requests/mine'), hasLength(1));
    expect(find.byKey(TripPostScreen.requestKey), findsOneWidget);
    await drain(t);
  });

  testWidgets('a 429 join limit closes the sheet and opens the Plus limit sheet', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith(joinUsed: 1));
    server.on('GET', _path, publicTripJson());
    server.refuse('POST', '$_path/join-requests', status: 429, type: 'JoinRequestLimit');
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    await t.tap(find.byKey(TripPostScreen.requestKey));
    await settle(t);
    await t.tap(find.byKey(JoinRequestSheet.sendKey));
    await settle(t);
    expect(find.byKey(JoinRequestSheet.sendKey), findsNothing);
    expect(find.byKey(const ValueKey('plus_limit_sheet')), findsOneWidget);
    await drain(t);
  });

  testWidgets('a trip for the other gender: not open, no Request button, See trips', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson(joinGender: 'F', notOpen: true, text: '', seats: 0, seatsLeft: 0, when: {'kind': 'within', 'months': 0}));
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.text(SocialStringsB.notOpenTitle), findsOneWidget);
    expect(find.text('It is for women only. Find trips you can join.'), findsOneWidget);
    expect(find.byKey(TripPostScreen.requestKey), findsNothing);
    expect(find.text(SocialStrings.safetyMeet), findsNothing);
    expect(find.text('Dehradun'), findsOneWidget);
    expect(find.byKey(TripPostScreen.menuKey), findsOneWidget);
    await t.tap(find.byKey(TripPostScreen.seeTripsKey));
    await settle(t);
    expect(find.text('FEED'), findsOneWidget);
    await drain(t);
  });

  testWidgets('my own post: Join requests and Open trip, no Request button', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson(isMine: true, ownerId: 'me', ownerName: 'Rahul Verma', waitingRequests: 2));
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.byKey(TripPostScreen.requestKey), findsNothing);
    expect(find.byKey(TripPostScreen.openTripKey), findsOneWidget);
    expect(find.text('${SocialStringsB.joinRequestsTitle} · 2'), findsOneWidget);
    await t.tap(find.byKey(TripPostScreen.joinRequestsKey));
    await settle(t);
    expect(find.text('REQUESTS trip-1'), findsOneWidget);
    await drain(t);
  });

  testWidgets('a post that is gone shows the not-available state', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.refuse('GET', _path, status: 404, type: 'TripPostNotFound');
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.text(SocialStringsB.postGone), findsOneWidget);
    await drain(t);
  });
}
