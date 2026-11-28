import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/a/people/discover/discover_card.dart';
import 'package:bakhli/features/social/a/people/discover/discover_rail.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/shared/data/follow_api.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';

class _Api extends FollowApi {
  _Api(this.state);

  final String state;
  int follows = 0;

  @override
  Future<BuddyResult<String>> follow(String userId) async {
    follows++;
    return BuddyOk(state);
  }
}

DiscoverPerson _person({DiscoverReason reason = const DiscoverReason(kind: DiscoverReasonKinds.followsYou), bool followsMe = false, bool isPrivate = false}) => DiscoverPerson(
      person: const SocialPerson(userId: 'kavya', name: 'Kavya Sharma', username: 'Bakhli#123', initial: 'K', level: 3),
      followsMe: followsMe,
      isPrivate: isPrivate,
      reason: reason,
    );

Widget _host(Widget child) => Scaffold(body: Center(child: SizedBox(width: 170, child: child)));

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
  });
  tearDown(Get.reset);

  group('reason line of each kind', () {
    final cases = <(DiscoverReason, String)>[
      (const DiscoverReason(kind: DiscoverReasonKinds.sameTrip, cityName: 'Manali', month: 202612), 'Going to Manali in Dec, like you'),
      (const DiscoverReason(kind: DiscoverReasonKinds.travelledWith, cityName: 'Rishikesh'), 'Travelled with you · Rishikesh'),
      (const DiscoverReason(kind: DiscoverReasonKinds.followsYou), SocialStrings.followsYou),
      (const DiscoverReason(kind: DiscoverReasonKinds.mutual, mutualName: 'Aman', mutualCount: 4), 'Followed by Aman + 3 others'),
      (const DiscoverReason(kind: DiscoverReasonKinds.mutual, mutualCount: 2), 'Followed by 2 people you follow'),
      (const DiscoverReason(kind: DiscoverReasonKinds.near, tags: ['Treks', 'Camping']), 'Near you · Treks, Camping'),
      (const DiscoverReason(kind: DiscoverReasonKinds.interests, tags: ['Treks', 'Camping', 'Food']), 'Treks, Camping'),
      (const DiscoverReason(kind: DiscoverReasonKinds.places, tags: ['Auli']), 'Auli'),
    ];
    for (final (reason, line) in cases) {
      testWidgets('${reason.kind}: $line', (t) async {
        installServer();
        await pumpSocial(t, _host(DiscoverCard(item: _person(reason: reason), reason: SocialStringsA.reasonLine(reason), onHide: () {})));
        expect(find.text(line), findsOneWidget);
        expect(find.text('Kavya S.'), findsOneWidget);
        expect(find.text('Bakhli#123'), findsOneWidget);
        expect(find.byKey(DiscoverCard.hideKeyOf('kavya')), findsOneWidget);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  });

  testWidgets('a person who follows me gets Follow back', (t) async {
    installServer();
    await pumpSocial(t, _host(DiscoverCard(item: _person(followsMe: true), reason: SocialStrings.followsYou)));
    expect(find.text(SocialStrings.followBack), findsOneWidget);
    await drain(t);
  });

  testWidgets('a private profile reads Requested after the tap', (t) async {
    installServer();
    final api = _Api(FollowApi.stateRequested);
    final log = <(bool, bool)>[];
    await pumpSocial(t, _host(DiscoverCard(item: _person(isPrivate: true), reason: SocialStrings.followsYou, api: api, onFollowChanged: (f, q) => log.add((f, q)))));
    expect(find.text(SocialStrings.follow), findsOneWidget);
    await t.tap(find.text(SocialStrings.follow));
    await settle(t);
    expect(api.follows, 1);
    expect(find.text(SocialStrings.requested), findsOneWidget);
    expect(log.last, (false, true));
    await drain(t);
  });

  testWidgets('X calls hide', (t) async {
    installServer();
    var hidden = 0;
    await pumpSocial(t, _host(DiscoverCard(item: _person(), reason: SocialStrings.followsYou, onHide: () => hidden++)));
    await t.tap(find.byKey(DiscoverCard.hideKeyOf('kavya')));
    await settle(t);
    expect(hidden, 1);
    await drain(t);
  });

  testWidgets('rail: at most 5 small cards with short reasons, See all, no X', (t) async {
    installServer();
    var seeAll = 0;
    final people = [
      for (var i = 0; i < 7; i++)
        DiscoverPerson(
          person: SocialPerson(userId: 'p$i', name: 'Person $i', initial: 'P'),
          reason: const DiscoverReason(kind: DiscoverReasonKinds.mutual, mutualName: 'Aman', mutualCount: 3),
        ),
    ];
    await pumpSocial(t, Scaffold(body: ListView(children: [DiscoverRail(people: people, onSeeAll: () => seeAll++)])));
    expect(find.text(SocialStringsA.mayKnow), findsOneWidget);
    expect(find.byType(DiscoverCard), findsNWidgets(5));
    expect(find.text(SocialStrings.mutualCount(3)), findsWidgets);
    expect(find.byKey(DiscoverCard.hideKeyOf('p0')), findsNothing);
    await t.tap(find.byKey(DiscoverRail.seeAllKey));
    expect(seeAll, 1);
    await drain(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('rail: viewed name reads "Kavya follows"; empty list draws nothing', (t) async {
    installServer();
    final people = [
      const DiscoverPerson(
        person: SocialPerson(userId: 'p1', name: 'Priya', initial: 'P'),
        reason: DiscoverReason(kind: DiscoverReasonKinds.mutual, mutualName: 'Kavya', mutualCount: 1),
      ),
    ];
    await pumpSocial(t, Scaffold(body: ListView(children: [DiscoverRail(people: people, viewedName: 'Kavya', tinted: false), const DiscoverRail(people: [])])));
    expect(find.text('Kavya follows'), findsOneWidget);
    expect(find.byType(DiscoverRail), findsNWidgets(2));
    expect(find.text(SocialStringsA.mayKnow), findsOneWidget);
    await drain(t);
  });
}
