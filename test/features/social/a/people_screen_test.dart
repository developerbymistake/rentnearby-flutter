import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/social/a/people/people_screen.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';

final _pages = [
  GetPage(name: AppRoutes.people, page: () => Scaffold(body: Text('PEOPLE ${(Get.arguments as Map)['tab']}'))),
  GetPage(name: AppRoutes.addBuddies, page: () => const Scaffold(body: Text('ADD'))),
];

Map<String, dynamic> _page(List<Map<String, dynamic>> items, {int? total, int buddies = 0}) =>
    {'items': items, 'nextCursor': null, 'total': total ?? items.length, 'buddies': buddies};

SocialFakeServer _server({bool requests = true}) {
  final s = installServer();
  s.on('GET', '/social/followers', _page([
    rowJson('kavya', 'Kavya Sharma', mutualCount: 1, mutualName: 'Aman'),
    rowJson('rohan', 'Rohan Mehta', iFollow: true, mutualCount: 4, isBuddy: true),
  ], total: 128, buddies: 6));
  s.on('GET', '/social/following', _page([rowJson('rohan', 'Rohan Mehta', iFollow: true)], total: 41));
  s.on('GET', '/social/follow-requests', _page(requests ? [rowJson('meera', 'Meera Joshi', followsMe: false, mutualCount: 2), rowJson('sana', 'Sana Khan', followsMe: false)] : []));
  s.on('GET', '/buddies', {
    'items': [
      {'userId': 'rohan', 'name': 'Rohan Mehta', 'username': 'Bakhli#1', 'initial': 'R', 'isNew': false, 'gender': 'Male', 'tripsTogether': 2, 'mutualCount': 5},
    ],
    'count': 1,
    'nextCursor': null,
  });
  return s;
}

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
      testWidgets('Requests row on top, three tabs, followers with mutual lines ($size, $scale)', (t) async {
        _server();
        await pumpSocial(t, const PeopleScreen(), size: size, textScale: scale, pages: _pages);
        expect(find.byKey(PeopleScreen.requestsRowKey), findsOneWidget);
        expect(find.text(SocialStringsA.requestsLine('Meera J.', 2)), findsOneWidget);
        for (final tab in SocialStringsA.peopleTabs) {
          expect(find.text(tab), findsWidgets);
        }
        expect(find.text(SocialStringsA.followersCount(128).toUpperCase()), findsOneWidget);
        expect(find.text('Followed by Aman'), findsOneWidget);
        expect(find.text('4 mutual'), findsOneWidget);
        expect(find.text(SocialStrings.followBack), findsOneWidget);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('no Requests row when there are no follow requests', (t) async {
    _server(requests: false);
    await pumpSocial(t, const PeopleScreen(), pages: _pages);
    expect(find.byKey(PeopleScreen.requestsRowKey), findsNothing);
    await drain(t);
  });

  testWidgets('Requests row opens the requests list', (t) async {
    _server();
    await pumpSocial(t, const PeopleScreen(), pages: _pages);
    await t.tap(find.byKey(PeopleScreen.requestsRowKey));
    await settle(t);
    expect(find.text('PEOPLE requests'), findsOneWidget);
    await drain(t);
  });

  testWidgets('requests view: Accept removes the row and calls accept', (t) async {
    final s = _server();
    s.on('POST', '/social/follow-requests/meera/accept', {'state': 'accepted'});
    await pumpSocial(t, const PeopleScreen(tab: 'requests'), pages: _pages);
    expect(find.text(SocialStringsA.waiting(2)), findsOneWidget);
    expect(find.text(SocialStringsA.requestsNote), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('accept_meera')));
    await settle(t);
    expect(s.calls('POST', '/social/follow-requests/meera/accept'), hasLength(1));
    expect(find.byKey(const ValueKey('request_meera')), findsNothing);
    expect(find.byKey(const ValueKey('request_sana')), findsOneWidget);
    await drain(t);
  });

  testWidgets('remove follower from the 3 dots', (t) async {
    final s = _server();
    s.on('DELETE', '/social/followers/kavya', {});
    await pumpSocial(t, const PeopleScreen(), pages: _pages);
    await t.tap(find.descendant(of: find.byKey(const ValueKey('follower_kavya')), matching: find.byIcon(Icons.more_vert_rounded)));
    await settle(t);
    await t.tap(find.text(SocialStringsA.removeFollower));
    await settle(t);
    expect(s.calls('DELETE', '/social/followers/kavya'), hasLength(1));
    expect(find.byKey(const ValueKey('follower_kavya')), findsNothing);
    await drain(t);
  });

  testWidgets('My Buddies tab: Add from followers, buddy rows, remove buddy', (t) async {
    final s = _server();
    s.on('DELETE', '/buddies/rohan', {});
    await pumpSocial(t, const PeopleScreen(tab: 'buddies'), pages: _pages);
    expect(find.byKey(PeopleScreen.addFromFollowersKey), findsOneWidget);
    expect(find.text(SocialStringsA.buddiesNote), findsOneWidget);
    expect(find.byKey(const ValueKey('buddy_rohan')), findsOneWidget);
    expect(find.text(SocialStrings.buddyLine(2)), findsOneWidget);
    expect(find.text(SocialStrings.mutualCount(5)), findsOneWidget);
    await t.tap(find.descendant(of: find.byKey(const ValueKey('buddy_rohan')), matching: find.byIcon(Icons.more_vert_rounded)));
    await settle(t);
    await t.tap(find.text(SocialStringsA.removeBuddy));
    await settle(t);
    expect(s.calls('DELETE', '/buddies/rohan'), hasLength(1));
    expect(find.byKey(const ValueKey('buddy_rohan')), findsNothing);
    await drain(t);
  });
}
