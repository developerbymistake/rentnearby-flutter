import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/b/data/public_trips_api.dart';
import 'package:bakhli/features/social/b/feed/my_posts_controller.dart';
import 'package:bakhli/features/social/b/feed/travel_buddies_controller.dart';
import 'package:bakhli/features/social/shared/social_live.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'social_b_test_kit.dart';

class _Api extends PublicTripsApi {
  BuddyResult<List<PublicTrip>> next = const BuddyOk(<PublicTrip>[]);
  int calls = 0;

  @override
  Future<BuddyResult<List<PublicTrip>>> mine() async {
    calls++;
    return next;
  }
}

PublicTrip _mine(String id, {int waiting = 0}) => PublicTrip.fromJson(publicTripJson(id: id, isMine: true, waitingRequests: waiting));

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

  test('loads my posts on start, in the server order', () async {
    final api = _Api()..next = BuddyOk([_mine('m2', waiting: 3), _mine('m1')]);
    final c = Get.put(MyPostsController(api: api));
    expect(c.state.value, FeedLoad.loading);
    await _settle();
    expect(c.state.value, FeedLoad.ready);
    expect(c.items.map((t) => t.tripId), ['m2', 'm1']);
    expect(c.items.first.waitingRequests, 3);
    expect(api.calls, 1);
  });

  test('no posts is ready and empty', () async {
    final c = Get.put(MyPostsController(api: _Api()));
    await _settle();
    expect(c.state.value, FeedLoad.ready);
    expect(c.items, isEmpty);
  });

  test('offline and failed show their state only while nothing is loaded', () async {
    final api = _Api()..next = const BuddyOffline();
    final c = Get.put(MyPostsController(api: api));
    await _settle();
    expect(c.state.value, FeedLoad.offline);
    api.next = const BuddyFailed(message: 'down');
    await c.load();
    expect(c.state.value, FeedLoad.failed);
    api.next = BuddyOk([_mine('m1')]);
    await c.load();
    expect(c.state.value, FeedLoad.ready);
    api.next = const BuddyOffline();
    await c.load();
    expect(c.state.value, FeedLoad.ready);
    expect(c.items.map((t) => t.tripId), ['m1']);
  });

  test('a new post and a join request tick both reload My posts', () async {
    final api = _Api()..next = BuddyOk([_mine('m1')]);
    final c = Get.put(MyPostsController(api: api));
    await _settle();
    api.next = BuddyOk([_mine('m2'), _mine('m1')]);
    SocialLive.posts.value++;
    await _settle();
    expect(c.items.map((t) => t.tripId), ['m2', 'm1']);
    api.next = BuddyOk([_mine('m2', waiting: 1), _mine('m1')]);
    SocialLive.joinRequests.value++;
    await _settle();
    expect(c.items.first.waitingRequests, 1);
    expect(api.calls, 3);
  });
}
