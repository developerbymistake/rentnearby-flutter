import 'dart:async';

import 'package:bakhli/features/map_discovery/data/map_pack_discovery_source.dart';
import 'package:bakhli/features/map_discovery/data/map_pack_service.dart';
import 'package:bakhli/features/map_discovery/data/map_pack_store.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_constants.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_models.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_synthetic.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/discovery_tiers.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/fake_map_pack_api.dart';

void main() {
  late FakeMapPackApi api;
  late FakeVersion version;
  late FakeClock clock;
  late List<TripCityModel> cities;

  MapPackService make() => MapPackService(
        api: api,
        versionCall: version.call,
        citiesOf: (keys) => cities.where((c) => keys.contains(c.cityKey)),
        now: clock.call,
      );

  setUpAll(() => initMapPackTestStorage('map_pack_service'));
  setUp(() async {
    Get.reset();
    await resetMapPackStore();
    api = FakeMapPackApi();
    version = FakeVersion();
    clock = FakeClock();
    cities = [city(1, state: 'State One'), city(2, state: 'State One'), city(7, state: 'State Two', lat: 32, lon: 77)];
  });
  tearDownAll(() => MapPackStore.debugUseBox(null));

  test('first ensure: version call, one download, stored, ready', () async {
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    api.body('s1', packBody());
    final s = make();
    await s.ensureForCities([1, 2]);
    expect(version.calls, 1);
    expect(api.count, 1);
    expect(api.calls.single.etag, isNull);
    expect(s.status.value, MapPackStatus.ready);
    expect(s.index!.length, 20);
    expect(MapPackStore.readVersion('s1'), 'v1');
    expect(MapPackStore.readBody('s1'), isNotNull);
    expect(s.source.state.value, DiscoveryDataState.ready);
  });

  group('APP-7 a 404 of the versioned URL (newer pack on the server)', () {
    test('404 on v1: exactly one version call and one request for v2, then the index is ready', () async {
      version.answer(ver(packs: [ref('s1', name: 'State One')]));
      version.answer(ver(packs: [ref('s1', name: 'State One', version: 'v2')]));
      api.gone('s1');
      api.body('s1', packBody(version: 'v2'));
      final s = make();
      await s.ensureForCities([1]);
      await s.settle();
      expect(version.calls, 2, reason: 'the first version call plus ONE refresh after the 404');
      expect(api.calls.map((c) => c.path), ['/trips/map-packs/s1/v1', '/trips/map-packs/s1/v2']);
      expect(s.status.value, MapPackStatus.ready);
      expect(s.index!.length, 20);
      expect(MapPackStore.readVersion('s1'), 'v2');
    });

    test('404 with an unchanged ref: one refresh, then the back-off holds (100 ensure calls inside 60 s = 0 requests)', () async {
      version.answer(ver(packs: [ref('s1', name: 'State One')]));
      api.gone('s1');
      final s = make();
      await s.ensureForCities([1]);
      await s.settle();
      expect(version.calls, 2);
      expect(api.count, 1);
      for (var i = 0; i < 100; i++) {
        clock.advance(const Duration(milliseconds: 500));
        await s.ensureForCities([1]);
      }
      expect(api.count, 1);
      expect(version.calls, 2);
      expect(s.status.value, isNot(MapPackStatus.ready));
    });
  });

  test('T3: corrupt bodies are refused; the old pack stays in memory and on disk', () async {
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    api.body('s1', packBody());
    final s = make();
    await s.ensureForCities([1]);
    final oldBody = MapPackStore.readBody('s1');
    var expected = 1;
    for (final bad in [
      'not json',
      '[1,2]',
      '{"fields":["lat","lon","name"],"s":[]}',
      '{"fields":["id","lat","lon","name"],"s":{}}',
      '{"fields":["id","lat","lon","name"],"s":[],"pad":"${'x' * (MapPackConstants.maxBodyChars + 1)}"}',
    ]) {
      clock.advance(const Duration(minutes: 11));
      version.answer(ver(packs: [ref('s1', name: 'State One', version: 'v-${bad.length}')]));
      api.body('s1', bad);
      await s.ensureForCities([1]);
      expect(api.countFor('s1'), ++expected);
      expect(s.index!.length, 20, reason: bad.length > 10 ? bad.substring(0, 10) : bad);
      expect(MapPackStore.readBody('s1'), oldBody);
      expect(MapPackStore.readVersion('s1'), 'v1');
    }
  });

  test('D8: a corrupt body on disk is dropped and downloaded again', () async {
    MapPackStore.save('s1', 'v1', 'garbage');
    MapPackStore.writeMeta({'flag': true, 'refs': [ref('s1', name: 'State One').toJson()], 'refsAtMs': clock.value.millisecondsSinceEpoch});
    api.body('s1', packBody());
    final s = make();
    await s.ensureForCities([1]);
    expect(version.calls, 0);
    expect(api.count, 1);
    expect(s.index!.length, 20);
    expect(MapPackStore.readBody('s1'), isNot('garbage'));
  });

  test('T4: an empty valid pack is stored and ready with an empty index', () async {
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    api.body('s1', packBody(rows: 0));
    final s = make();
    await s.ensureForCities([1]);
    expect(s.status.value, MapPackStatus.ready);
    expect(s.index, isNotNull);
    expect(s.index!.isEmpty, true);
    expect(MapPackStore.readBody('s1'), isNotNull);
  });

  test('T5: 1,500 rows parse off the frame, index and tiers are exact', () async {
    final body = MapPackSynthetic.body(rows: 1500, withThumb: 300, state: 's1', version: 'v1');
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    api.body('s1', body);
    final s = make();
    final sw = Stopwatch()..start();
    await s.ensureForCities([1]);
    sw.stop();
    // ignore: avoid_print
    print('T5 ensure with 1500 rows (${body.length} chars): ${sw.elapsedMilliseconds} ms');
    final idx = s.index!;
    expect(idx.length, 1500);
    final c3 = idx.byCity(3);
    expect(c3, isNotEmpty);
    for (var i = 1; i < c3.length; i++) {
      expect(c3[i - 1].rank <= c3[i].rank, true);
    }
    final top = DiscTiers.topPhotos(idx.ranked, DiscTuning.trip.photoMax);
    expect(top.length, 40);
    expect(top.every((p) => p.hasThumb), true);
    expect(s.source.forCities([3]).length, c3.length);
    expect(s.source.all().length, 1500);
  });

  test('T7: failed download keeps the old pack; back-off blocks a retry for 60 s', () async {
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    api.body('s1', packBody());
    final s = make();
    await s.ensureForCities([1]);
    clock.advance(const Duration(minutes: 11));
    version.answer(ver(packs: [ref('s1', name: 'State One', version: 'v2')]));
    api.fail('s1');
    await s.ensureForCities([1]);
    expect(api.countFor('s1'), 2);
    expect(s.index!.length, 20);
    expect(MapPackStore.readVersion('s1'), 'v1');
    clock.advance(const Duration(seconds: 30));
    await s.ensureForCities([1]);
    expect(api.countFor('s1'), 2);
    clock.advance(const Duration(seconds: 31));
    api.body('s1', packBody(rows: 5, version: 'v2'));
    await s.ensureForCities([1]);
    expect(api.countFor('s1'), 3);
    expect(api.calls.last.etag, 'v1');
    expect(s.index!.length, 5);
    expect(MapPackStore.readVersion('s1'), 'v2');
  });

  test('T8: two concurrent ensures for the same state make one request', () async {
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    final gate = Completer<void>();
    final body = packBody();
    api.enqueue('s1', (_, _) async {
      await gate.future;
      return (notModified: false, body: body, gone: false);
    });
    final s = make();
    final a = s.ensureForCities([1]);
    final b = s.ensureForCities([2]);
    await pumpEventQueue();
    expect(s.status.value, MapPackStatus.loading);
    expect(s.source.state.value, DiscoveryDataState.loading);
    gate.complete();
    await Future.wait([a, b]);
    expect(api.count, 1);
    expect(version.calls, 1);
    expect(s.status.value, MapPackStatus.ready);
  });

  test('T10: offline start serves the stored pack, no crash', () async {
    MapPackStore.save('s1', 'v1', packBody());
    MapPackStore.writeMeta({'flag': true, 'refs': [ref('s1', name: 'State One').toJson()], 'refsAtMs': 0});
    version.throwNext();
    final s = make();
    await s.ensureForCities([1]);
    expect(version.calls, 1);
    expect(api.count, 0);
    expect(s.enabled, true);
    expect(s.status.value, MapPackStatus.ready);
    expect(s.index!.length, 20);
  });

  test('D14: no pack and no network -> none; version call backs off', () async {
    version.throwNext();
    final s = make();
    await s.ensureForCities([1]);
    expect(s.status.value, MapPackStatus.off);
    expect(s.index, isNull);
    await s.ensureForCities([1]);
    expect(version.calls, 1);
  });

  test('T11: wipe during an in-flight download swaps nothing and writes nothing', () async {
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    final gate = Completer<void>();
    final body = packBody();
    api.enqueue('s1', (_, _) async {
      await gate.future;
      return (notModified: false, body: body, gone: false);
    });
    final s = make();
    final f = s.ensureForCities([1]);
    await pumpEventQueue();
    final rev = s.revision.value;
    await s.wipe();
    expect(s.revision.value, rev + 1);
    gate.complete();
    await f;
    await s.settle();
    expect(s.index, isNull);
    expect(s.status.value, MapPackStatus.none);
    expect(mapPackTestBox.getKeys<Iterable<dynamic>>(), isEmpty);
  });

  test('wipe after a load drops memory, flag and box', () async {
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    api.body('s1', packBody());
    final s = make();
    await s.ensureForCities([1]);
    await s.wipe();
    expect(s.enabled, false);
    expect(s.index, isNull);
    expect(s.source.all(), isEmpty);
    expect(MapPackStore.storedStates(), isEmpty);
  });

  test('T13: a state removed from packs is dropped from disk and memory', () async {
    version.answer(ver(packs: [ref('s1', name: 'State One'), ref('s2', name: 'State Two')]));
    api.body('s1', packBody());
    api.body('s2', packBody(state: 's2', seed: 2, lat: 32, lon: 77));
    final s = make();
    await s.ensureForCities([1, 7]);
    expect(s.index!.length, 40);
    s.onVersion(ver(packs: [ref('s1', name: 'State One')]));
    await s.settle();
    expect(MapPackStore.storedStates(), ['s1']);
    expect(s.index!.length, 20);
    expect(s.index!.stateIds, ['s1']);
  });

  test('T14: pick by state name (folded), then bbox, then the first 4 refs', () async {
    final refs = [
      ref('a', name: 'Other'),
      ref('b', name: 'state  ONE'),
      ref('c', bbox: [76, 31, 78, 33]),
      ref('d'),
      ref('e'),
    ];
    version.answer(ver(packs: refs));
    api.fallback = (r, _) => (notModified: false, body: packBody(state: r.stateId, rows: 2, seed: r.stateId.codeUnitAt(0)), gone: false);
    final s = make();
    await s.ensureForCities([1]);
    expect(api.calls.map((c) => c.stateId), ['b']);
    await s.ensureForCities([7]);
    expect(api.calls.map((c) => c.stateId), ['b', 'c']);
    cities.add(city(9, state: '', lat: 10, lon: 10));
    await s.ensureForCities([9]);
    expect(api.calls.map((c) => c.stateId).toSet(), {'a', 'b', 'c', 'd'});
  });

  test('T14: ensureForPoint picks by bbox, else the first refs', () async {
    version.answer(ver(packs: [ref('a'), ref('c', bbox: [76, 31, 78, 33])]));
    api.fallback = (r, _) => (notModified: false, body: packBody(state: r.stateId, rows: 2), gone: false);
    final s = make();
    await s.ensureForPoint(32, 77);
    expect(api.calls.map((c) => c.stateId), ['c']);
    await s.ensureForPoint(10, 10);
    expect(api.calls.map((c) => c.stateId), ['c', 'a']);
  });

  test('L-09: a point outside every bbox downloads nothing', () async {
    version.answer(ver(packs: [ref('a', bbox: [76, 31, 78, 33]), ref('c', bbox: [78, 29, 81, 31])]));
    api.fallback = (r, _) => (notModified: false, body: packBody(state: r.stateId, rows: 2), gone: false);
    final s = make();
    await s.ensureForPoint(12.9, 77.6);
    expect(api.count, 0);
  });

  test('L-12: a body of another version or state is refused, nothing stored', () async {
    version.answer(ver(packs: [ref('s1', name: 'State One', version: 'v2')]));
    api.body('s1', packBody(version: 'v9'));
    final s = make();
    await s.ensureForCities([1]);
    expect(s.index, isNull);
    expect(MapPackStore.readVersion('s1'), isNull);
  });

  test('T12: a ref path on another host is never fetched, the state is missing', () async {
    version.answer(ver(packs: [ref('s1', name: 'State One', path: 'https://evil.example.com/p')]));
    api.fallback = (_, _) => (notModified: false, body: packBody(), gone: false);
    final s = make();
    await s.ensureForCities([1]);
    expect(s.index, isNull);
    expect(s.status.value, MapPackStatus.none);
  });

  test('T17: 100 camera moves call nothing on the service network side', () async {
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    api.body('s1', packBody());
    final s = make();
    final DiscoveryDataSource src = s.source;
    await src.ensureForCities([1]);
    final apiCalls = api.count;
    final versionCalls = version.calls;
    final rev = s.revision.value;
    for (var i = 0; i < 100; i++) {
      src.near(30 + i / 1000, 78, 5);
      src.forCities([1, 2]);
      src.all();
      src.byId('syn-1-$i');
      expect(src.enabled, true);
      expect(src.version, rev);
    }
    expect(api.count, apiCalls);
    expect(version.calls, versionCalls);
  });

  test('source maps status and reads the merged index', () async {
    expect(MapPackDiscoverySource.of(MapPackStatus.off), DiscoveryDataState.none);
    expect(MapPackDiscoverySource.of(MapPackStatus.none), DiscoveryDataState.none);
    expect(MapPackDiscoverySource.of(MapPackStatus.loading), DiscoveryDataState.loading);
    expect(MapPackDiscoverySource.of(MapPackStatus.ready), DiscoveryDataState.ready);
    final s = make();
    expect(s.source.all(), isEmpty);
    expect(s.source.byId('x'), isNull);
    expect(s.source.near(30, 78, 10), isEmpty);
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    api.body('s1', packBody());
    await s.source.ensureForCities([1]);
    final first = s.source.all().first;
    expect(s.source.byId(first.id), same(first));
    expect(first.stateId, 's1');
    expect(s.source.near(first.lat, first.lon, 1), contains(first));
  });

  test('ensure opens its own box lazily when no test box is set and never throws', () async {
    MapPackStore.debugUseBox(null);
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    api.body('s1', packBody());
    final s = make();
    await s.ensureForCities([1]);
    await s.ensureForPoint(double.nan, 1);
    expect(s.status.value, isNot(MapPackStatus.loading));
  });
}
