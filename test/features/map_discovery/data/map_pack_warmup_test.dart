import 'package:bakhli/features/map_discovery/data/map_pack_service.dart';
import 'package:bakhli/features/map_discovery/data/map_pack_store.dart';
import 'package:bakhli/features/map_discovery/data/map_pack_warmup.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_models.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../support/fake_map_pack_api.dart';

TripSummaryModel _trip(String id, List<String> cities) => TripSummaryModel(
      id: id,
      title: id,
      status: 'Draft',
      cityName: cities.first,
      dayCount: 2,
      spotCount: 0,
      category: '',
      updatedAt: DateTime(2026, 11, 24),
      legCount: cities.length,
      legCities: cities,
    );

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

  setUpAll(() => initMapPackTestStorage('map_pack_warmup'));
  setUp(() async {
    Get.reset();
    await resetMapPackStore();
    api = FakeMapPackApi();
    version = FakeVersion();
    clock = FakeClock();
    cities = [city(1, state: 'State One'), city(7, state: 'State Two', lat: 32, lon: 77)];
  });
  tearDownAll(() => MapPackStore.debugUseBox(null));

  group('MapPackService.warm', () {
    test('the user point and the trip cities are downloaded to disk; a later map open needs no download', () async {
      version.answer(ver(packs: [
        ref('s1', name: 'State One', bbox: [77.5, 29.5, 78.5, 30.5]),
        ref('s2', name: 'State Two', bbox: [76.5, 31.5, 77.5, 32.5]),
        ref('s3', name: 'State Three', bbox: [70, 20, 71, 21]),
      ]));
      api.body('s1', packBody());
      api.body('s2', packBody(state: 's2', seed: 2, lat: 32, lon: 77));
      final s = make();
      await s.warm(lat: 30, lon: 78, cityKeys: [7]);
      expect(api.calls.map((c) => c.path).toSet(), {'/trips/map-packs/s1/v1', '/trips/map-packs/s2/v1'});
      expect(MapPackStore.readBody('s1'), isNotNull);
      expect(MapPackStore.readBody('s2'), isNotNull);
      expect(MapPackStore.readBody('s3'), isNull);
      expect(s.source.state.value, DiscoveryDataState.ready);
      final before = api.count;
      await s.ensureForPoint(30, 78);
      expect(api.count, before, reason: 'the stay map finds the pack in memory');
      expect(s.index!.length, 40);
    });

    test('a point outside every pack and unknown cities download nothing (no fallback pack)', () async {
      version.answer(ver(packs: [ref('s1', name: 'State One', bbox: [77.5, 29.5, 78.5, 30.5])]));
      api.body('s1', packBody());
      final s = make();
      await s.warm(lat: 10, lon: 10, cityKeys: [99]);
      expect(api.count, 0);
    });

    test('flag off: no download', () async {
      version.answer(ver(flag: false, packs: [ref('s1', name: 'State One', bbox: [77.5, 29.5, 78.5, 30.5])]));
      final s = make();
      await s.warm(lat: 30, lon: 78);
      expect(api.count, 0);
    });

    test('a fresh service reads the warmed pack from disk without a download', () async {
      version.answer(ver(packs: [ref('s1', name: 'State One', bbox: [77.5, 29.5, 78.5, 30.5])]));
      api.body('s1', packBody());
      await make().warm(lat: 30, lon: 78);
      expect(api.count, 1);
      Get.reset();
      clock.advance(const Duration(seconds: 5));
      final next = make();
      await next.ensureForPoint(30, 78);
      await next.settle();
      expect(api.count, 1);
      expect(next.status.value, MapPackStatus.ready);
    });
  });

  group('MapPackWarmup', () {
    test('warms the first GPS fix once and every new trip city once', () async {
      final calls = <({double? lat, double? lon, List<int> keys})>[];
      final w = MapPackWarmup(
        warm: ({double? lat, double? lon, Iterable<int> cityKeys = const []}) async => calls.add((lat: lat, lon: lon, keys: cityKeys.toList()..sort())),
        keysOf: (names) => [for (final n in names) if (n == 'Shimla') 7 else if (n == 'Manali') 8],
      );
      final loc = Rxn<LatLng>();
      final trips = <TripSummaryModel>[].obs;
      w.start(userLocation: loc, trips: trips);
      expect(calls, isEmpty);
      loc.value = const LatLng(30, 78);
      loc.value = const LatLng(30.1, 78.1);
      trips.assignAll([_trip('a', ['Shimla'])]);
      trips.assignAll([_trip('a', ['Shimla']), _trip('b', ['Shimla', 'Manali'])]);
      trips.assignAll([_trip('a', ['Shimla'])]);
      expect(calls.length, 3);
      expect((calls[0].lat, calls[0].lon), (30.0, 78.0));
      expect(calls[0].keys, isEmpty);
      expect(calls[1].keys, [7]);
      expect(calls[2].keys, [7, 8]);
      w.dispose();
      loc.value = const LatLng(31, 77);
      trips.assignAll([_trip('c', ['Other'])]);
      expect(calls.length, 3);
    });

    test('a known GPS fix at start is warmed at once', () {
      var n = 0;
      final w = MapPackWarmup(warm: ({double? lat, double? lon, Iterable<int> cityKeys = const []}) async => n++, keysOf: (_) => const []);
      w.start(userLocation: Rxn<LatLng>(const LatLng(30, 78)), trips: <TripSummaryModel>[].obs);
      expect(n, 1);
      w.dispose();
    });
  });
}
