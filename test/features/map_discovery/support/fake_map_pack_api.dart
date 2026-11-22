import 'dart:async';
import 'dart:io';

import 'package:bakhli/features/map_discovery/data/map_pack_api.dart';
import 'package:bakhli/features/map_discovery/data/map_pack_store.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_constants.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_models.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_synthetic.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

typedef FakeAnswer = FutureOr<MapPackFetchResult> Function(MapPackRef ref, String? etag);

class FakeMapPackApi extends MapPackApi {
  final List<({String stateId, String? etag, String path})> calls = [];
  final Map<String, List<FakeAnswer>> _script = {};
  FakeAnswer? fallback;

  FakeMapPackApi({this.fallback});

  int get count => calls.length;

  int countFor(String stateId) => calls.where((c) => c.stateId == stateId).length;

  void enqueue(String stateId, FakeAnswer answer) => (_script[stateId] ??= []).add(answer);

  void body(String stateId, String raw) => enqueue(stateId, (_, _) => (notModified: false, body: raw));

  void notModified(String stateId) => enqueue(stateId, (_, _) => (notModified: true, body: null));

  void fail(String stateId, [Object error = const SocketException('offline')]) => enqueue(stateId, (_, _) => throw error);

  @override
  Future<MapPackFetchResult> fetch(MapPackRef ref, {String? etag}) async {
    calls.add((stateId: ref.stateId, etag: etag, path: ref.path));
    if (MapPackApi.requestPath(ref.path, 'https://api.example.test/api/v1') == null) return MapPackApi.failed;
    final queue = _script[ref.stateId];
    final answer = (queue != null && queue.isNotEmpty) ? queue.removeAt(0) : fallback;
    if (answer == null) throw const SocketException('no scripted answer');
    return answer(ref, etag);
  }
}

class FakeClock {
  DateTime value = DateTime(2026, 11, 22, 10);
  DateTime call() => value;
  void advance(Duration d) => value = value.add(d);
}

class FakeVersion {
  int calls = 0;
  final List<Object> _script = [];
  Object? last;

  void answer(TripCityVersion v) => _script.add(v);

  void throwNext([Object error = const SocketException('offline')]) => _script.add(error);

  Future<TripCityVersion> call() async {
    calls++;
    final next = _script.isNotEmpty ? _script.removeAt(0) : last;
    if (next == null) throw const SocketException('no version scripted');
    last = next;
    if (next is TripCityVersion) return next;
    throw next;
  }
}

MapPackRef ref(String stateId, {String version = 'v1', String? name, List<double>? bbox, String? path}) => MapPackRef(
      stateId: stateId,
      version: version,
      path: path ?? '/trips/map-packs/$stateId/$version',
      stateName: name,
      bbox: bbox,
    );

TripCityVersion ver({bool flag = true, List<MapPackRef> packs = const []}) =>
    TripCityVersion(version: 'c1', count: 1, stale: false, mapDiscovery: flag, packs: packs);

String packBody({String state = 's1', String version = 'v1', int rows = 20, int seed = 1, double lat = 30, double lon = 78}) =>
    MapPackSynthetic.body(rows: rows, seed: seed, withThumb: rows ~/ 2, state: state, version: version, centerLat: lat, centerLon: lon, spreadDeg: 0.2);

TripCityModel city(int key, {String state = 'State One', double lat = 30, double lon = 78}) => TripCityModel(
      cityKey: key,
      name: 'City $key',
      districtName: 'D',
      stateName: state,
      latitude: lat,
      longitude: lon,
      status: TripCityStatus.ready,
      spotCount: 1,
      isPopularDestination: false,
    );

late GetStorage mapPackTestBox;

Future<void> initMapPackTestStorage(String name) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => Directory.systemTemp.createTempSync(name).path,
  );
  await GetStorage.init();
  await GetStorage.init('${MapPackConstants.box}_test');
  mapPackTestBox = GetStorage('${MapPackConstants.box}_test');
}

Future<void> resetMapPackStore() async {
  await mapPackTestBox.erase();
  MapPackStore.debugUseBox(mapPackTestBox);
}
