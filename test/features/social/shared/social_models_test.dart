import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'social_test_support.dart';

void main() {
  test('SocialPerson parses and falls back to the first letter for initial', () {
    final p = SocialPerson.fromJson({'userId': 'u1', 'name': 'kavya sharma', 'username': 'Bakhli#1', 'photoUrl': '  ', 'initial': ''});
    expect(p.userId, 'u1');
    expect(p.initial, 'K');
    expect(p.photoUrl, isNull);
    expect(p.shortName, 'kavya S.');
    expect(p.asBuddyPerson.userId, 'u1');
    expect(p.gender, '');
    expect(SocialPerson.fromJson({'userId': 'u2', 'name': 'Aman', 'gender': 'Male'}).gender, 'Male');
  });

  test('every model survives an empty or wrong-typed map', () {
    expect(SocialPerson.fromJson(const {}).name, '');
    expect(PersonRow.fromJson(const {'mutualCount': 'x', 'followsMe': 'true'}).followsMe, isTrue);
    expect(PersonRow.fromJson(const {'mutualCount': 'x'}).mutualCount, 0);
    expect(Mutuals.fromJson(null).isEmpty, isTrue);
    expect(TripWhen.fromJson(null).kind, TripWhen.within);
    expect(PublicTrip.fromJson(const {}).myJoin, 'none');
    expect(SocialLimits.fromJson(null).newChats.limit, 3);
    expect(ChatUnread.fromJson(const {'total': 4}).total, 4);
    expect(SocialCatalogData.fromJson(null).interests, isEmpty);
    expect(MyProfile.fromJson(const {}).messagePolicy, 'Everyone');
    expect(TravellerProfile.fromJson(const {}).mutuals.isEmpty, isTrue);
    expect(SocialMe.fromJson(const {}).profile, isNull);
  });

  test('SocialMe reads profile, counters, limits, counts and catalog', () {
    final me = SocialMe.fromJson(socialMeJson(profile: myProfileJson()));
    expect(me.profile!.followers, 128);
    expect(me.profile!.buddies, 6);
    expect(me.profile!.birthYear, 1998);
    expect(me.limits.newChats.used, 1);
    expect(me.limits.newChats.left, 2);
    expect(me.limits.resetsAt, DateTime.utc(2026, 12, 1));
    expect(me.followRequests, 2);
    expect(me.chatUnread.requests, 2);
    expect(me.catalog.skills, contains('First aid'));
  });

  test('TravellerProfile reads relation and mutuals; copyWith keeps canAddBuddy in step', () {
    final t = TravellerProfile.fromJson(travellerJson(followsMe: true));
    expect(t.followsMe, isTrue);
    expect(t.canAddBuddy, isTrue);
    expect(t.mutuals.names, ['Aman']);
    final buddy = t.copyWith(isBuddy: true);
    expect(buddy.isBuddy, isTrue);
    expect(buddy.canAddBuddy, isFalse);
  });

  test('PersonRow copyWith only changes the named flags', () {
    final r = PersonRow.fromJson(rowJson('a', 'Aman Kumar', mutualCount: 2, mutualName: 'Rohan'));
    final c = r.copyWith(iFollow: true);
    expect(c.iFollow, isTrue);
    expect(c.followsMe, r.followsMe);
    expect(c.mutualCount, 2);
    expect(c.mutualName, 'Rohan');
  });

  test('PublicTrip parses when, mutuals and copyWith', () {
    final t = PublicTrip.fromJson({
      'tripId': 't1',
      'owner': personJson('o', 'Neha Pant'),
      'when': {'kind': 'month', 'month': 202701},
      'days': 11,
      'seats': 11,
      'seatsLeft': 5,
      'mutuals': {'count': 2, 'names': ['Aman'], 'photoUrls': ['x']},
      'waitingRequests': 3,
    });
    expect(t.when.kind, TripWhen.monthKind);
    expect(t.when.month, 202701);
    expect(t.mutuals.count, 2);
    expect(t.copyWith(myJoin: 'requested').myJoin, 'requested');
    expect(t.copyWith(myJoin: 'requested').waitingRequests, 3);
  });

  test('LimitUse never reports a negative left', () {
    const u = LimitUse(limit: 1, used: 3);
    expect(u.left, 0);
    expect(u.reached, isTrue);
  });

  test('MyProfile reads the name lock date (nameChangeAllowedAt or nextAllowedAt) and tells when it is locked', () {
    final now = DateTime.utc(2026, 11, 27, 12);
    final a = MyProfile.fromJson(const {'nameChangeAllowedAt': '2026-12-11T00:00:00Z'});
    expect(a.nameChangeAllowedAt, DateTime.utc(2026, 12, 11));
    expect(a.nameLockedAt(now), isTrue);
    expect(a.nameLockedAt(DateTime.utc(2026, 12, 12)), isFalse);
    expect(MyProfile.fromJson(const {'nextAllowedAt': '2026-12-11T00:00:00Z'}).nameChangeAllowedAt, DateTime.utc(2026, 12, 11));
    final none = MyProfile.fromJson(const {});
    expect(none.nameChangeAllowedAt, isNull);
    expect(none.nameLockedAt(now), isFalse);
    final locked = none.withNameChangeAllowedAt(DateTime.utc(2026, 12, 1));
    expect(locked.nameLockedAt(now), isTrue);
    expect(locked.messagePolicy, none.messagePolicy);
  });
}
