import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/utils/dio_error_mapper.dart';
import 'package:dio/dio.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/shared/widgets/menu_row.dart';
import 'package:bakhli/features/social/b/feed/travel_buddies_screen.dart';
import 'package:bakhli/features/social/b/post/trip_post_screen.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/shared/post_removal.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:bakhli/features/social/shared/widgets/public_trip_card.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

final _pages = [
  GetPage(name: AppRoutes.tripPost, page: () => Scaffold(body: Text('POST ${(Get.arguments as Map)['tripId']}'))),
  GetPage(name: AppRoutes.joinRequests, page: () => Scaffold(body: Text('REQUESTS ${(Get.arguments as Map)['tripId']}'))),
  GetPage(name: AppRoutes.postTrip, page: () => const Scaffold(body: Text('WIZARD'))),
  GetPage(name: AppRoutes.travelBuddies, page: () => const Scaffold(body: Text('FEED'))),
];

const _feed = '/social/trips/feed';
const _post = '/social/trips/mine-1';
const _unpublish = '/social/trips/mine-1/post';

Map<String, dynamic> _mine({DateTime? unlocksAt}) => {
      ...publicTripJson(id: 'mine-1', ownerId: 'me', ownerName: 'Rahul Verma', cities: ['Manali'], isMine: true, waitingRequests: 0),
      if (unlocksAt != null) 'unlocksAt': unlocksAt.toIso8601String(),
    };

Map<String, dynamic> _page({List<Map<String, dynamic>> mine = const []}) => {'mine': mine, 'items': <Object>[], 'nextCursor': null};

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
  });
  tearDown(Get.reset);

  final later = DateTime.now().toUtc().add(const Duration(hours: 50));

  group('models and rules', () {
    test('PublicTrip reads unlocksAt for the own post; a passed moment or someone else\'s post never locks', () {
      final now = DateTime.utc(2026, 11, 27, 10);
      final mine = PublicTrip.fromJson({..._mine(), 'unlocksAt': '2026-11-29T10:00:00Z'});
      expect(mine.unlocksAt, DateTime.utc(2026, 11, 29, 10));
      expect(mine.lockedUntil(now: now), DateTime.utc(2026, 11, 29, 10));
      expect(mine.lockedUntil(now: DateTime.utc(2026, 11, 29, 10)), isNull, reason: '72:00 is free');
      expect(mine.lockedUntil(now: DateTime.utc(2026, 11, 29, 9, 59)), isNotNull, reason: '71:59 is locked');
      final other = PublicTrip.fromJson({...publicTripJson(), 'unlocksAt': '2026-11-29T10:00:00Z'});
      expect(other.lockedUntil(now: now), isNull);
    });

    test('an older answer without the new fields never blocks', () {
      expect(PublicTrip.fromJson(_mine()).unlocksAt, isNull);
      expect(PostRemovalRule.lockOnly(null), isNull);
      expect(PostRemovalRule.forDelete(posted: true, otherMembers: 0, ended: false), isNull);
      final t = TripModel.fromJson({'id': 't', 'cityKey': 1, 'plan': <String, dynamic>{}});
      expect(t.postUnlocksAt, isNull);
      expect(t.deleteNeedsAlone, isFalse);
    });

    test('TripModel and the My Trips row read postUnlocksAt and deleteNeedsAlone from owner answers', () {
      final t = TripModel.fromJson({'id': 't', 'cityKey': 1, 'plan': <String, dynamic>{}, 'postUnlocksAt': '2026-11-29T10:00:00Z', 'deleteNeedsAlone': true});
      expect(t.postUnlocksAt!.toUtc(), DateTime.utc(2026, 11, 29, 10));
      expect(t.deleteNeedsAlone, isTrue);
      final row = TripSummaryModel.fromJson({'id': 't', 'postUnlocksAt': '2026-11-29T10:00:00Z', 'deleteNeedsAlone': true});
      expect(row.postUnlocksAt!.toUtc(), DateTime.utc(2026, 11, 29, 10));
      expect(row.deleteNeedsAlone, isTrue);
      expect(TripSummaryModel.fromJson({'id': 't'}).postUnlocksAt, isNull);
      expect(TripSummaryModel.fromJson({'id': 't'}).deleteNeedsAlone, isFalse);
    });

    test('typed refusals map to the calm lines; other errors are not removal blocks', () {
      final locked = PostRemovalBlock.fromRefusal('PostLocked', {'unlocksAt': '2026-11-29T10:00:00Z'});
      expect(locked, isA<PostLockedBlock>());
      expect((locked as PostLockedBlock).unlocksAt, DateTime.utc(2026, 11, 29, 10));
      expect(locked.line, startsWith('You can remove this post on '));
      final members = PostRemovalBlock.fromRefusal('RemoveMembersFirst', {'count': 3});
      expect(members!.line, 'Remove the other travellers first (3)');
      expect(PostRemovalBlock.fromRefusal('TripFull', const {}), isNull);
      expect(PostRemovalBlock.fromResult(const BuddyOffline<void>()), isNull);
      expect(PostRemovalBlock.fromRefusal('PostLocked', const {})!.line, SocialStrings.postLockedLine(null));
      // The notice adds the full stop itself: no line may end with one (no "posting..").
      for (final line in [SocialStrings.postLockedLine(null), SocialStrings.postLockedLine(DateTime(2026, 11, 30, 16, 5)), SocialStrings.removeMembersFirstLine(2), SocialStrings.removeMembersFirstLine(0)]) {
        expect(line, isNot(endsWith('.')));
      }
    });

    test('My Trips delete (Dio path): a RemoveMembersFirst or PostLocked answer becomes the calm block, not a raw toast', () {
      DioException err(Map<String, dynamic> body) {
        final o = RequestOptions(path: '/trips/t1');
        return DioException(requestOptions: o, response: Response(requestOptions: o, statusCode: 409, data: body), type: DioExceptionType.badResponse);
      }

      final members = PostRemovalBlock.fromError(err({'error': {'type': 'RemoveMembersFirst', 'message': 'Remove the other travellers first.'}, 'data': {'count': 2}}));
      expect(members, isA<MembersFirstBlock>());
      expect((members as MembersFirstBlock).count, 2);
      final locked = PostRemovalBlock.fromError(err({'error': {'type': 'PostLocked', 'message': 'x'}, 'data': {'unlocksAt': '2026-11-29T10:00:00Z'}}));
      expect((locked as PostLockedBlock).unlocksAt, DateTime.utc(2026, 11, 29, 10));
      expect(PostRemovalBlock.fromError(err({'error': {'type': 'TripNotFound', 'message': 'x'}})), isNull);
      expect(DioErrorMapper.errorData(err({'error': {'type': 'X'}})), isEmpty);
      expect(PostRemovalBlock.fromError(Exception('boom')), isNull);
    });

    test('the unlock moment reads weekday, date and time in the phone time zone', () {
      final at = DateTime(2026, 11, 30, 16, 5);
      expect(SocialStrings.postLockedLine(at), 'You can remove this post on Mon 30 Nov, 4:05 pm');
    });
  });

  group('feed own post', () {
    testWidgets('UC40 locked: Remove stays visible, greyed with the unlock line; a tap explains and sends nothing', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', _feed, _page(mine: [_mine(unlocksAt: later)]));
      server.on('DELETE', _unpublish, {});
      await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
      await t.tap(find.byKey(PublicTripCard.menuKey));
      await settle(t);
      expect(find.text(SocialStringsB.removePost), findsOneWidget);
      final row = t.widget<MenuRow>(find.ancestor(of: find.text(SocialStringsB.removePost), matching: find.byType(MenuRow)));
      expect(row.grey, isTrue);
      expect(row.danger, isFalse);
      expect(row.subtitle, SocialStrings.postLockedLine(later));
      await t.tap(find.text(SocialStringsB.removePost));
      await settle(t);
      expect(find.text(SocialStrings.postLockedTitle), findsOneWidget);
      expect(find.text(SocialStrings.postLockedEditNote), findsOneWidget);
      expect(server.calls('DELETE', _unpublish), isEmpty);
      expect(find.text(SocialStringsB.yourPost), findsOneWidget);
      await drain(t);
      expect(t.takeException(), isNull);
    });

    testWidgets('a late PostLocked refusal keeps the post, explains, and greys the item next time', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', _feed, _page(mine: [_mine()]));
      server.refuse('DELETE', _unpublish, status: 409, type: 'PostLocked', message: 'You can remove this post after 3 days.', data: {'unlocksAt': later.toIso8601String()});
      await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
      await t.tap(find.byKey(PublicTripCard.menuKey));
      await settle(t);
      await t.tap(find.text(SocialStringsB.removePost));
      await settle(t);
      expect(server.calls('DELETE', _unpublish), hasLength(1));
      expect(find.text(SocialStrings.postLockedTitle), findsOneWidget);
      expect(find.text('${SocialStrings.postLockedLine(later)}.'), findsOneWidget);
      await t.tap(find.text('Close').last);
      await settle(t);
      expect(find.text(SocialStringsB.yourPost), findsOneWidget);
      await t.tap(find.byKey(PublicTripCard.menuKey));
      await settle(t);
      final row = t.widget<MenuRow>(find.ancestor(of: find.text(SocialStringsB.removePost), matching: find.byType(MenuRow)));
      expect(row.grey, isTrue);
      await drain(t);
    });

    testWidgets('unlocked: Remove works as before', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', _feed, _page(mine: [_mine(unlocksAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)))]));
      server.on('DELETE', _unpublish, {});
      await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
      await t.tap(find.byKey(PublicTripCard.menuKey));
      await settle(t);
      server.on('GET', _feed, _page());
      await t.tap(find.text(SocialStringsB.removePost));
      await settle(t);
      expect(server.calls('DELETE', _unpublish), hasLength(1));
      expect(find.text(SocialStringsB.yourPost), findsNothing);
      await drain(t);
    });

    testWidgets('another refusal is no longer silent: its message shows', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', _feed, _page(mine: [_mine()]));
      server.refuse('DELETE', _unpublish, status: 409, type: 'Something', message: 'Could not remove the post.');
      await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
      await t.tap(find.byKey(PublicTripCard.menuKey));
      await settle(t);
      await t.tap(find.text(SocialStringsB.removePost));
      await settle(t);
      expect(find.text('Could not remove the post.'), findsOneWidget);
      await drain(t);
    });
  });

  group('post page', () {
    testWidgets('UC40 locked: the menu item is greyed with the unlock line; a tap explains and the page stays', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', _post, _mine(unlocksAt: later));
      server.on('DELETE', _unpublish, {});
      await pumpSocial(t, const TripPostScreen(tripId: 'mine-1'), pages: _pages);
      await t.tap(find.byKey(TripPostScreen.menuKey));
      await settle(t);
      expect(find.text(SocialStrings.postLockedLine(later)), findsOneWidget);
      await t.tap(find.text(SocialStringsB.removePost));
      await settle(t);
      expect(find.text(SocialStrings.postLockedTitle), findsOneWidget);
      expect(server.calls('DELETE', _unpublish), isEmpty);
      await drain(t);
    });

    testWidgets('a late PostLocked refusal over REST shows the same line and the page stays', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', _post, _mine());
      server.refuse('DELETE', _unpublish, status: 409, type: 'PostLocked', data: {'unlocksAt': later.toIso8601String()});
      await pumpSocial(t, const TripPostScreen(tripId: 'mine-1'), pages: _pages);
      await t.tap(find.byKey(TripPostScreen.menuKey));
      await settle(t);
      await t.tap(find.text(SocialStringsB.removePost));
      await settle(t);
      expect(server.calls('DELETE', _unpublish), hasLength(1));
      expect(find.text('${SocialStrings.postLockedLine(later)}.'), findsOneWidget);
      expect(find.text(SocialStringsB.postRemoved), findsNothing);
      await drain(t);
    });
  });
}
