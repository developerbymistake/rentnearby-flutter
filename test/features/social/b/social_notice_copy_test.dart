import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/buddy/notices/models/notice_models.dart';
import 'package:bakhli/features/buddy/notices/notice_copy.dart';
import 'package:bakhli/features/buddy/notices/widgets/notice_row.dart';
import 'package:bakhli/features/buddy/notices/widgets/social_notice_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';

Notice _n(String kind, {String? tripId, String? tripTitle = 'Manali trip', String? tripCity = 'Manali', String? refId, String? preview, bool read = false, int count = 1}) => Notice.fromJson({
      'id': 'n-$kind',
      'kind': kind,
      'tripId': tripId,
      'tripTitle': tripTitle,
      'tripCity': tripCity,
      'actorUserId': 'rohan',
      'actorName': 'Rohan M.',
      'refId': refId,
      'actorPhotoUrl': null,
      'actorUsername': 'Bakhli#52190466',
      'preview': preview,
      'count': count,
      'createdAt': '2026-11-26T10:00:00Z',
      'updatedAt': '2026-11-26T10:00:00Z',
      'isRead': read,
    });

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);

  test('all eight social kinds are known (NearbyPosted added for the 07:00 digest)', () {
    expect(NoticeKinds.social, hasLength(8));
    for (final k in NoticeKinds.social) {
      expect(NoticeKinds.known(k), isTrue, reason: k);
    }
  });

  final cases = <(Notice, String, String, String, Map<String, dynamic>)>[
    (_n(NoticeKinds.followRequest), 'Rohan M. wants to follow you', '', AppRoutes.people, {'tab': 'requests'}),
    (_n(NoticeKinds.newFollower), 'Rohan M. started following you', '', AppRoutes.traveller, {'userId': 'rohan'}),
    (_n(NoticeKinds.followAccepted), 'Rohan M. accepted your follow request', '', AppRoutes.traveller, {'userId': 'rohan'}),
    (
      _n(NoticeKinds.joinRequest, tripId: 'trip-1', refId: 'jr-1', preview: 'Same plan here, happy to split the cab'),
      'Rohan M. asked to join your Manali trip',
      '“Same plan here, happy to split the cab”',
      AppRoutes.joinRequests,
      {'tripId': 'trip-1'},
    ),
    (_n(NoticeKinds.joinAccepted, tripId: 'trip-2', tripTitle: 'Rishikesh trip', tripCity: 'Rishikesh'), 'Rohan M. accepted you on Rishikesh', 'You are in. It is in My Trips.', AppRoutes.tripView, {'tripId': 'trip-2'}),
    (_n(NoticeKinds.joinDeclined, tripId: 'trip-3'), 'Not this time for Manali', '', AppRoutes.travelBuddies, <String, dynamic>{}),
    (_n(NoticeKinds.followedPosted, tripId: 'trip-4', tripTitle: 'Spiti trip', tripCity: 'Spiti'), 'Rohan M. posted a trip to Spiti', '', AppRoutes.tripPost, {'tripId': 'trip-4'}),
    (_n(NoticeKinds.nearbyPosted, tripId: 'trip-5'), 'Rohan M. posted a trip near you', '', AppRoutes.tripPost, {'tripId': 'trip-5'}),
    (_n(NoticeKinds.nearbyPosted, tripId: null, count: 3), '3 new trips near you', '', AppRoutes.travelBuddies, <String, dynamic>{}),
  ];

  for (final (n, line, preview, route, args) in cases) {
    test('${n.kind}: line, preview, route and args', () {
      final v = NoticeCopy.of(n)!;
      expect(v.social, isTrue);
      expect(v.title, line);
      expect(v.body, preview);
      expect(v.route, route);
      expect(v.args, args);
    });
  }

  test('social rows carry the trip city so the row can show it bold', () {
    expect(NoticeCopy.of(_n(NoticeKinds.joinRequest, tripId: 't'))!.place, 'Manali');
    expect(NoticeCopy.of(_n(NoticeKinds.followRequest))!.place, isNull);
  });

  test('a join request with no trip city still reads well', () {
    expect(NoticeCopy.of(_n(NoticeKinds.joinRequest, tripId: 't', tripTitle: null, tripCity: null))!.title, 'Rohan M. asked to join your trip');
  });

  test('the default trip title never doubles the word trip', () {
    for (final k in [NoticeKinds.joinRequest, NoticeKinds.joinAccepted, NoticeKinds.joinDeclined, NoticeKinds.followedPosted]) {
      expect(NoticeCopy.of(_n(k, tripId: 't'))!.title, isNot(contains('trip trip')), reason: k);
    }
  });

  testWidgets('a social row has no buttons: avatar, line, grey preview, time, unread dot; a tap opens', (t) async {
    Get.reset();
    var taps = 0;
    final n = _n(NoticeKinds.joinRequest, tripId: 'trip-1', refId: 'jr-1', preview: 'Same plan here');
    await pumpSocial(
      t,
      Scaffold(body: ListView(children: [NoticeRow(notice: n, now: DateTime.utc(2026, 11, 26, 10, 2), onTap: () => taps++)])),
    );
    expect(find.byType(SocialNoticeCard), findsOneWidget);
    expect(find.textContaining('asked to join your Manali trip', findRichText: true), findsOneWidget);
    final rich = t.widgetList<RichText>(find.byType(RichText)).firstWhere((r) => r.text.toPlainText().contains('asked to join your Manali trip'));
    final spans = <TextSpan>[];
    rich.text.visitChildren((s) {
      if (s is TextSpan && s.text != null) spans.add(s);
      return true;
    });
    expect(spans.firstWhere((s) => s.text == 'Manali').style?.fontWeight, FontWeight.w600);
    expect(spans.firstWhere((s) => s.text == 'Rohan M.').style?.fontWeight, FontWeight.w600);
    expect(find.text('“Same plan here”'), findsOneWidget);
    expect(find.text('2 min ago'), findsOneWidget);
    expect(find.byKey(SocialNoticeCard.dotKey), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Decline'), findsNothing);
    await t.tap(find.byType(SocialNoticeCard));
    expect(taps, 1);
    Get.reset();
  });

  testWidgets('a read social row has no dot', (t) async {
    Get.reset();
    final n = _n(NoticeKinds.newFollower, read: true);
    await pumpSocial(t, Scaffold(body: ListView(children: [NoticeRow(notice: n, onTap: () {})])));
    expect(find.byKey(SocialNoticeCard.dotKey), findsNothing);
    Get.reset();
  });
}
