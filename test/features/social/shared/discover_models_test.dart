import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/shared/social_error_types.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscoverPage.fromJson', () {
    test('reads items, reason, cursor and the same-trip header', () {
      final page = DiscoverPage.fromJson({
        'items': [
          {
            'userId': 'u1',
            'name': 'Kavya',
            'username': 'kavya.hills',
            'initial': 'K',
            'photoUrl': null,
            'level': 3,
            'followsMe': false,
            'iFollow': false,
            'followRequested': false,
            'isPrivate': true,
            'reason': {'kind': 'sameTrip', 'cityName': 'Manali', 'month': 202612},
          },
        ],
        'nextCursor': 'abc',
        'myTrip': {'cityName': 'Manali', 'month': 202612},
      });
      expect(page.items, hasLength(1));
      final p = page.items.single;
      expect(p.userId, 'u1');
      expect(p.person.level, 3);
      expect(p.isPrivate, isTrue);
      expect(p.reason.kind, DiscoverReasonKinds.sameTrip);
      expect(p.reason.month, 202612);
      expect(page.hasMore, isTrue);
      expect(page.myTrip!.cityName, 'Manali');
    });

    test('no cursor and no header', () {
      final page = DiscoverPage.fromJson({'items': [], 'nextCursor': null});
      expect(page.hasMore, isFalse);
      expect(page.myTrip, isNull);
    });

    test('copyWith flips only the follow state', () {
      final p = DiscoverPerson.fromJson({'userId': 'u2', 'name': 'Rohit', 'followsMe': true, 'reason': {'kind': 'followsYou'}});
      final r = p.copyWith(followRequested: true);
      expect(r.followRequested, isTrue);
      expect(r.iFollow, isFalse);
      expect(r.followsMe, isTrue);
      expect(r.reason.kind, DiscoverReasonKinds.followsYou);
    });
  });

  group('reason lines', () {
    String line(Map<String, dynamic> j) => SocialStringsA.reasonLine(DiscoverReason.fromJson(j));

    test('full lines of the mock', () {
      expect(line({'kind': 'sameTrip', 'cityName': 'Manali', 'month': 202612}), 'Going to Manali in Dec, like you');
      expect(line({'kind': 'mutual', 'mutualName': 'Aman', 'mutualCount': 4}), 'Followed by Aman + 3 others');
      expect(line({'kind': 'mutual', 'mutualName': 'Aman', 'mutualCount': 1}), 'Followed by Aman');
      expect(line({'kind': 'mutual', 'mutualCount': 4}), 'Followed by 4 people you follow');
      expect(line({'kind': 'near', 'tags': ['Treks', 'Camping']}), 'Near you · Treks, Camping');
      expect(line({'kind': 'travelledWith', 'cityName': 'Rishikesh'}), 'Travelled with you · Rishikesh');
      expect(line({'kind': 'followsYou'}), SocialStrings.followsYou);
      expect(line({'kind': 'interests', 'tags': ['Treks', 'Camping']}), 'Treks, Camping');
    });

    test('short lines and headers', () {
      expect(SocialStringsA.reasonShort(const DiscoverReason(kind: 'sameTrip', cityName: 'Manali')), 'Also Manali');
      expect(SocialStringsA.reasonShort(const DiscoverReason(kind: 'mutual', mutualCount: 3)), '3 mutual');
      expect(SocialStringsA.reasonShort(const DiscoverReason(kind: 'mutual', mutualCount: 3), viewedName: 'Kavya'), 'Kavya follows');
      expect(SocialStringsA.alsoGoingTo('Manali', 202612), 'ALSO GOING TO MANALI · DEC');
      expect(SocialStringsA.cityMonth('Manali', 202612), 'Manali · Dec');
      expect(SocialStringsA.youFollowLine('Kavya', 'Female'), 'You follow Kavya. Travellers like her:');
      expect(SocialStringsA.youFollowLine('Kavya', null), 'You follow Kavya. Travellers like them:');
    });
  });

  test('the limit message has no number or date', () {
    expect(SocialErrorTypes.tryLater, 'TryLater');
    expect(SocialStrings.tryLaterTitle, 'Try again later');
    expect(SocialStrings.tryLaterLine, 'We limit some actions to keep Bakhli safe.');
    expect(RegExp(r'\d').hasMatch(SocialStrings.tryLaterLine), isFalse);
  });
}
