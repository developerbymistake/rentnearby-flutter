import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_controller_v2.dart';

import 'fake_taxi_feed_repo.dart';

void main() {
  late FakeRepo repo;
  late RxInt version;
  late LatLng pin;
  late TaxiListControllerV2 c;

  setUp(() {
    Get.reset();
    repo = FakeRepo();
    version = 0.obs;
    pin = const LatLng(29.2, 79.5);
    c = Get.put(TaxiListControllerV2(root: false, repo: repo, centre: () => pin, centreVersion: version));
  });

  tearDown(Get.reset);

  test('local mode loads around the centre', () async {
    await settle();
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

  test('picking To does not load a route and keeps the local list', () async {
    await settle();
    final before = repo.localCalls.length;
    c.setTo(place('Nainital', 29.4));
    await settle();
    expect(repo.routeCalls, isEmpty);
    expect(repo.localCalls.length, before);
    expect(c.items.map((e) => e.id), ['a', 'b']);
    c.clearTo();
    await settle();
    expect(c.to.value, isNull);
    expect(repo.localCalls.length, before);
  });

  test('failed first load shows the error flag', () async {
    await settle();
    Get.reset();
    final bad = FakeRepo()..localPage = (_) => throw StateError('x');
    final c2 = Get.put(TaxiListControllerV2(root: false, repo: bad, centre: () => pin, centreVersion: version));
    await settle();
    expect(c2.loadFailed.value, isTrue);
    expect(c2.isLoading.value, isFalse);
  });
}
