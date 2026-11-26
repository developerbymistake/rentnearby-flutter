import 'dart:async';

import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_journey_date.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_popular_routes.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_results_controller.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_seeker_cache.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_availability.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'fake_taxi_feed_repo.dart';
import 'fake_ways_repo.dart';

const _debounce = Duration(milliseconds: 20);

Future<void> _wait() => Future<void>.delayed(const Duration(milliseconds: 60));

TaxiRouteFeed _feed(String id, {int? free, String? date}) => TaxiRouteFeed(
      date: date,
      freeCount: free,
      tiers: [TaxiTier(key: TaxiTierKey.onRoute, items: [fi(id)])],
    );

void main() {
  late FakeRepo repo;
  late FakeWaysRepo ways;
  late DateTime now;

  setUp(() {
    Get.reset();
    TaxiSeekerCache.clearMemory();
    repo = FakeRepo();
    ways = FakeWaysRepo();
    now = DateTime.utc(2026, 11, 26, 6);
  });

  tearDown(Get.reset);

  TaxiResultsController make({PlaceResult? from, DateTime? date, bool nearYou = false, TaxiCityPair? cities}) => Get.put(
        TaxiResultsController(
          args: TaxiResultsArgs(
            from: from ?? PlaceResult(name: 'Haldwani', subtitle: '', latLng: const LatLng(29.2, 79.5)),
            fromNearYou: nearYou,
            to: PlaceResult(name: 'Nainital', subtitle: '', latLng: const LatLng(29.4, 79.45)),
            date: date ?? DateTime(2026, 11, 26),
            cities: cities,
          ),
          repo: repo,
          waysRepo: ways,
          clock: () => now,
          debounceTime: _debounce,
        ),
        tag: TaxiResultsController.tag,
      );

  test('first load sends the date and the sort', () async {
    repo.routeFeed = _feed('a', free: 9);
    final c = make(date: DateTime(2026, 11, 27));
    await settle();
    expect(repo.routeCalls.single.date, '2026-11-27');
    expect(repo.routeCalls.single.sort, 'nearest');
    expect(repo.routeCalls.single.fromLat, 29.2);
    expect(c.freeCount, 9);
    expect(c.isLoading.value, isFalse);
  });

  test('freeCount 0 or missing gives no count', () async {
    repo.routeFeed = _feed('a', free: 0);
    final c = make();
    await settle();
    expect(c.freeCount, isNull);
  });

  test('arrow taps in a row become one request after the debounce', () async {
    final c = make();
    await settle();
    expect(c.canPrev, isFalse);
    c.nextDay();
    c.nextDay();
    c.nextDay();
    expect(c.date.value, DateTime(2026, 11, 29));
    expect(c.route.value, isNull);
    await _wait();
    expect(repo.routeCalls, hasLength(2));
    expect(repo.routeCalls.last.date, '2026-11-29');
  });

  test('previous stops on today and next stops on day 90', () async {
    final c = make(date: DateTime(2027, 2, 24));
    await settle();
    expect(c.canNext, isFalse);
    c.nextDay();
    expect(c.date.value, DateTime(2027, 2, 24));
    c.setDate(DateTime(2026, 11, 26));
    c.prevDay();
    expect(c.date.value, DateTime(2026, 11, 26));
    await _wait();
  });

  test('a late answer for an older day is dropped', () async {
    repo.gateRoutes = true;
    final c = make();
    await settle();
    c.nextDay();
    await _wait();
    expect(repo.routeGates, hasLength(2));
    repo.routeGates.last.complete(_feed('new'));
    await settle();
    repo.routeGates.first.complete(_feed('old'));
    await settle();
    expect(c.route.value!.tiers.single.items.single.id, 'new');
    expect(c.date.value, DateTime(2026, 11, 27));
  });

  test('a day already seen paints at once from memory without a request', () async {
    repo.routeFor = (d, _) => _feed('day-$d');
    final c = make();
    await settle();
    c.nextDay();
    await _wait();
    c.prevDay();
    expect(c.route.value!.tiers.single.items.single.id, 'day-2026-11-26');
    expect(c.isLoading.value, isFalse);
    await _wait();
    expect(repo.routeCalls, hasLength(2));
  });

  test('an old memory entry paints, then refreshes quietly', () async {
    repo.routeFor = (d, _) => _feed('day-$d');
    final c = make();
    await settle();
    c.nextDay();
    await _wait();
    now = now.add(const Duration(minutes: 3));
    c.prevDay();
    expect(c.route.value, isNotNull);
    await _wait();
    expect(repo.routeCalls, hasLength(3));
  });

  test('sort change resets the open tiers and reloads with cheapest', () async {
    repo.routeFeed = TaxiRouteFeed(tiers: [
      TaxiTier(key: TaxiTierKey.inTo, items: [fi('t1')], collapsed: true),
    ]);
    final c = make();
    await settle();
    await c.showMoreOf(TaxiTierKey.inTo);
    expect(c.isExpanded(TaxiTierKey.inTo), isTrue);
    c.setSort('cheapest');
    expect(c.isExpanded(TaxiTierKey.inTo), isFalse);
    await _wait();
    expect(repo.routeCalls.last.sort, 'cheapest');
    c.setSort('bogus');
    expect(c.sort.value, 'cheapest');
  });

  test('collapsed tier opens first, then loads more with the same date and sort and dedupes', () async {
    repo.routeFeed = TaxiRouteFeed(date: '2026-11-26', freeCount: 3, tiers: [
      TaxiTier(key: TaxiTierKey.onRoute, items: [fi('r1')], hasMore: true, nextToken: 'p2'),
      TaxiTier(key: TaxiTierKey.inTo, items: [fi('t1')], collapsed: true, hasMore: true, nextToken: 'x'),
    ]);
    final c = make();
    await settle();
    await c.showMoreOf(TaxiTierKey.inTo);
    expect(c.isExpanded(TaxiTierKey.inTo), isTrue);
    expect(repo.tierCalls, isEmpty);
    await c.showMoreOf(TaxiTierKey.onRoute);
    expect(repo.tierCalls, ['onRoute:p2:2026-11-26:nearest']);
    expect(c.route.value!.tier(TaxiTierKey.onRoute)!.items.map((e) => e.id), ['r1', 'n1']);
    expect(c.route.value!.tier(TaxiTierKey.onRoute)!.hasMore, isFalse);
    expect(c.route.value!.freeCount, 3);
  });

  test('a popular city pair goes with the first call, the day flips and tier pages', () async {
    const pair = TaxiCityPair(101, 245);
    repo.routeFeed = TaxiRouteFeed(date: '2026-11-26', tiers: [
      TaxiTier(key: TaxiTierKey.onRoute, items: [fi('r1')], hasMore: true, nextToken: 'p2'),
    ]);
    final c = make(cities: pair);
    await settle();
    expect(repo.routeCalls.single.cities, pair);
    await c.showMoreOf(TaxiTierKey.onRoute);
    expect(repo.tierCities.single, pair);
    c.nextDay();
    await _wait();
    expect(repo.routeCalls.last.cities, pair);
  });

  test('a plain search sends no city pair', () async {
    make();
    await settle();
    expect(repo.routeCalls.single.cities, isNull);
  });

  test('failure flag only when nothing is shown', () async {
    repo.routeError = StateError('offline');
    final c = make();
    await settle();
    expect(c.loadFailed.value, isTrue);
    expect(c.isLoading.value, isFalse);
    repo.routeError = null;
    repo.routeFeed = _feed('a');
    c.retry();
    await settle();
    expect(c.loadFailed.value, isFalse);
    repo.routeError = StateError('offline');
    await c.pullRefresh();
    expect(c.loadFailed.value, isFalse);
    expect(c.route.value, isNotNull);
  });

  test('InvalidDate retries once without the date, for that request only', () async {
    repo.rejectDate = true;
    repo.routeFeed = _feed('a');
    final c = make();
    await settle();
    expect(repo.routeCalls.map((e) => e.date), ['2026-11-26', null]);
    expect(c.route.value, isNotNull);
    c.nextDay();
    await _wait();
    expect(repo.routeCalls.map((e) => e.date), ['2026-11-26', null, '2026-11-27', null]);
    expect(c.date.value, DateTime(2026, 11, 26));
    expect(c.isToday, isTrue);
  });

  test('after one InvalidDate the next day is asked with its date again', () async {
    repo.rejectDate = true;
    repo.routeFor = (d, _) => _feed('day-$d');
    final c = make();
    await settle();
    expect(c.route.value!.tiers.single.items.single.id, 'day-null');
    repo.rejectDate = false;
    c.nextDay();
    await _wait();
    expect(repo.routeCalls.last.date, '2026-11-27');
    expect(c.date.value, DateTime(2026, 11, 27));
    expect(c.route.value!.tiers.single.items.single.id, 'day-2026-11-27');
  });

  test('a no-date answer is kept only under today, never under the asked day', () async {
    repo.routeFor = (d, _) => _feed('day-$d');
    final c = make();
    await settle();
    repo.rejectDate = true;
    c.nextDay();
    await _wait();
    expect(c.date.value, DateTime(2026, 11, 26));
    expect(c.route.value!.tiers.single.items.single.id, 'day-null');
    repo.rejectDate = false;
    final before = repo.routeCalls.length;
    c.nextDay();
    expect(c.route.value, isNull);
    await _wait();
    expect(repo.routeCalls.length, before + 1);
    expect(repo.routeCalls.last.date, '2026-11-27');
  });

  test('a dated answer for another day is kept under that day only', () async {
    repo.routeFor = (d, _) => _feed('answered', date: '2026-11-28');
    final c = make();
    await settle();
    expect(c.date.value, DateTime(2026, 11, 28));
    c.setDate(DateTime(2026, 11, 26));
    expect(c.route.value, isNull);
    c.setDate(DateTime(2026, 11, 28));
    expect(c.route.value!.tiers.single.items.single.id, 'answered');
    await _wait();
  });

  test('Show more retries once without the date on InvalidDate', () async {
    repo.routeFeed = TaxiRouteFeed(tiers: [
      TaxiTier(key: TaxiTierKey.onRoute, items: [fi('r1')], hasMore: true, nextToken: 'p2'),
    ]);
    final c = make();
    await settle();
    repo.rejectTierDate = true;
    await c.showMoreOf(TaxiTierKey.onRoute);
    expect(repo.tierCalls, ['onRoute:p2:2026-11-26:nearest', 'onRoute:p2:null:nearest']);
    expect(c.route.value!.tier(TaxiTierKey.onRoute)!.items.map((e) => e.id), ['r1', 'n1']);
  });

  test('a refresh drops a Show more page that was still loading', () async {
    repo.routeFeed = TaxiRouteFeed(tiers: [
      TaxiTier(key: TaxiTierKey.onRoute, items: [fi('r1')], hasMore: true, nextToken: 'p2'),
    ]);
    final c = make();
    await settle();
    final gate = Completer<TaxiTier?>();
    repo.tierGate = gate;
    final more = c.showMoreOf(TaxiTierKey.onRoute);
    expect(c.loadingTiers.contains(TaxiTierKey.onRoute), isTrue);
    repo.routeFeed = TaxiRouteFeed(tiers: [
      TaxiTier(key: TaxiTierKey.onRoute, items: [fi('fresh')], hasMore: true, nextToken: 'q2'),
    ]);
    final refresh = c.pullRefresh();
    expect(c.loadingTiers, isEmpty);
    await refresh;
    gate.complete(TaxiTier(key: TaxiTierKey.onRoute, items: [fi('old')], hasMore: false));
    await more;
    final tier = c.route.value!.tier(TaxiTierKey.onRoute)!;
    expect(tier.items.map((e) => e.id), ['fresh']);
    expect(tier.hasMore, isTrue);
    expect(tier.nextToken, 'q2');
    expect(c.loadingTiers, isEmpty);
  });

  group('IST midnight', () {
    test('untilNextDay counts to 18:30 UTC', () {
      expect(TaxiJourneyDate.untilNextDay(DateTime.utc(2026, 11, 26, 18, 29)), const Duration(minutes: 1));
      expect(TaxiJourneyDate.untilNextDay(DateTime.utc(2026, 11, 26, 18, 30)), const Duration(hours: 24));
      expect(TaxiJourneyDate.untilNextDay(DateTime.utc(2026, 11, 26, 6)), const Duration(hours: 12, minutes: 30));
    });

    test('a page on today moves to the new today at midnight', () async {
      repo.routeFor = (d, _) => _feed('day-$d');
      now = DateTime.utc(2026, 11, 26, 18, 29);
      final c = make();
      await settle();
      expect(c.isToday, isTrue);
      expect(c.canPrev, isFalse);
      c.checkDay();
      expect(c.date.value, DateTime(2026, 11, 26));
      now = DateTime.utc(2026, 11, 26, 18, 31);
      c.checkDay();
      expect(c.currentDay.value, DateTime(2026, 11, 27));
      expect(c.date.value, DateTime(2026, 11, 27));
      expect(c.isToday, isTrue);
      expect(c.canPrev, isFalse);
      await _wait();
      expect(repo.routeCalls.last.date, '2026-11-27');
    });

    test('a later day stays and becomes today at midnight', () async {
      now = DateTime.utc(2026, 11, 26, 18, 29);
      final c = make(date: DateTime(2026, 11, 27));
      await settle();
      expect(c.isToday, isFalse);
      expect(c.canPrev, isTrue);
      final before = repo.routeCalls.length;
      now = DateTime.utc(2026, 11, 26, 18, 31);
      c.checkDay();
      expect(c.date.value, DateTime(2026, 11, 27));
      expect(c.isToday, isTrue);
      expect(c.canPrev, isFalse);
      await _wait();
      expect(repo.routeCalls.length, before);
    });

    test('pull to refresh after midnight asks for the new today', () async {
      now = DateTime.utc(2026, 11, 26, 18, 29);
      final c = make();
      await settle();
      now = DateTime.utc(2026, 11, 26, 18, 31);
      await c.pullRefresh();
      expect(c.date.value, DateTime(2026, 11, 27));
      expect(repo.routeCalls.last.date, '2026-11-27');
    });
  });

  test('the bar follows the day the server answered', () async {
    repo.routeFeed = _feed('a', date: '2026-11-27');
    final c = make();
    await settle();
    expect(c.date.value, DateTime(2026, 11, 27));
    expect(repo.routeCalls, hasLength(1));
  });

  test('a past date in the arguments starts on today', () async {
    final c = make(date: DateTime(2026, 11, 1));
    expect(c.date.value, DateTime(2026, 11, 26));
    expect(c.isToday, isTrue);
    await settle();
  });

  group('ways entry check', () {
    test('asks once per page with the same From and To', () async {
      final c = make();
      await settle();
      c.nextDay();
      await _wait();
      expect(ways.calls, hasLength(1));
      expect(ways.calls.single.fromLat, 29.2);
      expect(ways.calls.single.toLat, 29.4);
      expect(c.waysCheck.isAvailable, isTrue);
    });

    test('false and failed answers leave the card off', () async {
      ways.answer = false;
      final c = make();
      await settle();
      expect(c.waysCheck.state.value, WaysAvailability.unavailable);
      Get.reset();
      ways = FakeWaysRepo()..error = StateError('503');
      final c2 = make();
      await settle();
      expect(c2.waysCheck.state.value, WaysAvailability.failed);
      expect(c2.waysCheck.isAvailable, isFalse);
    });

    test('my location flag is passed through', () async {
      make(nearYou: true);
      await settle();
      expect(ways.calls.single.fromMyLocation, isTrue);
    });

    test('closing the page resets the check', () async {
      final c = make();
      await settle();
      expect(c.waysCheck.isAvailable, isTrue);
      Get.delete<TaxiResultsController>(tag: TaxiResultsController.tag);
      expect(c.waysCheck.state.value, WaysAvailability.idle);
    });
  });

  group('arguments', () {
    final today = DateTime(2026, 11, 26);

    test('round trip', () {
      final a = TaxiResultsArgs(
        from: PlaceResult(name: 'Delhi', subtitle: '', latLng: const LatLng(28.6, 77.2)),
        fromNearYou: false,
        to: PlaceResult(name: 'Rishikesh', subtitle: '', latLng: const LatLng(30.1, 78.3)),
        date: DateTime(2026, 11, 28),
      );
      final b = TaxiResultsArgs.fromMap(a.toMap(), today)!;
      expect(b.from.name, 'Delhi');
      expect(b.to.latLng.latitude, 30.1);
      // maplibre LatLng normalises longitude with (lng + 180) % 360 - 180, which moves the last bit.
      expect(b.to.latLng.longitude, closeTo(78.3, 1e-9));
      expect(b.date, DateTime(2026, 11, 28));
      expect(a.toMap()['date'], '2026-11-28');
      expect(b.cities, isNull);
      expect(a.toMap().containsKey('fromCityKey'), isFalse);
    });

    test('city pair round trip, dropped for a near-you From', () {
      final a = TaxiResultsArgs(
        from: PlaceResult(name: 'Delhi', subtitle: '', latLng: const LatLng(28.6, 77.2)),
        fromNearYou: false,
        to: PlaceResult(name: 'Rishikesh', subtitle: '', latLng: const LatLng(30.1, 78.3)),
        date: DateTime(2026, 11, 28),
        cities: const TaxiCityPair(101, 245),
      );
      expect(a.toMap()['fromCityKey'], 101);
      expect(a.toMap()['toCityKey'], 245);
      expect(TaxiResultsArgs.fromMap(a.toMap(), today)!.cities, const TaxiCityPair(101, 245));
      final near = {...a.toMap(), 'fromNearYou': true};
      expect(TaxiResultsArgs.fromMap(near, today)!.cities, isNull);
    });

    test('bad coordinates give null, bad dates fall back to today', () {
      expect(TaxiResultsArgs.fromMap(null, today), isNull);
      expect(TaxiResultsArgs.fromMap({'fromLat': 1, 'fromLng': 2, 'toLat': 'x', 'toLng': 3}, today), isNull);
      final b = TaxiResultsArgs.fromMap({'fromLat': 1, 'fromLng': 2, 'toLat': 3, 'toLng': 4, 'date': 'soon', 'fromNearYou': true}, today)!;
      expect(b.date, today);
      expect(b.from.name, 'Near you');
      expect(b.fromNearYou, isTrue);
      final far = TaxiResultsArgs.fromMap({'fromLat': 1, 'fromLng': 2, 'toLat': 3, 'toLng': 4, 'date': '2027-06-01'}, today)!;
      expect(far.date, TaxiJourneyDate.last(today));
    });
  });

  test('request keys stay unique per pair, day and sort', () {
    final k1 = TaxiSeekerCache.routeKey(fromLat: 1, fromLng: 2, toLat: 3, toLng: 4, date: '2026-11-26', sort: 'nearest');
    final k2 = TaxiSeekerCache.routeKey(fromLat: 1, fromLng: 2, toLat: 3, toLng: 4, date: '2026-11-26', sort: 'cheapest');
    expect(k1 == k2, isFalse);
    final k3 = TaxiSeekerCache.routeKey(fromLat: 1, fromLng: 2, toLat: 3, toLng: 4, date: '2026-11-26', sort: 'nearest', cities: const TaxiCityPair(101, 245));
    expect(k3 == k1, isFalse);
    for (var i = 0; i < 20; i++) {
      TaxiSeekerCache.putRoute('k$i', const TaxiRouteFeed(), DateTime(2026));
    }
    expect(TaxiSeekerCache.route('k0', DateTime(2026)), isNull);
    expect(TaxiSeekerCache.route('k19', DateTime(2026)), isNotNull);
  });

  test('stale guard keeps a fully disposed page quiet', () async {
    repo.gateRoutes = true;
    final c = make();
    await settle();
    Get.delete<TaxiResultsController>(tag: TaxiResultsController.tag);
    repo.routeGates.single.complete(_feed('late'));
    await settle();
    expect(c.route.value, isNull);
  });
}
