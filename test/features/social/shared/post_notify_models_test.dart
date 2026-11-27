import 'package:bakhli/features/buddy/notices/models/notice_models.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../b/social_b_test_kit.dart';
import 'social_test_support.dart';

SocialLimits _limits({bool isPlus = false, bool canUpgrade = true, int publicUsed = 0}) => SocialLimits.fromJson({
      ...socialMeJson()['limits'] as Map<String, dynamic>,
      'isPlus': isPlus,
      'canUpgrade': canUpgrade,
      'publicTrips': {'limit': isPlus ? 3 : 1, 'used': publicUsed},
    });

void main() {
  group('old answers never break: missing fields read as safe defaults', () {
    test('PublicTrip without the new fields: not full, no nearby, notified unknown', () {
      final t = PublicTrip.fromJson(publicTripJson());
      expect(t.requestsFull, isFalse);
      expect(t.notifyNearby, isFalse);
      expect(t.nearbyNotifiedAt, isNull);
      expect(t.notified, isNull);
      expect(t.removedByHost, isFalse);
      expect(t.fullForOthers, isFalse);
    });

    test('limits without notifyPosts / groupChat: 2 a week, group chat allowed (the server enforces)', () {
      final l = SocialLimits.fromJson(socialMeJson()['limits'] as Map<String, dynamic>);
      expect(l.notifiedPosts.limit, 2);
      expect(l.notifiedPosts.used, 0);
      expect(l.notifyResetsAt, isNull);
      expect(l.groupChat, isTrue);
      expect(SocialLimits.free.groupChat, isTrue);
      expect(SocialLimits.free.notifiedPosts.limit, 2);
      expect(l.publishes.limit, 4);
      expect(l.publishes.reached, isFalse);
      expect(l.publishNextAt, isNull);
    });

    test('MyProfile without notifyNearbyTrips reads ON (owner default)', () {
      expect(MyProfile.fromJson(myProfileJson()).notifyNearbyTrips, isTrue);
    });
  });

  group('new fields parse', () {
    test('PublicTrip: requestsFull, notifyNearby, nearbyNotifiedAt, notified', () {
      final t = PublicTrip.fromJson({
        ...publicTripJson(isMine: true),
        'requestsFull': true,
        'notifyNearby': true,
        'nearbyNotifiedAt': null,
        'notify': {'followers': 'weekLimit', 'nearby': 'weekLimit', 'used': 2, 'limit': 2},
      });
      expect(t.requestsFull, isTrue);
      expect(t.notifyNearby, isTrue);
      expect(t.notified, isFalse);
      expect(t.nearbyPending, isTrue);
      expect(t.fullForOthers, isFalse, reason: 'the host never sees his own post as Full');
      final sent = PublicTrip.fromJson({...publicTripJson(isMine: true), 'notifyNearby': true, 'nearbyNotifiedAt': '2026-11-28T01:30:00Z'});
      expect(sent.nearbyPending, isFalse);
    });

    test('Full for others: no seats left OR the most pending requests', () {
      expect(PublicTrip.fromJson({...publicTripJson(), 'requestsFull': true}).fullForOthers, isTrue);
      expect(PublicTrip.fromJson(publicTripJson(seatsLeft: 0)).fullForOthers, isTrue);
      expect(PublicTrip.fromJson(publicTripJson(seatsLeft: 2)).fullForOthers, isFalse);
    });

    test('a member the host removed reads myJoin removed', () {
      expect(PublicTrip.fromJson(publicTripJson(myJoin: 'removed')).removedByHost, isTrue);
    });

    test('copyWith keeps the new fields and can set requestsFull', () {
      final t = PublicTrip.fromJson({...publicTripJson(), 'notify': {'followers': 'sent', 'nearby': 'queued', 'used': 1, 'limit': 2}});
      final c = t.copyWith(requestsFull: true);
      expect(c.requestsFull, isTrue);
      expect(c.notifyNearby, isTrue);
      expect(c.notified, isTrue);
      expect(t.copyWith(myJoin: 'requested').requestsFull, isFalse);
    });

    test('limits: notifyPosts with notifyNextAt, groupChat false', () {
      final l = SocialLimits.fromJson({
        ...socialMeJson()['limits'] as Map<String, dynamic>,
        'notifyPosts': {'limit': 2, 'used': 2},
        'notifyNextAt': '2026-12-02T04:00:00Z',
        'groupChat': false,
      });
      expect(l.notifiedPosts.reached, isTrue);
      expect(l.notifyResetsAt, DateTime.utc(2026, 12, 2, 4));
      expect(l.groupChat, isFalse);
    });

    test('MyProfile: notifyNearbyTrips false is kept through withNameChangeAllowedAt', () {
      final p = MyProfile.fromJson({...myProfileJson(), 'notifyNearbyTrips': false});
      expect(p.notifyNearbyTrips, isFalse);
      expect(p.withNameChangeAllowedAt(null).notifyNearbyTrips, isFalse);
    });
  });

  group('create / publish answer: notify', () {
    PublicTrip of(Map<String, dynamic> notify) => PublicTrip.fromJson({...publicTripJson(isMine: true), 'notify': notify});

    test('followers sent, nearby queued: notified, nearby ON', () {
      final t = of({'followers': 'sent', 'nearby': 'queued', 'used': 1, 'limit': 2});
      expect(t.notified, isTrue);
      expect(t.notifyNearby, isTrue);
    });

    test('weekly limit used: notified false, nearby not queued', () {
      final t = of({'followers': 'weekLimit', 'nearby': 'weekLimit', 'used': 2, 'limit': 2, 'nextAllowedAt': '2026-12-01T06:00:00Z'});
      expect(t.notified, isFalse);
      expect(t.notifyNearby, isFalse);
      expect(PostNotifyResult.of({'followers': 'weekLimit', 'nearby': 'off', 'nextAllowedAt': '2026-12-01T06:00:00Z'})!.nextAllowedAt, DateTime.utc(2026, 12, 1, 6));
    });

    test('nothing to say (no followers, toggle off, an edit): notified unknown, never the used-up line', () {
      expect(of({'followers': 'none', 'nearby': 'off'}).notified, isNull);
      expect(of({'followers': 'alreadySent', 'nearby': 'alreadySent'}).notified, isNull);
    });

    test('nearby refused for a private profile or a far start while followers were told: notified, nearby OFF', () {
      final t = of({'followers': 'sent', 'nearby': 'private'});
      expect(t.notified, isTrue);
      expect(t.notifyNearby, isFalse);
    });
  });

  group('post entry hint (SPEC 9)', () {
    test('Free at the live post cap with payment ON: Free limit reached. Get Plus.', () {
      final l = _limits(publicUsed: 1);
      expect(l.postNeedsPlus, isTrue);
      expect(SocialStringsB.postEntryHint(l), 'Free limit reached. Get Plus.');
    });

    test('below the cap, or limits not loaded: no hint, the invitation line stays', () {
      expect(SocialStringsB.postEntryHint(_limits()), '');
      expect(SocialStringsB.postEntryHint(null), '');
    });

    test('Plus at its cap, or payment OFF (cannot upgrade): a plain live-post line, never a Plus promise', () {
      expect(SocialStringsB.postEntryHint(_limits(isPlus: true, publicUsed: 3)), '3 live posts. Remove one to post again.');
      expect(SocialStringsB.postEntryHint(_limits(canUpgrade: false, publicUsed: 1)), '1 live post. Remove it to post again.');
    });
  });

  test('copy is short professional English with no tip clutter', () {
    for (final s in [
      SocialStringsB.notifyNearby,
      SocialStringsB.notifyUsedUp,
      SocialStringsB.notifyUsedUpPosted,
      SocialStringsB.nearbyTomorrow,
      SocialStringsB.freeLimitHint,
      SocialStringsB.cannotRejoin,
      SocialStringsB.requestsFullNow,
      SocialStringsB.publishLimit(null),
    ]) {
      expect(s.length, lessThanOrEqualTo(80), reason: s);
      expect(s.toLowerCase(), isNot(contains('tip')), reason: s);
    }
    expect(SocialStringsB.notifyNearby, 'Notify travellers near me');
    expect(SocialStringsB.cannotRejoin, 'You can no longer join this trip');
  });

  test('new bell kinds are known social kinds', () {
    expect(NoticeKinds.known(NoticeKinds.nearbyPosted), isTrue);
    expect(NoticeKinds.social, contains(NoticeKinds.nearbyPosted));
    expect(NoticeKinds.nearbyPosted, 'NearbyPosted');
  });
}
