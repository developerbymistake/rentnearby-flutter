import 'dart:io';

import 'package:bakhli/features/map_discovery/data/map_pack_service.dart';
import 'package:bakhli/features/map_discovery/data/map_pack_store.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_models.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_parser.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/fake_map_pack_api.dart';

// Journeys of the state map pack with the golden bytes produced by Atlas (same files as the Atlas and
// main backend tests; tools/map_pack/check_golden.ps1 compares the three copies).
const _state = '0b6e1f2a-3c4d-4e5f-8a9b-0c1d2e3f4a5b';
const _v1 = 'a7dc2cc534fc7243';
const _vCover = '9fe966ff62737494';
const _vRemoved = 'ad70ac8117d71816';
const _img = 'https://res.cloudinary.com/demo/image/upload/';

String golden(String name) => File('test/features/map_discovery/fixtures/golden_$name.json').readAsStringSync();

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

  MapPackRef refOf(String v) => ref(_state, version: v, name: 'Test State');

  setUpAll(() => initMapPackTestStorage('map_pack_journey'));
  setUp(() async {
    Get.reset();
    await resetMapPackStore();
    api = FakeMapPackApi();
    version = FakeVersion();
    clock = FakeClock();
    cities = [city(210045678, state: 'Test State'), city(210045302, state: 'Test State')];
  });
  tearDownAll(() => MapPackStore.debugUseBox(null));

  test('golden pack: every wire shape parses to the exact values', () {
    final p = MapPackParser.parse(golden('pack'))!;
    expect(p.version, _v1);
    expect(p.stateId, _state);
    expect(p.spots.map((s) => s.id), [
      'osm:n123',
      'osm:w77',
      'osm:n9',
      'osm:n10',
      'osm:n11',
      'admin:6f1c0000-0000-0000-0000-000000000001',
    ]);
    expect(p.spots.map((s) => s.rank), [1, 2, 3, 4, 5, 6]);
    final a = p.spots[0];
    expect(a.lat, 32.24316);
    expect(a.lon, 77.18922);
    expect(a.category, 'temple');
    expect(a.cityKey, 210045678);
    expect(a.thumbUrl, '${_img}v1731/atlas/spots/a/b.jpg');
    expect(a.nPhotos, 3);
    expect(p.spots[1].thumbUrl, isNull);
    expect(p.spots[1].nPhotos, 0);
    expect(p.spots[2].name, 'Caf\u00e9 Gh\u0101t \u2013 \u0938\u0902\u0917\u092e');
    expect(p.spots[2].category, 'Some New Kind');
    expect(p.spots[2].thumbUrl, 'https://example.com/x/y.jpg');
    expect(p.spots[3].lon, 79);
    expect(p.spots[4].name, r'Quote "Peak" \ Pass');
    expect(p.spots[5].category, 'viewpoint');
  });

  test('golden pack: cover and removed variants differ exactly where Atlas changed them', () {
    final v1 = MapPackParser.parse(golden('pack'))!;
    final cover = MapPackParser.parse(golden('pack_cover'))!;
    final removed = MapPackParser.parse(golden('pack_removed'))!;
    expect(cover.version, _vCover);
    expect(removed.version, _vRemoved);
    expect(cover.spots.length, 6);
    expect(removed.spots.length, 5);
    expect(removed.spots.any((s) => s.id == 'osm:n10'), false);
    final w77 = cover.spots.firstWhere((s) => s.id == 'osm:w77');
    expect(w77.thumbUrl, '${_img}v1799/atlas/spots/e/f.jpg');
    expect(w77.nPhotos, 1);
    expect(v1.spots.firstWhere((s) => s.id == 'osm:w77').thumbUrl, isNull);
  });

  test('J1 admin edits a photo: version moves, new pack downloaded, index swapped, store follows', () async {
    version.answer(ver(packs: [refOf(_v1)]));
    api.body(_state, golden('pack'));
    final s = make();
    await s.ensureForCities([210045678]);
    expect(s.index!.byId('osm:w77')!.thumbUrl, isNull);

    clock.advance(const Duration(minutes: 11));
    version.answer(ver(packs: [refOf(_vCover)]));
    api.body(_state, golden('pack_cover'));
    await s.ensureForCities([210045678]);

    expect(api.countFor(_state), 2);
    expect(api.calls.last.etag, _v1);
    expect(s.index!.byId('osm:w77')!.thumbUrl, '${_img}v1799/atlas/spots/e/f.jpg');
    expect(MapPackStore.readVersion(_state), _vCover);
  });

  test('J2 delete or unassign: the removed spot leaves the map after the swap', () async {
    version.answer(ver(packs: [refOf(_v1)]));
    api.body(_state, golden('pack'));
    final s = make();
    await s.ensureForCities([210045678]);
    expect(s.index!.byId('osm:n10'), isNotNull);

    clock.advance(const Duration(minutes: 11));
    version.answer(ver(packs: [refOf(_vRemoved)]));
    api.body(_state, golden('pack_removed'));
    await s.ensureForCities([210045678]);

    expect(s.index!.length, 5);
    expect(s.index!.byId('osm:n10'), isNull);
    expect(s.source.all().length, 5);
  });

  test('J3 a corrupt new pack is refused: the stale pack stays in memory and on disk', () async {
    version.answer(ver(packs: [refOf(_v1)]));
    api.body(_state, golden('pack'));
    final s = make();
    await s.ensureForCities([210045678]);
    final stored = MapPackStore.readBody(_state);

    clock.advance(const Duration(minutes: 11));
    version.answer(ver(packs: [refOf(_vCover)]));
    final cover = golden('pack_cover');
    api.body(_state, cover.substring(0, cover.length ~/ 2));
    await s.ensureForCities([210045678]);

    expect(s.index!.length, 6);
    expect(s.index!.byId('osm:w77')!.thumbUrl, isNull);
    expect(MapPackStore.readBody(_state), stored);
    expect(MapPackStore.readVersion(_state), _v1);
  });

  test('J4 flag off: no download on a cold start, and a loaded index is dropped', () async {
    version.answer(ver(flag: false, packs: [refOf(_v1)]));
    final cold = make();
    await cold.ensureForCities([210045678]);
    expect(api.count, 0);
    expect(cold.index, isNull);
    expect(cold.enabled, false);

    await resetMapPackStore();
    version.answer(ver(packs: [refOf(_v1)]));
    api.body(_state, golden('pack'));
    final s = make();
    await s.ensureForCities([210045678]);
    expect(s.index!.length, 6);
    s.onVersion(ver(flag: false, packs: [refOf(_v1)]));
    expect(s.index, isNull);
    expect(s.enabled, false);
  });

  test('J5 offline restart: the stored golden pack serves with no network call', () async {
    MapPackStore.save(_state, _v1, golden('pack'));
    MapPackStore.writeMeta({'flag': true, 'refs': [refOf(_v1).toJson()], 'refsAtMs': 0});
    version.throwNext();
    final s = make();
    await s.ensureForCities([210045678]);

    expect(api.count, 0);
    expect(s.index!.length, 6);
    expect(s.index!.byCity(210045302).map((e) => e.id), ['osm:n9', 'osm:n10', 'admin:6f1c0000-0000-0000-0000-000000000001']);
  });
}
