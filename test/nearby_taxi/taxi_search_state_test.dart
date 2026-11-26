import 'dart:async';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/session/owner_session_hooks.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_controller_v2.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_popular_routes.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_seeker_cache.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../support/owner_fakes.dart';
import 'fake_taxi_feed_repo.dart';

class _Open {
  final calls = <({PlaceResult? from, bool fromNearYou, PlaceResult to, DateTime date, TaxiCityPair? cities})>[];
  Completer<void>? hold;

  Future<void>? call({required PlaceResult? from, required bool fromNearYou, required PlaceResult to, required DateTime date, TaxiCityPair? cities}) {
    calls.add((from: from, fromNearYou: fromNearYou, to: to, date: date, cities: cities));
    return hold?.future;
  }
}

TaxiPopularRoute _route(String id, {double fromLat = 28.61, double toLat = 30.09, TaxiCityPair? cities}) => TaxiPopularRoute(
      id: id,
      cities: cities,
      fromName: 'Delhi',
      fromLat: fromLat,
      fromLng: 77.21,
      toName: 'Rishikesh',
      toLat: toLat,
      toLng: 78.27,
      minFare: 899,
      taxiCount: 9,
    );

void main() {
  late GetStorage box;
  late FakeRepo repo;
  late _Open open;
  late RxInt version;
  late RxInt tab;
  late DateTime now;
  String? pinLabel;
  String? user;
  const pin = LatLng(29.2, 79.5);

  setUpAll(() async {
    await initTestStorage('taxi_search_state');
    box = GetStorage();
  });

  tearDownAll(() => OwnerCache.debugUseBox(null));

  setUp(() async {
    Get.reset();
    await box.erase();
    OwnerCache.debugUseBox(box);
    TaxiSeekerCache.clearMemory();
    repo = FakeRepo();
    open = _Open();
    version = 0.obs;
    tab = 3.obs;
    now = DateTime.utc(2026, 11, 26, 6);
    pinLabel = null;
    user = null;
  });

  tearDown(Get.reset);

  TaxiListControllerV2 make({bool root = false}) => Get.put(
        TaxiListControllerV2(
          root: root,
          repo: repo,
          centre: () => pin,
          pinLabel: () => pinLabel,
          centreVersion: version,
          tabIndex: tab,
          clock: () => now,
          userIdOf: () => user,
          openResults: open.call,
        ),
        tag: TaxiListControllerV2.tag,
      );

  group('states A to D', () {
    test('A: To empty, Swap and Search off', () async {
      final c = make();
      await settle();
      expect(c.canSearch, isFalse);
      expect(c.canSwap, isFalse);
    });

    test('B: bare GPS From with To set, Search on, Swap off', () async {
      final c = make();
      await settle();
      c.setTo(place('Nainital', 29.4));
      expect(c.canSearch, isTrue);
      expect(c.canSwap, isFalse);
      expect(c.fromMyLocation, isTrue);
    });

    test('C: named From and a far To, both on', () async {
      final c = make();
      await settle();
      c.setFrom(place('Haldwani', 29.2));
      c.setTo(place('Nainital', 29.4));
      expect(c.canSearch, isTrue);
      expect(c.canSwap, isTrue);
    });

    test('D: same place sets the value and turns Search off, Swap stays on', () async {
      final c = make();
      await settle();
      c.setFrom(place('Delhi', 28.6));
      c.setTo(place('Delhi', 28.6));
      expect(c.to.value?.name, 'Delhi');
      expect(c.samePlace, isTrue);
      expect(c.canSearch, isFalse);
      expect(c.canSwap, isTrue);
    });

    test('a labelled search pin counts as a named From', () async {
      pinLabel = 'Shimla';
      final c = make();
      await settle();
      c.setTo(place('Manali', 32.2));
      expect(c.fromMyLocation, isFalse);
      expect(c.canSwap, isTrue);
      expect(c.routeFrom.name, 'Shimla');
    });
  });

  group('swap', () {
    test('exchanges the values with one local reload', () async {
      final c = make();
      await settle();
      c.setFrom(place('Haldwani', 29.2));
      await settle();
      c.setTo(place('Nainital', 29.4));
      final before = repo.localCalls.length;
      c.swap();
      await settle();
      expect(c.from.value?.name, 'Nainital');
      expect(c.to.value?.name, 'Haldwani');
      expect(repo.localCalls.length, before + 1);
      expect(repo.localCalls.last.lat, 29.4);
    });

    test('a labelled pin moves into To', () async {
      pinLabel = 'Shimla';
      final c = make();
      await settle();
      c.setTo(place('Manali', 32.2));
      c.swap();
      await settle();
      expect(c.from.value?.name, 'Manali');
      expect(c.to.value?.name, 'Shimla');
      expect(c.to.value?.latLng.latitude, pin.latitude);
    });

    test('does nothing with bare GPS', () async {
      final c = make();
      await settle();
      c.setTo(place('Nainital', 29.4));
      final before = repo.localCalls.length;
      c.swap();
      await settle();
      expect(c.to.value?.name, 'Nainital');
      expect(c.from.value, isNull);
      expect(repo.localCalls.length, before);
    });
  });

  test('setTo and clearTo make no repo call', () async {
    final c = make();
    await settle();
    final before = repo.localCalls.length;
    c.setTo(place('Nainital', 29.4));
    c.clearTo();
    await settle();
    expect(repo.localCalls.length, before);
    expect(repo.routeCalls, isEmpty);
  });

  test('local list is called with today on the first and the next page', () async {
    repo.localPage = (t) => t == null ? NearbyPage(items: [fi('a')], hasMore: true, nextToken: 't2') : NearbyPage(items: [fi('b')]);
    final c = make();
    await settle();
    c.loadNextPage();
    await settle();
    expect(repo.localCalls.first.date, '2026-11-26');
    expect(repo.localCalls.last.token, 't2');
    expect(repo.localCalls.last.date, '2026-11-26');
  });

  test('the card date never changes the list date', () async {
    final c = make();
    await settle();
    c.setDate(DateTime(2026, 11, 29));
    c.retry();
    await settle();
    expect(c.date.value, DateTime(2026, 11, 29));
    expect(repo.localCalls.last.date, '2026-11-26');
  });

  test('date is clamped to the window', () async {
    final c = make();
    await settle();
    c.setDate(DateTime(2026, 11, 1));
    expect(c.date.value, DateTime(2026, 11, 26));
    c.setDate(DateTime(2027, 6, 1));
    expect(c.date.value, DateTime(2027, 2, 24));
  });

  test('leaving the tab resets From, To and the date', () async {
    final c = make(root: true);
    await settle();
    c.setFrom(place('Haldwani', 29.2));
    c.setTo(place('Nainital', 29.4));
    c.setDate(DateTime(2026, 11, 30));
    tab.value = 0;
    await settle();
    expect(c.from.value, isNull);
    expect(c.to.value, isNull);
    expect(c.date.value, DateTime(2026, 11, 26));
  });

  test('midnight roll reloads the list for the new day', () async {
    final c = make(root: true);
    await settle();
    expect(repo.localCalls.last.date, '2026-11-26');
    now = DateTime.utc(2026, 11, 26, 19);
    c.refreshIfStale();
    await settle();
    expect(repo.localCalls.last.date, '2026-11-27');
  });

  group('IST midnight', () {
    test('the day check at 18:30 UTC moves the card and the list to the new day', () async {
      now = DateTime.utc(2026, 11, 26, 18, 29);
      final c = make(root: true);
      await settle();
      expect(c.isToday, isTrue);
      expect(c.untilNextDay, const Duration(minutes: 1));
      final before = repo.localCalls.length;
      c.checkDay();
      await settle();
      expect(repo.localCalls.length, before);
      now = DateTime.utc(2026, 11, 26, 18, 31);
      c.checkDay();
      await settle();
      expect(c.currentDay.value, DateTime(2026, 11, 27));
      expect(c.date.value, DateTime(2026, 11, 27));
      expect(c.isToday, isTrue);
      expect(repo.localCalls.last.date, '2026-11-27');
      expect(repo.localCalls.length, before + 1);
    });

    test('a picked later day stays and shows as today after midnight', () async {
      now = DateTime.utc(2026, 11, 26, 18, 29);
      final c = make(root: true);
      await settle();
      c.setDate(DateTime(2026, 11, 27));
      expect(c.isToday, isFalse);
      now = DateTime.utc(2026, 11, 26, 18, 31);
      c.checkDay();
      await settle();
      expect(c.date.value, DateTime(2026, 11, 27));
      expect(c.isToday, isTrue);
    });

    test('on another tab the date moves, the list waits for the tab', () async {
      now = DateTime.utc(2026, 11, 26, 18, 29);
      final c = make(root: true);
      await settle();
      tab.value = 0;
      await settle();
      final before = repo.localCalls.length;
      now = DateTime.utc(2026, 11, 26, 18, 31);
      c.checkDay();
      await settle();
      expect(c.date.value, DateTime(2026, 11, 27));
      expect(repo.localCalls.length, before);
      tab.value = 3;
      await settle();
      expect(repo.localCalls.last.date, '2026-11-27');
    });

    test('pull to refresh after midnight moves the date and loads the new day', () async {
      now = DateTime.utc(2026, 11, 26, 18, 29);
      final c = make();
      await settle();
      now = DateTime.utc(2026, 11, 26, 18, 31);
      await c.pullRefresh();
      expect(c.currentDay.value, DateTime(2026, 11, 27));
      expect(c.date.value, DateTime(2026, 11, 27));
      expect(repo.localCalls.last.date, '2026-11-27');
    });
  });

  test('InvalidDate retries once without the date and never loops', () async {
    repo.rejectDate = true;
    final c = make();
    await settle();
    expect(repo.localCalls.map((e) => e.date), ['2026-11-26', null]);
    expect(c.items.map((e) => e.id), ['a', 'b']);
    c.retry();
    await settle();
    expect(repo.localCalls.last.date, isNull);
    expect(repo.localCalls.length, 3);
  });

  test('a stale answer is dropped', () async {
    final c = make();
    await settle();
    final slow = Completer<NearbyPage<TaxiFeedItem>>();
    repo.gate = slow;
    c.retry();
    repo.localPage = (_) => NearbyPage(items: [fi('fresh')]);
    c.retry();
    await settle();
    slow.complete(NearbyPage(items: [fi('old')]));
    await settle();
    expect(c.items.map((e) => e.id), ['fresh']);
  });

  group('disk copy', () {
    Map<String, dynamic> data(String id) => {
          'items': [
            {'id': id, 'driverName': 'Driver $id', 'vehicleTypeName': 'Sedan', 'plateDisplay': '', 'routeCount': 1, 'createdAt': '2026-11-01T00:00:00Z'},
          ],
        };

    test('same day and centre paints at once with no skeleton, then refreshes', () async {
      user = 'u1';
      TaxiSeekerCache.writeLocal('u1', date: '2026-11-26', lat: pin.latitude, lng: pin.longitude, data: data('cached'), now: now);
      final gate = Completer<NearbyPage<TaxiFeedItem>>();
      repo.gate = gate;
      final c = make();
      expect(c.items.map((e) => e.id), ['cached']);
      expect(c.isLoading.value, isFalse);
      gate.complete(NearbyPage(items: [fi('live')]));
      await settle();
      expect(c.items.map((e) => e.id), ['live']);
      expect(repo.localCalls, hasLength(1));
    });

    test('another day or another user is never painted', () async {
      TaxiSeekerCache.writeLocal('u1', date: '2026-11-25', lat: pin.latitude, lng: pin.longitude, data: data('old'), now: now);
      user = 'u1';
      final gate = Completer<NearbyPage<TaxiFeedItem>>();
      repo.gate = gate;
      final c = make();
      expect(c.items, isEmpty);
      expect(c.isLoading.value, isTrue);
      gate.complete(const NearbyPage());
      await settle();
      Get.reset();
      user = 'u2';
      TaxiSeekerCache.writeLocal('u1', date: '2026-11-26', lat: pin.latitude, lng: pin.longitude, data: data('other'), now: now);
      final c2 = make();
      expect(c2.items, isEmpty);
    });

    test('a live answer is written for the user', () async {
      user = 'u1';
      repo.localPage = (_) => TaxiLocalPage.fromData(data('live'));
      make();
      await settle();
      final copy = TaxiSeekerCache.readLocal('u1');
      expect(copy?.date, '2026-11-26');
      expect(copy?.lat, 29.2);
    });
  });

  group('popular routes', () {
    test('loaded once, hidden on empty and on failure', () async {
      final c = make();
      await settle();
      expect(repo.popularCalls, 1);
      expect(c.popular, isEmpty);
      Get.reset();
      repo = FakeRepo()..popularError = StateError('offline');
      final c2 = make();
      await settle();
      expect(c2.popular, isEmpty);
    });

    test('single flight and five minute freshness', () async {
      repo.popular = [_route('a')];
      final gate = Completer<List<TaxiPopularRoute>>();
      repo.popularGate = gate;
      final c = make();
      unawaited(c.loadPopular(force: true));
      unawaited(c.loadPopular(force: true));
      expect(repo.popularCalls, 1);
      gate.complete([_route('a')]);
      await settle();
      expect(c.popular.map((e) => e.id), ['a']);
      repo.popularGate = null;
      await c.loadPopular();
      expect(repo.popularCalls, 1);
      now = now.add(const Duration(minutes: 6));
      await c.loadPopular();
      expect(repo.popularCalls, 2);
    });

    test('applyPopular fills From and To and opens results once', () async {
      final c = make();
      await settle();
      final before = repo.localCalls.length;
      open.hold = Completer<void>();
      c.applyPopular(_route('a'));
      c.applyPopular(_route('b', fromLat: 28.7, toLat: 30.2));
      await settle();
      expect(repo.localCalls.length, before + 1);
      expect(c.from.value?.name, 'Delhi');
      expect(c.to.value?.name, 'Rishikesh');
      expect(open.calls, hasLength(1));
      expect(open.calls.single.from?.latLng.latitude, 28.61);
      expect(open.calls.single.to.latLng.latitude, 30.09);
      expect(open.calls.single.fromNearYou, isFalse);
      expect(open.calls.single.cities, isNull);
      open.hold!.complete();
      await settle();
    });

    test('applyPopular sends the city pair and the card date', () async {
      final c = make();
      await settle();
      c.setDate(DateTime(2026, 11, 29));
      c.applyPopular(_route('a', cities: const TaxiCityPair(101, 245)));
      await settle();
      expect(open.calls.single.cities, const TaxiCityPair(101, 245));
      expect(open.calls.single.date, DateTime(2026, 11, 29));
    });

    test('swap after a popular tap sends the pair reversed', () async {
      final c = make();
      await settle();
      c.applyPopular(_route('a', cities: const TaxiCityPair(101, 245)));
      await settle();
      c.swap();
      await c.search();
      expect(open.calls.last.cities, const TaxiCityPair(245, 101));
      expect(open.calls.last.from?.name, 'Rishikesh');
    });

    test('changing From or To after a popular tap drops the pair', () async {
      final c = make();
      await settle();
      c.applyPopular(_route('a', cities: const TaxiCityPair(101, 245)));
      await settle();
      c.setTo(place('Nainital', 29.4));
      expect(c.cityPair, isNull);
      await c.search();
      expect(open.calls.last.cities, isNull);
      c.applyPopular(_route('a', cities: const TaxiCityPair(101, 245)));
      await settle();
      c.setFrom(place('Haldwani', 29.2));
      expect(c.cityPair, isNull);
    });
  });

  group('popular route parse', () {
    Map<String, dynamic> raw({Object? fromKey = 101, Object? toKey = 245}) => {
          'id': 'r1',
          'fromCityKey': fromKey,
          'fromName': 'Delhi',
          'fromLat': 28.61,
          'fromLng': 77.21,
          'toCityKey': toKey,
          'toName': 'Rishikesh',
          'toLat': 30.09,
          'toLng': 78.27,
          'minFare': 899,
          'taxiCount': 9,
        };

    test('keeps the city keys and round trips through toJson', () {
      final r = TaxiPopularRoute.tryParse(raw())!;
      expect(r.cities, const TaxiCityPair(101, 245));
      expect(TaxiPopularRoute.tryParse(r.toJson())!.cities, const TaxiCityPair(101, 245));
    });

    test('missing, zero, equal or bad keys give no pair but keep the route', () {
      expect(TaxiPopularRoute.tryParse(raw(fromKey: null))!.cities, isNull);
      expect(TaxiPopularRoute.tryParse(raw(toKey: 0))!.cities, isNull);
      expect(TaxiPopularRoute.tryParse(raw(toKey: 101))!.cities, isNull);
      expect(TaxiPopularRoute.tryParse(raw(fromKey: 1.5))!.cities, isNull);
    });

    test('pair params and reverse', () {
      const p = TaxiCityPair(101, 245);
      expect(p.toParams(), {'fromCityKey': 101, 'toCityKey': 245});
      expect(p.reversed, const TaxiCityPair(245, 101));
    });
  });

  group('search', () {
    test('opens results with From, To and the card date, guarded against a double tap', () async {
      final c = make();
      await settle();
      c.setTo(place('Nainital', 29.4));
      c.setDate(DateTime(2026, 11, 28));
      open.hold = Completer<void>();
      unawaited(c.search());
      unawaited(c.search());
      await settle();
      expect(open.calls, hasLength(1));
      expect(open.calls.single.fromNearYou, isTrue);
      expect(open.calls.single.from?.latLng.latitude, pin.latitude);
      expect(open.calls.single.date, DateTime(2026, 11, 28));
      open.hold!.complete();
      await settle();
      await c.search();
      expect(open.calls, hasLength(2));
    });

    test('off when To is too close', () async {
      final c = make();
      await settle();
      c.setTo(PlaceResult(name: 'Here', subtitle: '', latLng: pin));
      expect(c.canSearch, isFalse);
      await c.search();
      expect(open.calls, isEmpty);
    });
  });

  test('logout hook clears the memory cache', () async {
    TaxiSeekerSession.register();
    TaxiSeekerCache.putRoute('k', const TaxiRouteFeed(), now);
    expect(TaxiSeekerCache.route('k', now), isNotNull);
    await OwnerSessionHooks.onLogout(LogoutReason.explicitLogout, 'u1');
    expect(TaxiSeekerCache.route('k', now), isNull);
    expect(OwnerSessionHooks.names, contains(TaxiSeekerSession.name));
  });
}
