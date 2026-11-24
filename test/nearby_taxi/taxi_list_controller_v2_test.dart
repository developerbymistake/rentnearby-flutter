import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_controller_v2.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_availability.dart';
import 'package:bakhli/models/place_result_model.dart';

import 'fake_ways_repo.dart';

TaxiFeedItem fi(String id) => TaxiFeedItem(
      item: TaxiBrowseItem(
        id: id,
        driverName: id,
        vehicleTypeName: 'Sedan',
        plateDisplay: '',
        routeCount: 1,
        matchReversed: false,
        createdAt: DateTime(2026),
      ),
    );

class FakeRepo extends TaxiFeedRepository {
  final localCalls = <({double lat, String? token})>[];
  final routeCalls = <({double fromLat, double toLat})>[];
  final tierCalls = <String>[];
  Completer<NearbyPage<TaxiFeedItem>>? gate;
  NearbyPage<TaxiFeedItem> Function(String? token) localPage = (t) => NearbyPage(items: [fi('a'), fi('b')]);
  TaxiRouteFeed routeFeed = const TaxiRouteFeed();

  @override
  Future<NearbyPage<TaxiFeedItem>> local({
    required double lat,
    required double lng,
    String? pageToken,
    int pageSize = 20,
    String? category,
  }) {
    localCalls.add((lat: lat, token: pageToken));
    final g = gate;
    if (g != null && pageToken == null) {
      gate = null;
      return g.future;
    }
    try {
      return Future.value(localPage(pageToken));
    } catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<TaxiRouteFeed> route({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String? category,
  }) {
    routeCalls.add((fromLat: fromLat, toLat: toLat));
    return Future.value(routeFeed);
  }

  @override
  Future<TaxiTier?> routeTier({
    required String tier,
    required String pageToken,
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String? category,
  }) {
    tierCalls.add('$tier:$pageToken');
    return Future.value(TaxiTier(key: tier, items: [fi('n1'), fi('r1')]));
  }
}

PlaceResult place(String n, double lat) => PlaceResult(name: n, subtitle: '', latLng: LatLng(lat, 79));

Future<void> settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late FakeRepo repo;
  late FakeWaysRepo ways;
  late RxInt version;
  late LatLng pin;
  late TaxiListControllerV2 c;

  setUp(() {
    Get.reset();
    repo = FakeRepo();
    ways = FakeWaysRepo();
    version = 0.obs;
    pin = const LatLng(29.2, 79.5);
    c = Get.put(TaxiListControllerV2(root: false, repo: repo, waysRepo: ways, centre: () => pin, centreVersion: version));
  });

  tearDown(Get.reset);

  test('local mode loads around the centre', () async {
    await settle();
    expect(c.isRoute, isFalse);
    expect(repo.localCalls.single.lat, 29.2);
    expect(c.items.map((e) => e.id), ['a', 'b']);
    expect(repo.routeCalls, isEmpty);
  });

  test('featured ids are removed from items', () async {
    await settle();
    repo.localPage = (_) => NearbyPage(featured: [fi('a')], items: [fi('a'), fi('b')]);
    c.retry();
    await settle();
    expect(c.featured.map((e) => e.id), ['a']);
    expect(c.items.map((e) => e.id), ['b']);
  });

  test('centre change reloads', () async {
    await settle();
    pin = const LatLng(30.0, 79.0);
    version.value++;
    await settle();
    expect(repo.localCalls.last.lat, 30.0);
  });

  test('a stale response is dropped', () async {
    await settle();
    final slow = Completer<NearbyPage<TaxiFeedItem>>();
    repo.gate = slow;
    c.retry();
    await settle();
    repo.localPage = (_) => NearbyPage(items: [fi('fresh')]);
    c.retry();
    await settle();
    slow.complete(NearbyPage(items: [fi('old')]));
    await settle();
    expect(c.items.map((e) => e.id), ['fresh']);
  });

  test('paging appends without duplicates', () async {
    await settle();
    repo.localPage = (t) =>
        t == null ? NearbyPage(items: [fi('a')], hasMore: true, nextToken: 't2') : NearbyPage(items: [fi('a'), fi('c')]);
    c.retry();
    await settle();
    c.loadNextPage();
    await settle();
    expect(c.items.map((e) => e.id), ['a', 'c']);
    expect(repo.localCalls.last.token, 't2');
    expect(c.hasMore.value, isFalse);
  });

  test('picking To switches to route mode with From defaulting to the centre', () async {
    await settle();
    c.setTo(place('Nainital', 29.4));
    await settle();
    expect(c.isRoute, isTrue);
    expect(repo.routeCalls.single.fromLat, 29.2);
    expect(repo.routeCalls.single.toLat, 29.4);
    c.setFrom(place('Delhi', 28.6));
    await settle();
    expect(repo.routeCalls.last.fromLat, 28.6);
    c.clearTo();
    await settle();
    expect(c.isRoute, isFalse);
    expect(c.route.value, isNull);
  });

  test('collapsed tier opens first, then loads more and dedupes', () async {
    repo.routeFeed = TaxiRouteFeed(tiers: [
      TaxiTier(key: 'onRoute', items: [fi('r1')], hasMore: true, nextToken: 'p2'),
      TaxiTier(key: 'inTo', items: [fi('t1')], collapsed: true, hasMore: true, nextToken: 'x'),
    ]);
    await settle();
    c.setTo(place('Nainital', 29.4));
    await settle();
    await c.showMoreOf('inTo');
    expect(c.isExpanded('inTo'), isTrue);
    expect(repo.tierCalls, isEmpty);
    await c.showMoreOf('onRoute');
    expect(repo.tierCalls, ['onRoute:p2']);
    expect(c.route.value!.tier('onRoute')!.items.map((e) => e.id), ['r1', 'n1']);
    expect(c.route.value!.tier('onRoute')!.hasMore, isFalse);
  });

  test('failed first load shows the error flag', () async {
    await settle();
    Get.reset();
    final bad = FakeRepo()..localPage = (_) => throw StateError('x');
    final c2 = Get.put(TaxiListControllerV2(root: false, repo: bad, waysRepo: ways, centre: () => pin, centreVersion: version));
    await settle();
    expect(c2.loadFailed.value, isTrue);
    expect(c2.isLoading.value, isFalse);
  });

  group('ways entry check', () {
    test('local mode never asks', () async {
      await settle();
      expect(ways.calls, isEmpty);
      expect(c.waysCheck.state.value, WaysAvailability.idle);
    });

    test('picking To asks once for the same From and To as the route list', () async {
      await settle();
      c.setTo(place('Almora', 29.6));
      await settle();
      expect(ways.calls.single.fromLat, 29.2);
      expect(ways.calls.single.toLat, 29.6);
      expect(c.waysCheck.isAvailable, isTrue);
    });

    test('false and failed answers leave the card off', () async {
      await settle();
      ways.answer = false;
      c.setTo(place('Almora', 29.6));
      await settle();
      expect(c.waysCheck.state.value, WaysAvailability.unavailable);
      ways.error = StateError('503');
      c.setTo(place('Nainital', 29.4));
      await settle();
      expect(c.waysCheck.state.value, WaysAvailability.failed);
      expect(c.waysCheck.isAvailable, isFalse);
    });

    test('a new search resets to loading and drops the old answer', () async {
      await settle();
      ways.manual = true;
      c.setTo(place('Almora', 29.6));
      await settle();
      c.setFrom(place('Delhi', 28.6));
      await settle();
      expect(c.waysCheck.state.value, WaysAvailability.loading);
      ways.pending.first.complete(true);
      await settle();
      expect(c.waysCheck.isAvailable, isFalse);
      ways.pending.last.complete(true);
      await settle();
      expect(ways.calls.last.fromLat, 28.6);
      expect(c.waysCheck.isAvailable, isTrue);
    });

    test('clearing To resets the check', () async {
      await settle();
      c.setTo(place('Almora', 29.6));
      await settle();
      expect(c.waysCheck.isAvailable, isTrue);
      c.clearTo();
      await settle();
      expect(c.waysCheck.state.value, WaysAvailability.idle);
      expect(ways.calls, hasLength(1));
    });
  });
}
