import 'dart:async';

import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/seeker_home/seeker_feed_controller.dart';
import 'package:bakhli/features/seeker_home/seeker_feed_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../support/owner_fakes.dart';
import 'seeker_fakes.dart';

SeekerFeed feedWith(String tripId, {String? statusKey}) => SeekerFeed(
      tripCard: SeekerTripCard(state: SeekerTripState.inProgress, tripId: tripId, title: 'Nainital trip', done: 3, total: 5),
      status: statusKey == null ? null : SeekerStatus(kind: SeekerStatusKind.confirmed, listingName: 'Deodar Heights', key: statusKey),
    );

void main() {
  late GetStorage box;
  setUpAll(() async {
    await initTestStorage('seeker_feed_ctrl');
    box = GetStorage();
  });

  setUp(() async {
    Get.reset();
    await box.erase();
    OwnerCache.debugUseBox(box);
  });

  tearDown(Get.reset);

  SeekerFeedController make(ScriptedFeedApi api, {String user = 'user-a'}) =>
      Get.put(SeekerFeedController(api: api, userIdOf: () => user));

  test('o_sk_5_firstOpenNoCopy: skeleton while the first call runs, data after', () async {
    final done = Completer<OwnerResult<SeekerFeed>>();
    final api = ScriptedFeedApi(() => done.future);
    final c = make(api);
    expect(c.feed.value, isNull);
    expect(c.showSkeleton, isTrue);
    done.complete(OwnerOk(feedWith('t1')));
    await pumpEventQueue();
    expect(c.showSkeleton, isFalse);
    expect(c.feed.value?.tripCard.tripId, 't1');
    expect(c.loading.value, isFalse);
  });

  test('o_sk_5_savedCopyExists_noSkeletonAtAll: the saved copy paints at once', () async {
    OwnerCache.write('user-a', OwnerCacheKeys.seekerFeed, feedWith('saved').toJson());
    final api = ScriptedFeedApi(() => Completer<OwnerResult<SeekerFeed>>().future);
    final c = make(api);
    expect(c.feed.value?.tripCard.tripId, 'saved');
    expect(c.showSkeleton, isFalse);
  });

  test('o_sk_5_skeletonEndsOnError: offline, refused, failed and a throw end the skeleton with the no-trip card', () async {
    final results = <Future<OwnerResult<SeekerFeed>> Function()>[
      () async => const OwnerOffline<SeekerFeed>(),
      () async => const OwnerRefused<SeekerFeed>(type: 'X', statusCode: 400),
      () async => const OwnerFailed<SeekerFeed>(message: 'boom'),
      () async => throw StateError('boom'),
    ];
    for (final r in results) {
      Get.reset();
      final c = make(ScriptedFeedApi(r));
      await pumpEventQueue();
      expect(c.loading.value, isFalse);
      expect(c.feed.value?.tripCard.hasTrip, isFalse);
    }
  });

  test('o_sk_2 refresh error keeps the saved copy', () async {
    OwnerCache.write('user-a', OwnerCacheKeys.seekerFeed, feedWith('saved').toJson());
    final c = make(ScriptedFeedApi(() async => const OwnerOffline<SeekerFeed>()));
    await pumpEventQueue();
    expect(c.feed.value?.tripCard.tripId, 'saved');
  });

  test('single flight: two reloads share one call', () async {
    final done = Completer<OwnerResult<SeekerFeed>>();
    final api = ScriptedFeedApi(() => done.future);
    final c = make(api);
    unawaited(c.reload());
    unawaited(c.reload());
    expect(api.calls, 1);
    done.complete(OwnerOk(feedWith('t1')));
    await pumpEventQueue();
  });

  test('refresh at most once per 30 s unless forced', () async {
    var now = DateTime(2026, 11, 21, 10);
    final api = ScriptedFeedApi(() async => OwnerOk(feedWith('t1')));
    final c = Get.put(SeekerFeedController(api: api, userIdOf: () => 'user-a', clock: () => now));
    await pumpEventQueue();
    expect(api.calls, 1);
    await c.refreshIfStale();
    expect(api.calls, 1);
    now = now.add(const Duration(seconds: 31));
    await c.refreshIfStale();
    expect(api.calls, 2);
    await c.refreshIfStale(force: true);
    expect(api.calls, 3);
  });

  test('stale answer is dropped after a reset (logout)', () async {
    final done = Completer<OwnerResult<SeekerFeed>>();
    final c = make(ScriptedFeedApi(() => done.future));
    c.reset();
    done.complete(OwnerOk(feedWith('late')));
    await pumpEventQueue();
    expect(c.feed.value, isNull);
  });

  test('closed controller ignores a late answer and leaves no spinner', () async {
    final done = Completer<OwnerResult<SeekerFeed>>();
    final c = make(ScriptedFeedApi(() => done.future));
    Get.delete<SeekerFeedController>(force: true);
    done.complete(OwnerOk(feedWith('late')));
    await pumpEventQueue();
    expect(c.isClosed, isTrue);
    expect(Get.isRegistered<SeekerFeedController>(), isFalse);
  });

  test('markStatusOpened stores the key per user and hides the line', () async {
    final c = make(ScriptedFeedApi(() async => OwnerOk(feedWith('t1', statusKey: 'k1'))));
    await pumpEventQueue();
    expect(c.visibleStatus?.key, 'k1');
    c.markStatusOpened();
    expect(c.visibleStatus, isNull);
    expect(OwnerCache.statusSeen('user-a'), 'k1');
    expect(OwnerCache.statusSeen('user-b'), isNull);
  });

  test('logout: no cached feed readable by user B', () async {
    final c = make(ScriptedFeedApi(() async => OwnerOk(feedWith('t1', statusKey: 'k1'))));
    await pumpEventQueue();
    expect(OwnerCache.read('user-a', OwnerCacheKeys.seekerFeed), isNotNull);
    OwnerCache.clearAll();
    c.reset();
    expect(OwnerCache.read('user-a', OwnerCacheKeys.seekerFeed), isNull);
    Get.reset();
    final b = make(ScriptedFeedApi(() => Completer<OwnerResult<SeekerFeed>>().future), user: 'user-b');
    expect(b.feed.value, isNull);
    expect(b.showSkeleton, isTrue);
  });
}
