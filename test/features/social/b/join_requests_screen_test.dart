import 'package:bakhli/features/social/b/join/join_requests_screen.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

const _path = '/social/trips/trip-1/join-requests';

Map<String, dynamic> _item(String id, String userId, String name, int tier, {String? note, int mutualCount = 0, String? mutualName}) => {
      'id': id,
      'person': rowJson(userId, name, followsMe: tier == 1, mutualCount: mutualCount, mutualName: mutualName),
      'tier': tier,
      'note': note,
      'interests': ['Treks', 'Food'],
      'createdAt': '2026-11-26T09:00:00Z',
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {
      'trip': publicTripJson(isMine: true, cities: ['Manali'], when: {'kind': 'within', 'months': 2}, seats: 3, seatsLeft: 3),
      'items': items,
    };

final _three = [
  _item('jr-a', 'aman', 'Aman Kumar', 0, note: 'Count me in.'),
  _item('jr-r', 'rohan', 'Rohan Mehta', 1, note: 'Same plan here, happy to split the cab from Delhi.', mutualCount: 3),
  _item('jr-m', 'meera', 'Meera Joshi', 2, note: 'First time in Himachal, would love company.', mutualCount: 1, mutualName: 'Aman'),
];

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
      testWidgets('tiers: My Buddies, Followers, Other requests, with notes and facts ($size, $scale)', (t) async {
        final server = installServer();
        server.on('GET', _path, _page(_three));
        await pumpSocial(t, const JoinRequestsScreen(tripId: 'trip-1'), size: size, textScale: scale);
        expect(find.text(SocialStringsB.joinRequestsTitle), findsOneWidget);
        expect(find.text('Manali · within 2 months · 3 seats left'), findsOneWidget);
        expect(find.text(SocialStringsB.sectionBuddies(1).toUpperCase()), findsOneWidget);
        expect(find.text(SocialStringsB.sectionFollowers(1).toUpperCase()), findsOneWidget);
        expect(find.text(SocialStringsB.sectionOthers(1).toUpperCase()), findsOneWidget);
        expect(find.text('Follows you · 3 mutual'), findsOneWidget);
        expect(find.text('Follows you · 3 mutual · Treks, Food'), findsNothing);
        expect(find.text('Followed by Aman · Treks, Food'), findsOneWidget);
        expect(find.text('“Same plan here, happy to split the cab from Delhi.”'), findsOneWidget);
        expect(find.byKey(JoinRequestsScreen.buddyKey('jr-r')), findsOneWidget);
        expect(find.byKey(JoinRequestsScreen.buddyKey('jr-a')), findsNothing);
        expect(find.byKey(JoinRequestsScreen.buddyKey('jr-m')), findsNothing);
        expect(find.text(SocialStringsB.acceptNote, skipOffstage: false), findsOneWidget);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('Accept with the buddy tick sends addToBuddies and removes the card', (t) async {
    final server = installServer();
    server.on('GET', _path, _page(_three));
    server.on('POST', '/social/join-requests/jr-r/accept', {'memberId': 'm-1', 'seatsLeft': 2, 'roomId': 'room-1'});
    await pumpSocial(t, const JoinRequestsScreen(tripId: 'trip-1'));
    await t.tap(find.byKey(JoinRequestsScreen.buddyKey('jr-r')));
    await settle(t);
    await t.ensureVisible(find.byKey(JoinRequestsScreen.acceptKey('jr-r')));
    await t.tap(find.byKey(JoinRequestsScreen.acceptKey('jr-r')));
    await settle(t);
    final call = server.calls('POST', '/social/join-requests/jr-r/accept').single;
    expect((call.data as Map)['addToBuddies'], isTrue);
    expect(find.byKey(const ValueKey('join_card_jr-r')), findsNothing);
    expect(find.text(SocialStringsB.sectionFollowers(1).toUpperCase()), findsNothing);
    await drain(t);
  });

  testWidgets('Accept without the tick sends addToBuddies false', (t) async {
    final server = installServer();
    server.on('GET', _path, _page(_three));
    server.on('POST', '/social/join-requests/jr-m/accept', {'memberId': 'm-2', 'seatsLeft': 2, 'roomId': 'room-1'});
    await pumpSocial(t, const JoinRequestsScreen(tripId: 'trip-1'));
    await t.ensureVisible(find.byKey(JoinRequestsScreen.acceptKey('jr-m')));
    await t.tap(find.byKey(JoinRequestsScreen.acceptKey('jr-m')));
    await settle(t);
    expect((server.calls('POST', '/social/join-requests/jr-m/accept').single.data as Map)['addToBuddies'], isFalse);
    await drain(t);
  });

  testWidgets('a request that is gone stays removed; a failed decline puts the card back', (t) async {
    final server = installServer();
    server.on('GET', _path, _page(_three));
    server.refuse('POST', '/social/join-requests/jr-a/accept', status: 409, type: 'JoinRequestGone', message: 'This request is no longer waiting.');
    server.refuse('POST', '/social/join-requests/jr-m/decline', status: 409, type: 'TripFull', message: 'Full');
    await pumpSocial(t, const JoinRequestsScreen(tripId: 'trip-1'));
    await t.tap(find.byKey(JoinRequestsScreen.acceptKey('jr-a')));
    await settle(t);
    expect(find.byKey(const ValueKey('join_card_jr-a')), findsNothing);
    await drain(t);
    await t.ensureVisible(find.byKey(JoinRequestsScreen.declineKey('jr-m')));
    await t.tap(find.byKey(JoinRequestsScreen.declineKey('jr-m')));
    await settle(t);
    expect(find.byKey(const ValueKey('join_card_jr-m')), findsOneWidget);
    await drain(t);
  });

  testWidgets('no waiting requests shows the empty state', (t) async {
    final server = installServer();
    server.on('GET', _path, _page(const []));
    await pumpSocial(t, const JoinRequestsScreen(tripId: 'trip-1'));
    expect(find.text(SocialStringsB.noRequestsTitle), findsOneWidget);
    await drain(t);
  });

  testWidgets('each request card shows the requester trophy and trips', (t) async {
    final server = installServer();
    server.on('GET', _path, _page([
      {..._item('jr-r', 'rohan', 'Rohan Mehta', 1), 'person': {...rowJson('rohan', 'Rohan Mehta', followsMe: true), 'completedTrips': 18, 'level': 2}},
      _item('jr-m', 'meera', 'Meera Joshi', 2),
    ]));
    await pumpSocial(t, const JoinRequestsScreen(tripId: 'trip-1'));
    expect(find.descendant(of: find.byKey(JoinRequestsScreen.levelKey('jr-r')), matching: find.text('18 trips')), findsOneWidget);
    expect(find.descendant(of: find.byKey(JoinRequestsScreen.levelKey('jr-m')), matching: find.text('0 trips')), findsOneWidget);
    await drain(t);
  });
}
