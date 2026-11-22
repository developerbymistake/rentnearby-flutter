import 'dart:async';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/seeker_home/seeker_feed_controller.dart';
import 'package:bakhli/features/seeker_home/seeker_feed_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
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

  test('o_sk_5_skeletonEndsOnError: offline, refused, failed and a throw end the skeleton with the failed state (FX-10)', () async {
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
      expect(c.showSkeleton, isFalse);
      expect(c.feed.value, isNull, reason: 'no fake "first trip" card on a failure');
      expect(c.failed.value, isTrue);
    }
  });

  test('FX-10 a failed answer does not start the 30 s gap: the next refresh loads again', () async {
    var fail = true;
    final api = ScriptedFeedApi(() async => fail ? const OwnerOffline<SeekerFeed>() : OwnerOk(feedWith('t1')));
    final c = make(api);
    await pumpEventQueue();
    expect(c.failed.value, isTrue);
    fail = false;
    await c.refreshIfStale();
    expect(api.calls, 2);
    expect(c.failed.value, isFalse);
    expect(c.feed.value?.tripCard.tripId, 't1');
  });

  test('FX-12 trips list: identical lists do not refetch; a real change refetches once', () async {
    TripSummaryModel trip(String id, {String? start}) => TripSummaryModel.fromJson({'id': id, 'startDate': start});
    final list = <TripSummaryModel>[].obs;
    final offline = Rxn<DateTime>();
    final api = ScriptedFeedApi(() async => OwnerOk(feedWith('t1')));
    final c = make(api)..attachTripsList(list, offlineCopyAt: offline);
    await pumpEventQueue();
    expect(api.calls, 1);
    list.assignAll(const []);
    list.assignAll(const []);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(api.calls, 1);
    list.addAll([trip('a', start: '2026-12-01')]);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(api.calls, 2);
    list.assignAll([trip('a', start: '2026-12-01')]);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(api.calls, 2);
    offline.value = DateTime(2026);
    list.addAll([trip('b')]);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(api.calls, 2, reason: 'an offline copy of My trips never refetches the feed');
    expect(c.isClosed, isFalse);
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

  test('a user change during a load starts a new load for the new user', () async {
    final auth = FakeAuth();
    Get.put<AuthController>(auth);
    auth.signIn(role: 'SEEKER', id: 'user-a');
    final first = Completer<OwnerResult<SeekerFeed>>();
    final api = ScriptedFeedApi(() => first.future);
    final c = Get.put(SeekerFeedController(api: api));
    expect(api.calls, 1);
    api.next = () async => OwnerOk(feedWith('b-trip'));
    auth.signIn(role: 'SEEKER', id: 'user-b');
    await pumpEventQueue();
    expect(api.calls, 2);
    expect(c.feed.value?.tripCard.tripId, 'b-trip');
    first.complete(OwnerOk(feedWith('a-trip')));
    await pumpEventQueue();
    expect(c.feed.value?.tripCard.tripId, 'b-trip');
    expect(c.loading.value, isFalse);
  });

  test('FX-29 an equal answer is not assigned again (no Home rebuild); a changed one is', () async {
    var answer = feedWith('t1');
    final api = ScriptedFeedApi(() async => OwnerOk(answer));
    final c = make(api);
    await pumpEventQueue();
    var changes = 0;
    final w = ever(c.feed, (_) => changes++);
    await c.reload();
    await c.reload();
    expect(api.calls, 3);
    expect(changes, 0);
    answer = feedWith('t2');
    await c.reload();
    expect(changes, 1);
    expect(c.feed.value?.tripCard.tripId, 't2');
    w.dispose();
  });
}
