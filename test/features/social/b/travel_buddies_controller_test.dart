import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/b/data/public_trips_api.dart';
import 'package:bakhli/features/social/b/feed/travel_buddies_controller.dart';
import 'package:bakhli/features/social/shared/social_live.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'social_b_test_kit.dart';

class _Api extends PublicTripsApi {
  final Map<String?, FeedPage> pages = {};
  final List<String?> cursors = [];

  @override
  Future<BuddyResult<FeedPage>> feed({String? cursor, String? q, String who = 'any', bool near = false, double? lat, double? lng}) async {
    cursors.add(cursor);
    return BuddyOk(pages[cursor] ?? const FeedPage());
  }
}

PublicTrip _trip(String id, {String myJoin = 'none', int seatsLeft = 2}) => PublicTrip.fromJson(publicTripJson(id: id, myJoin: myJoin, seatsLeft: seatsLeft));

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  tearDown(() {
    SocialLive.reset();
    Get.reset();
  });

  test('a join request tick refreshes page 1 in place and keeps the pages already scrolled', () async {
    final api = _Api()
      ..pages[null] = FeedPage(items: [_trip('a'), _trip('b')], nextCursor: 'p2')
      ..pages['p2'] = FeedPage(items: [_trip('c'), _trip('d')]);
    final c = Get.put(TravelBuddiesController(api: api));
    await _settle();
    await c.loadMore();
    expect(c.items.map((t) => t.tripId), ['a', 'b', 'c', 'd']);
    api.pages[null] = FeedPage(items: [_trip('a', myJoin: 'requested', seatsLeft: 1), _trip('b')], nextCursor: 'p2');
    SocialLive.joinRequests.value++;
    await _settle();
    expect(c.items.map((t) => t.tripId), ['a', 'b', 'c', 'd']);
    expect(c.items.first.myJoin, 'requested');
    expect(c.items.first.seatsLeft, 1);
    expect(c.hasMore, isFalse);
    expect(api.cursors, [null, 'p2', null]);
  });

  test('my own new post still reloads the whole feed', () async {
    final api = _Api()..pages[null] = FeedPage(items: [_trip('a')], nextCursor: 'p2');
    final c = Get.put(TravelBuddiesController(api: api));
    await _settle();
    api.pages[null] = FeedPage(mine: [_trip('m')], items: [_trip('a')]);
    SocialLive.posts.value++;
    await _settle();
    expect(c.mine.map((t) => t.tripId), ['m']);
    expect(c.hasMore, isFalse);
  });
}
