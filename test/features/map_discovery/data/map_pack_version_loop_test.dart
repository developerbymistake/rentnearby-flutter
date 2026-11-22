import 'package:bakhli/features/map_discovery/data/map_pack_service.dart';
import 'package:bakhli/features/map_discovery/data/map_pack_store.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_models.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/fake_map_pack_api.dart';

void main() {
  late FakeMapPackApi api;
  late FakeVersion version;
  late FakeClock clock;

  MapPackService make() => MapPackService(
        api: api,
        versionCall: version.call,
        citiesOf: (keys) => [for (final k in keys) city(k, state: 'State One')],
        now: clock.call,
      );

  setUpAll(() => initMapPackTestStorage('map_pack_version_loop'));
  setUp(() async {
    Get.reset();
    await resetMapPackStore();
    api = FakeMapPackApi();
    version = FakeVersion();
    clock = FakeClock();
  });
  tearDownAll(() => MapPackStore.debugUseBox(null));

  Future<MapPackService> loaded() async {
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    api.body('s1', packBody());
    final s = make();
    await s.ensureForCities([1]);
    return s;
  }

  test('T6: same version -> zero pack requests', () async {
    final s = await loaded();
    s.onVersion(ver(packs: [ref('s1', name: 'State One')]));
    await s.settle();
    clock.advance(const Duration(minutes: 11));
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    await s.ensureForCities([1]);
    expect(api.count, 1);
  });

  test('T6: version differs -> exactly one request with If-None-Match of the old version; 304 keeps body, stamps version', () async {
    final s = await loaded();
    final body = MapPackStore.readBody('s1');
    api.notModified('s1');
    s.onVersion(ver(packs: [ref('s1', name: 'State One', version: 'v2')]));
    await s.settle();
    expect(api.count, 2);
    expect(api.calls.last.etag, 'v1');
    expect(MapPackStore.readBody('s1'), body);
    expect(MapPackStore.readVersion('s1'), 'v2');
    s.onVersion(ver(packs: [ref('s1', name: 'State One', version: 'v2')]));
    await s.settle();
    expect(api.count, 2);
    expect(s.index!.length, 20);
  });

  test('onVersion refreshes only packs already on disk; nothing new is fetched in the background', () async {
    final s = await loaded();
    s.onVersion(ver(packs: [ref('s1', name: 'State One'), ref('s2', name: 'State Two')]));
    await s.settle();
    expect(api.countFor('s2'), 0);
  });

  test('ensure within 10 minutes makes no version call; after 10 minutes exactly one', () async {
    final s = await loaded();
    clock.advance(const Duration(minutes: 9));
    await s.ensureForCities([1]);
    expect(version.calls, 1);
    clock.advance(const Duration(minutes: 2));
    version.answer(ver(packs: [ref('s1', name: 'State One')]));
    await s.ensureForCities([1]);
    await s.ensureForCities([1]);
    expect(version.calls, 2);
  });

  test('L-01: an empty packs list the server does not know yet keeps stored packs', () async {
    final s = await loaded();
    s.onVersion(ver(packs: const []));
    await s.settle();
    expect(MapPackStore.readBody('s1'), isNotNull);
    expect(s.index, isNotNull);
    s.onVersion(ver(packs: const [], packsKnown: true));
    await s.settle();
    expect(MapPackStore.readBody('s1'), isNull, reason: 'a known empty list drops the stored packs (CF-journey D-2)');
  });

  test('L-01: packsKnown parsed; missing = true only when packs is non-empty', () {
    expect(TripCityVersion.fromJson({'packsKnown': false, 'packs': []}).packsKnown, isFalse);
    expect(TripCityVersion.fromJson({'packs': []}).packsKnown, isFalse);
    expect(TripCityVersion.fromJson({'packsKnown': true}).packsKnown, isTrue);
  });

  test('L-03: empty refs: one version call for four ensures inside 10 minutes', () async {
    version.answer(ver(packs: const []));
    final s = make();
    await s.ensureForCities([1]);
    await s.ensureForCities([1]);
    await s.ensureForPoint(30, 78);
    await s.ensureForPoint(30, 78);
    expect(version.calls, 1);
  });

  test('a version answer handed in by the catalog stamps refsAt, so ensure skips its own call', () async {
    final s = make();
    s.onVersion(ver(packs: [ref('s1', name: 'State One')]));
    api.body('s1', packBody());
    await s.ensureForCities([1]);
    expect(version.calls, 0);
    expect(api.count, 1);
  });

  test('T9: flag off -> disabled, off, no request, index null, disk kept; on again -> index back with zero requests', () async {
    final s = await loaded();
    final rev = s.revision.value;
    s.onVersion(ver(flag: false, packs: [ref('s1', name: 'State One')]));
    await s.settle();
    expect(s.enabled, false);
    expect(s.status.value, MapPackStatus.off);
    expect(s.index, isNull);
    expect(s.source.all(), isEmpty);
    expect(s.revision.value, greaterThan(rev));
    expect(MapPackStore.readBody('s1'), isNotNull);
    await s.ensureForCities([1]);
    expect(api.count, 1);
    s.onVersion(ver(packs: [ref('s1', name: 'State One')]));
    await s.settle();
    expect(s.enabled, true);
    expect(s.index!.length, 20);
    expect(api.count, 1);
  });

  test('flag and refs survive a restart (meta); an offline start behaves like the last online one', () async {
    await loaded();
    final s2 = make();
    version.throwNext();
    clock.advance(const Duration(hours: 1));
    await s2.ensureForCities([1]);
    expect(s2.enabled, true);
    expect(s2.index!.length, 20);
    expect(api.count, 1);
  });

  test('meta is written only when flag or refs change', () async {
    final s = await loaded();
    final first = MapPackStore.readMeta();
    clock.advance(const Duration(minutes: 30));
    s.onVersion(ver(packs: [ref('s1', name: 'State One')]));
    await s.settle();
    expect(MapPackStore.readMeta(), first);
    s.onVersion(ver(flag: false, packs: [ref('s1', name: 'State One')]));
    await s.settle();
    expect(MapPackStore.readMeta()?['flag'], false);
  });

  group('T15: TripCityVersion.fromJson', () {
    test('old server answer: no new fields -> flag false, no packs', () {
      final v = TripCityVersion.fromJson({'version': 'x', 'count': 3, 'stale': false});
      expect(v.version, 'x');
      expect(v.count, 3);
      expect(v.mapDiscovery, false);
      expect(v.packs, isEmpty);
    });

    test('new fields parsed; stateId stringified; bad refs skipped', () {
      final v = TripCityVersion.fromJson({
        'version': 'x',
        'count': 3,
        'stale': false,
        'mapDiscovery': true,
        'packs': [
          {'stateId': 5, 'stateName': 'State One', 'version': 'p1', 'path': '/trips/map-packs/5/p1', 'bbox': [76, 29, 81, 31.5], 'count': 1500},
          {'stateId': 'a1b2', 'version': 'p2', 'path': '/trips/map-packs/a1b2/p2', 'bbox': [1, 2, 3]},
          {'stateId': 6, 'version': '', 'path': '/x'},
          {'version': 'p3', 'path': '/x'},
          {'stateId': 8, 'version': 'p3'},
          'junk',
          null,
        ],
      });
      expect(v.mapDiscovery, true);
      expect(v.packs.map((r) => r.stateId), ['5', 'a1b2']);
      expect(v.packs.first.bbox, [76, 29, 81, 31.5]);
      expect(v.packs.first.stateName, 'State One');
      expect(v.packs[1].bbox, isNull);
      expect(v.packs.first.contains(30, 78), true);
    });

    test('wrong types: flag not bool, packs not a list', () {
      for (final flag in ['true', 1, null, <String, dynamic>{}]) {
        expect(TripCityVersion.fromJson({'version': 'x', 'mapDiscovery': flag}).mapDiscovery, false);
      }
      for (final packs in ['x', 3, {'a': 1}, null]) {
        expect(TripCityVersion.fromJson({'version': 'x', 'packs': packs}).packs, isEmpty);
      }
    });

    test('const constructor keeps old call sites valid', () {
      const v = TripCityVersion(version: 'a', count: 0, stale: false);
      expect(v.mapDiscovery, false);
      expect(v.packs, const <MapPackRef>[]);
    });
  });
}
