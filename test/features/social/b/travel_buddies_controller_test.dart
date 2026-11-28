import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/b/data/public_trips_api.dart';
import 'package:bakhli/features/social/b/feed/feed_filter_sheet.dart';
import 'package:bakhli/features/social/b/feed/travel_buddies_controller.dart';
import 'package:bakhli/features/social/shared/social_live.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'social_b_test_kit.dart';

class _Api extends PublicTripsApi {
  final Map<String?, FeedPage> pages = {};
  final List<String?> cursors = [];
  final List<String> travels = [];

  @override
  Future<BuddyResult<FeedPage>> feed({String? cursor, String? q, String who = 'any', String travel = 'any', bool near = false, double? lat, double? lng}) async {
    cursors.add(cursor);
    travels.add(travel);
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
    api.pages[null] = FeedPage(items: [_trip('a'), _trip('b')]);
    SocialLive.posts.value++;
    await _settle();
    expect(c.items.map((t) => t.tripId), ['a', 'b']);
    expect(c.hasMore, isFalse);
  });

  test('I-37: Explore holds only the feed items, an empty feed is ready and empty', () async {
    final api = _Api();
    final c = Get.put(TravelBuddiesController(api: api));
    await _settle();
    expect(c.state.value, FeedLoad.ready);
    expect(c.items, isEmpty);
  });

  test('I-37: applyFollow flips Follow on every card of that poster only', () async {
    PublicTrip owned(String id, String owner) => PublicTrip.fromJson(publicTripJson(id: id, ownerId: owner));
    final api = _Api()..pages[null] = FeedPage(items: [owned('a', 'kavya'), owned('b', 'aman'), owned('c', 'kavya')]);
    final c = Get.put(TravelBuddiesController(api: api));
    await _settle();
    c.applyFollow('kavya', true);
    expect(c.items.map((t) => t.iFollowOwner), [true, false, true]);
    c.applyFollow('kavya', false);
    expect(c.items.map((t) => t.iFollowOwner), [false, false, false]);
  });

  test('applyMyJoin and applyRefusal update the card in place', () async {
    final api = _Api()..pages[null] = FeedPage(items: [_trip('a'), _trip('b')]);
    final c = Get.put(TravelBuddiesController(api: api));
    await _settle();
    c.applyMyJoin('a', 'requested');
    c.applyRefusal('b', 'TripRequestsFull');
    expect(c.items[0].myJoin, 'requested');
    expect(c.items[1].requestsFull, isTrue);
    c.applyRefusal('a', 'CannotRejoin');
    expect(c.items[0].myJoin, 'removed');
  });
  test('T3: the Travel by filter reaches every feed call, and Any sends no filter', () async {
    final api = _Api()..pages[null] = FeedPage(items: [_trip('a')], nextCursor: 'p2');
    final c = Get.put(TravelBuddiesController(api: api));
    await _settle();
    await c.applyFilter(c.filter.value.copyWith(travel: 'bike'));
    await c.loadMore();
    expect(api.travels, ['any', 'bike', 'bike']);
    expect(c.filter.value.count, 1);
    await c.applyFilter(c.filter.value.copyWith(travel: FeedFilter.any));
    expect(api.travels.last, 'any');
    expect(c.filter.value.count, 0);
  });
}
