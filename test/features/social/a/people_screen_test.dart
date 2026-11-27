import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/buddy/buddies/data/buddies_api.dart';
import 'package:bakhli/features/buddy/buddies/models/buddy_models.dart';
import 'package:bakhli/features/buddy/scan/scan_outcome.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/a/people/people_find.dart';
import 'package:bakhli/features/social/a/people/people_screen.dart';
import 'package:bakhli/features/social/a/people/scan_to_follow.dart';
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

class _FindApi extends BuddiesApi {
  _FindApi({this.followState = 'none', this.found = true});

  final String followState;
  final bool found;
  final finds = <String>[];

  @override
  Future<BuddyResult<FindResult>> find(String query, {required String source}) async {
    finds.add('$query:$source');
    if (!found) return const BuddyOk(FindResult(found: false));
    return BuddyOk(FindResult(
        found: true, person: FoundPerson(userId: 'vikram', name: 'Vikram', username: 'Bakhli#29583047', initial: 'V', relation: BuddyRelation.none, followState: followState)));
  }
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
  testWidgets('Q2: Scan QR sits on People and a scan opens the traveller profile to follow', (t) async {
    _server();
    final api = _FindApi();
    final opened = <String>[];
    var scans = 0;
    final flow = ScanToFollow(
      api: api,
      scan: () async {
        scans++;
        return const ScanFound('Bakhli#29583047');
      },
      openTraveller: opened.add,
    );
    await pumpSocial(t, PeopleScreen(scanToFollow: flow), pages: _pages);
    expect(find.byKey(PeopleScreen.scanQrKey), findsOneWidget);
    expect(find.text(SocialStringsA.scanQrLine), findsNothing, reason: 'I-12: no separate Scan QR card');
    final field = t.getRect(find.byKey(PeopleFindSection.fieldKey));
    final scan = t.getRect(find.byKey(PeopleScreen.scanQrKey));
    expect(scan.center.dy, closeTo(field.center.dy, DS.s(16)), reason: 'I-12: search and scan in one row');
    await t.tap(find.byKey(PeopleScreen.scanQrKey));
    await settle(t);
    expect(scans, 1);
    expect(api.finds, ['Bakhli#29583047:Qr']);
    expect(opened, ['vikram']);
    await drain(t);
  });

  for (final (state, label) in [('none', SocialStrings.follow), ('requested', SocialStrings.requested), ('following', SocialStrings.following)]) {
    testWidgets('I-12 username search shows the person with $label', (t) async {
      _server();
      final api = _FindApi(followState: state);
      await pumpSocial(t, PeopleScreen(scanToFollow: ScanToFollow(api: api)), pages: _pages);
      await t.enterText(find.byKey(PeopleFindSection.fieldKey), 'bakhli#29583047');
      await t.tap(find.byKey(PeopleFindSection.searchKey));
      await settle(t);
      expect(api.finds, ['Bakhli#29583047:Search']);
      final result = find.byKey(PeopleFindSection.resultKey);
      expect(result, findsOneWidget);
      expect(find.descendant(of: result, matching: find.text('Vikram')), findsOneWidget);
      expect(find.descendant(of: result, matching: find.text(label)), findsOneWidget);
      await drain(t);
    });
  }

  testWidgets('I-12 an unknown or badly typed username says no traveller found', (t) async {
    _server();
    final api = _FindApi(found: false);
    await pumpSocial(t, PeopleScreen(scanToFollow: ScanToFollow(api: api)), pages: _pages);
    await t.enterText(find.byKey(PeopleFindSection.fieldKey), 'hello');
    await t.tap(find.byKey(PeopleFindSection.searchKey));
    await settle(t);
    expect(api.finds, isEmpty);
    expect(find.text(SocialStringsA.noTravellerFound), findsOneWidget);
    await t.enterText(find.byKey(PeopleFindSection.fieldKey), 'Bakhli#11112222');
    await t.tap(find.byKey(PeopleFindSection.searchKey));
    await settle(t);
    expect(api.finds, ['Bakhli#11112222:Search']);
    expect(find.text(SocialStringsA.noTravellerFound), findsOneWidget);
    expect(find.byKey(PeopleFindSection.resultKey), findsNothing);
    await drain(t);
  });
}
