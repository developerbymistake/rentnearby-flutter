import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/utils/dio_error_mapper.dart';
import 'package:dio/dio.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/b/feed/travel_buddies_screen.dart';
import 'package:bakhli/features/social/b/post/trip_post_screen.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/shared/post_removal.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:bakhli/features/social/shared/widgets/public_trip_card.dart';
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

Map<String, dynamic> _mine() => {
      ...publicTripJson(id: 'mine-1', ownerId: 'me', ownerName: 'Rahul Verma', cities: ['Manali'], isMine: true, waitingRequests: 0),
      'unlocksAt': DateTime.now().toUtc().add(const Duration(hours: 50)).toIso8601String(),
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

  group('I-3 rules: no 72-hour lock, delete waits for the other travellers', () {
    test('any trip with other travellers is blocked, ended or not; alone is free', () {
      expect(PostRemovalRule.forDelete(otherMembers: 0), isNull);
      final b = PostRemovalRule.forDelete(otherMembers: 2);
      expect(b, isA<MembersFirstBlock>());
      expect(b!.line, 'Remove the other travellers first (2)');
    });

    test('only RemoveMembersFirst is a removal block', () {
      final members = PostRemovalBlock.fromRefusal('RemoveMembersFirst', {'count': 3});
      expect(members!.line, 'Remove the other travellers first (3)');
      expect(PostRemovalBlock.fromRefusal('TripFull', const {}), isNull);
      expect(PostRemovalBlock.fromResult(const BuddyOffline<void>()), isNull);
      for (final line in [SocialStrings.removeMembersFirstLine(2), SocialStrings.removeMembersFirstLine(0)]) {
        expect(line, isNot(endsWith('.')));
      }
    });

    test('My Trips delete (Dio path): a RemoveMembersFirst answer becomes the calm block, not a raw toast', () {
      DioException err(Map<String, dynamic> body) {
        final o = RequestOptions(path: '/trips/t1');
        return DioException(requestOptions: o, response: Response(requestOptions: o, statusCode: 409, data: body), type: DioExceptionType.badResponse);
      }

      final members = PostRemovalBlock.fromError(err({'error': {'type': 'RemoveMembersFirst', 'message': 'Remove the other travellers first.'}, 'data': {'count': 2}}));
      expect(members, isA<MembersFirstBlock>());
      expect((members as MembersFirstBlock).count, 2);
      expect(PostRemovalBlock.fromError(err({'error': {'type': 'TripNotFound', 'message': 'x'}})), isNull);
      expect(DioErrorMapper.errorData(err({'error': {'type': 'X'}})), isEmpty);
      expect(PostRemovalBlock.fromError(Exception('boom')), isNull);
    });
  });

  group('I-3: no Remove from Travel buddies option', () {
    testWidgets('feed: my own post card has no menu, even when an older answer still sends unlocksAt', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', _feed, _page(mine: [_mine()]));
      await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
      expect(find.text(SocialStringsB.yourPost), findsOneWidget);
      expect(find.byKey(PublicTripCard.menuKey), findsNothing);
      expect(find.textContaining('remove this post'), findsNothing);
      await drain(t);
      expect(t.takeException(), isNull);
    });

    testWidgets('post page: my own post has no menu and no lock line', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', _post, _mine());
      await pumpSocial(t, const TripPostScreen(tripId: 'mine-1'), pages: _pages);
      expect(find.byKey(TripPostScreen.menuKey), findsNothing);
      expect(find.textContaining('remove this post'), findsNothing);
      expect(find.textContaining('3 days'), findsNothing);
      await drain(t);
    });

    testWidgets('post page of someone else: report and block stay', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', '/social/trips/p-1', publicTripJson(id: 'p-1'));
      await pumpSocial(t, const TripPostScreen(tripId: 'p-1'), pages: _pages);
      await t.tap(find.byKey(TripPostScreen.menuKey));
      await settle(t);
      expect(find.text(SocialStringsB.reportTrip), findsOneWidget);
      expect(find.textContaining('Block '), findsOneWidget);
      await drain(t);
    });
  });
}
