import 'dart:io';
import 'dart:typed_data';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/discovery_geojson.dart';
import 'package:bakhli/features/trip/map/trip_discovery_layer.dart';
import 'package:bakhli/features/trip/map/trip_marker_images.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class FakePort implements DiscoveryMapPort {
  final calls = <String>[];
  final geo = <String, Map<String, dynamic>>{};
  final filters = <String, List<Object>?>{};
  List<Object?> rectResult = const [];
  List<({double x, double y})> Function(List<({double lat, double lon})>)? screen;
  bool failOnLayer = false;
  ({double lat, double lon})? animated;

  int count(String prefix) => calls.where((c) => c.startsWith(prefix)).length;

  @override
  Future<void> addGeoJsonSource(String sourceId, Map<String, dynamic> data) async {
    calls.add('source:$sourceId');
    geo[sourceId] = data;
  }

  @override
  Future<void> setGeoJson(String sourceId, Map<String, dynamic> data) async {
    calls.add('set:$sourceId');
    geo[sourceId] = data;
  }

  @override
  Future<void> addLayer(DiscLayerSpec spec, DiscTuning tuning, {String? belowLayerId}) async {
    if (failOnLayer) throw StateError('native');
    calls.add('layer:${spec.id}:$belowLayerId');
  }

  @override
  Future<void> addImage(String name, Uint8List bytes) async => calls.add('image:$name');

  @override
  Future<void> setFilter(String layerId, List<Object>? filter) async {
    calls.add('filter:$layerId');
    filters[layerId] = filter;
  }

  @override
  Future<void> setVisibility(String layerId, bool visible) async => calls.add('vis:$layerId:$visible');

  @override
  Future<List<Object?>> queryRect(double left, double top, double right, double bottom, List<String> layerIds) async {
    calls.add('query:${layerIds.join(',')}:${(right - left).toStringAsFixed(1)}');
    return rectResult;
  }

  @override
  Future<List<({double x, double y})>> toScreen(List<({double lat, double lon})> points) async {
    calls.add('screen:${points.length}');
    return screen?.call(points) ?? [for (final _ in points) (x: 0.0, y: 0.0)];
  }

  @override
  Future<void> animateTo(double lat, double lon, {double? zoom}) async {
    calls.add('animate');
    animated = (lat: lat, lon: lon);
  }

  @override
  Future<void> removeAll() async => calls.add('removeAll');
}

class FakeSource implements DiscoveryDataSource {
  @override
  final Rx<DiscoveryDataState> state = DiscoveryDataState.ready.obs;
  @override
  bool enabled = true;
  @override
  int version = 1;
  List<DiscoverySpot> spots;

  FakeSource(this.spots);

  @override
  List<DiscoverySpot> all() => spots;
  @override
  DiscoverySpot? byId(String id) => spots.where((s) => s.id == id).firstOrNull;
  @override
  List<DiscoverySpot> forCities(Iterable<int> cityKeys) =>
      spots.where((s) => cityKeys.contains(s.cityKey)).toList();
  @override
  List<DiscoverySpot> near(double lat, double lon, double km) => spots;
  @override
  Future<void> ensureForCities(Iterable<int> cityKeys) async {}
  @override
  Future<void> ensureForPoint(double lat, double lon) async {}
}

class FakePainter implements MarkerPainter {
  @override
  Future<Uint8List> badge(String category, DiscTuning t) async => Uint8List.fromList([1]);
  @override
  Future<Uint8List?> photo(Uint8List thumb, DiscTuning t) async => Uint8List.fromList([2]);
  @override
  Future<bool> valid(Uint8List png) async => true;
}

class MemDisk implements MarkerDiskStore {
  final files = <String, Uint8List>{};
  @override
  Future<void> clear() async => files.clear();
  @override
  Future<int> count() async => files.length;
  @override
  Future<Uint8List?> read(String key) async => files[key];
  @override
  Future<void> write(String key, Uint8List bytes) async => files[key] = bytes;
  @override
  Future<void> trimTo(int keep) async {}
}

DiscoverySpot spot(String id, {int rank = 1, bool thumb = false, int city = 7, double lat = 30.5, double lon = 78.2}) =>
    DiscoverySpot(
      id: id,
      lat: lat,
      lon: lon,
      category: 'lake',
      rank: rank,
      name: id,
      cityKey: city,
      thumbUrl: thumb ? 'https://res.cloudinary.com/x/image/upload/$id.jpg' : null,
    );

TripMarkerImages images({Set<String> fail = const {}}) => TripMarkerImages(
      fetch: (url) async => fail.any(url.contains) ? null : Uint8List.fromList([9]),
      disk: MemDisk(),
      painter: FakePainter(),
    );

TripDiscoveryLayer layer({
  DiscoveryMode mode = DiscoveryMode.full,
  FakeSource? source,
  Set<String> fail = const {},
  int? Function(String)? plannedDayOf,
  Size Function()? viewSize,
  bool Function()? blocked,
}) =>
    TripDiscoveryLayer(
      mode: mode,
      host: DiscoveryHost(
        anchorLayerId: () => 'anchor',
        plannedDayOf: plannedDayOf ?? (_) => null,
        topInset: () => 100,
        bottomInset: () => 0,
      ),
      source: source,
      dataOf: (s) => s.all(),
      images: images(fail: fail),
      viewSize: viewSize,
      cardHeight: () => 150,
      tapsBlocked: blocked,
    );

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

List<Map<String, dynamic>> features(Map<String, dynamic>? fc) => ((fc?['features'] as List?) ?? const []).cast();

void main() {
  tearDown(Get.reset);

  test('attach: 3 sources, badge images, 6 layers below the anchor, in that order', () async {
    final l = layer(source: FakeSource([spot('a'), spot('b')]));
    await l.refreshData();
    final port = FakePort();
    expect(await l.attach(port), isTrue);
    final c = port.calls;
    expect(c.take(3), ['source:disc-all', 'source:disc-photo', 'source:disc-sel']);
    final images = c.where((x) => x.startsWith('image:disc-b-')).length;
    expect(images, DiscIds.badgeCategories.length);
    final layers = [for (final x in c) if (x.startsWith('layer:')) x];
    expect(layers, [for (final id in DiscIds.layers) 'layer:$id:anchor']);
    expect(c.indexOf('layer:disc-dots:anchor'), greaterThan(c.lastIndexOf('image:disc-b-place')));
    expect(features(port.geo['disc-all']).length, 2);
    expect(l.attached.value, isTrue);
    expect(l.hasSpotsHere.value, isTrue);
  });

  test('read-only mode has no anchor: layers are added on top', () async {
    final l = TripDiscoveryLayer(
      mode: DiscoveryMode.readOnly,
      host: const DiscoveryHost.readOnly(),
      images: images(),
    );
    final port = FakePort();
    await l.attach(port);
    expect(port.calls.where((x) => x.startsWith('layer:')).every((x) => x.endsWith(':null')), isTrue);
    expect(l.tuning.photoDp, DS.s(44));
  });

  test('photos: tier-1 spots with a thumb registered in batches of 8, one disc-photo set per batch', () async {
    final spots = [for (var i = 0; i < 20; i++) spot('s$i', rank: i + 1, thumb: true)];
    final l = layer(source: FakeSource(spots));
    await l.refreshData();
    final port = FakePort();
    await l.attach(port);
    await settle();
    expect(port.count('image:disc-p-'), 20);
    expect(port.count('set:disc-photo'), 3);
    expect(features(port.geo['disc-photo']).length, 20);
  });

  test('failed photo is skipped, its badge stays', () async {
    final l = layer(source: FakeSource([spot('a', thumb: true), spot('b', rank: 2, thumb: true)]), fail: {'/a.jpg'});
    await l.refreshData();
    final port = FakePort();
    await l.attach(port);
    await settle();
    expect(port.count('image:disc-p-'), 1);
    expect(features(port.geo['disc-photo']).map((f) => f['id']), ['b']);
    expect(features(port.geo['disc-all']).firstWhere((f) => f['id'] == 'a')['properties']['tier'], 1);
  });

  test('zero port calls on a simulated pan; the layer registers no camera listener', () async {
    final l = layer(source: FakeSource([spot('a', thumb: true)]));
    await l.refreshData();
    final port = FakePort();
    await l.attach(port);
    await settle();
    final before = port.calls.length;
    for (var i = 0; i < 50; i++) {
      await settle();
    }
    expect(port.calls.length, before);
    final src = File('lib/features/trip/map/trip_discovery_layer.dart').readAsStringSync();
    expect(RegExp(r'onCameraMove|onCameraIdle|addListener\(').hasMatch(src), isFalse);
  });

  test('planned ids: one setFilter per discovery layer per change, none when unchanged', () async {
    final l = layer(source: FakeSource([spot('a'), spot('b')]));
    await l.refreshData();
    final port = FakePort();
    await l.attach(port);
    port.calls.clear();
    await l.setPlannedIds({'a'});
    expect(port.calls, ['filter:disc-dots', 'filter:disc-badge', 'filter:disc-photo']);
    expect(port.filters['disc-dots'], DiscGeoJson.plannedFilter({'a'}));
    port.calls.clear();
    await l.setPlannedIds({'a'});
    expect(port.calls, isEmpty);
    await l.setPlannedIds({});
    expect(port.count('filter:'), 3);
    expect(port.filters['disc-badge'], isNotNull);
  });

  test('planned ids set before attach are applied at attach', () async {
    final l = layer(source: FakeSource([spot('a')]));
    await l.setPlannedIds({'a'});
    final port = FakePort();
    await l.attach(port);
    expect(port.count('filter:'), 3);
  });

  test('selection = one disc-sel call; close clears it with one call', () async {
    final l = layer(source: FakeSource([spot('a'), spot('b', rank: 300)]));
    await l.refreshData();
    final port = FakePort();
    await l.attach(port);
    port.calls.clear();
    expect(await l.onFeatureTap(DiscIds.layerBadge, 'a'), isTrue);
    expect(port.calls, ['set:disc-sel']);
    expect(l.selected.value?.id, 'a');
    expect(features(port.geo['disc-sel']).single['properties']['kind'], 'badge');
    port.calls.clear();
    await l.clearSelection();
    expect(port.calls, ['set:disc-sel']);
    expect(l.selected.value, isNull);
    port.calls.clear();
    await l.clearSelection();
    expect(port.calls, isEmpty);
  });

  test('taps on other layers or unknown ids are ignored', () async {
    final l = layer(source: FakeSource([spot('a')]));
    await l.refreshData();
    final port = FakePort();
    await l.attach(port);
    expect(await l.onFeatureTap('trip-route-1-line', 'a'), isFalse);
    expect(await l.onFeatureTap(DiscIds.layerPhoto, 'zz'), isFalse);
    expect(l.selected.value, isNull);
  });

  test('dot tap: 44 dp rect query on disc-dots, nearest by screen distance; empty closes', () async {
    final l = TripDiscoveryLayer(
      mode: DiscoveryMode.full,
      host: DiscoveryHost(anchorLayerId: () => null, plannedDayOf: (_) => null, topInset: () => 0, bottomInset: () => 0),
      source: FakeSource([spot('a', rank: 500), spot('b', rank: 501)]),
      dataOf: (s) => s.all(),
      images: images(),
      unitsPerDp: () => 2,
    );
    await l.refreshData();
    final port = FakePort()
      ..rectResult = [
        {'type': 'Feature', 'id': 'a', 'geometry': {'type': 'Point', 'coordinates': [78.2, 30.5]}},
        '{"type":"Feature","id":"b","geometry":{"type":"Point","coordinates":[78.3,30.6]}}',
      ]
      ..screen = (pts) => [(x: 10.0, y: 10.0), (x: 101.0, y: 99.0)];
    await l.attach(port);
    port.calls.clear();
    expect(await l.onMapTap(100, 100), isTrue);
    expect(port.calls.first, 'query:disc-dots:88.0');
    expect(l.selected.value?.id, 'b');
    expect(features(port.geo['disc-sel']).single['properties']['kind'], 'dot');
    port.rectResult = const [];
    expect(await l.onMapTap(5, 5), isFalse);
    expect(l.selected.value, isNull);
  });

  test('eye off = 3 visibility calls + selection cleared; eye on = 3 calls', () async {
    final l = layer(source: FakeSource([spot('a')]));
    await l.refreshData();
    final port = FakePort();
    await l.attach(port);
    port.calls.clear();
    await l.setEye(false);
    expect(port.calls, ['vis:disc-dots:false', 'vis:disc-badge:false', 'vis:disc-photo:false']);
    await l.setEye(true);
    await l.onFeatureTap(DiscIds.layerBadge, 'a');
    port.calls.clear();
    await l.setEye(false);
    expect(port.count('vis:'), 3);
    expect(port.calls.last, 'set:disc-sel');
    expect(l.selected.value, isNull);
    expect(await l.onFeatureTap(DiscIds.layerBadge, 'a'), isFalse);
  });

  test('read-only eye state lasts for the app session', () async {
    final a = TripDiscoveryLayer(mode: DiscoveryMode.readOnly, host: const DiscoveryHost.readOnly(), images: images());
    await a.setEye(false);
    final b = TripDiscoveryLayer(mode: DiscoveryMode.readOnly, host: const DiscoveryHost.readOnly(), images: images());
    expect(b.eyeOn.value, isFalse);
    await b.setEye(true);
    final trip = layer();
    expect(trip.eyeOn.value, isTrue);
  });

  test('detach removes everything and stops photo batches; no call after dispose', () async {
    final spots = [for (var i = 0; i < 30; i++) spot('s$i', rank: i + 1, thumb: true)];
    final l = layer(source: FakeSource(spots));
    await l.refreshData();
    final port = FakePort();
    await l.attach(port);
    await l.detach();
    final n = port.count('image:disc-p-');
    await settle();
    expect(port.count('image:disc-p-'), n);
    expect(port.calls.contains('removeAll'), isTrue);
    expect(l.attached.value, isFalse);

    final port2 = FakePort();
    final l2 = layer(source: FakeSource(spots));
    await l2.refreshData();
    await l2.attach(port2);
    l2.dispose();
    final m = port2.calls.length;
    await settle();
    await l2.onFeatureTap(DiscIds.layerBadge, 's1');
    await l2.setPlannedIds({'s1'});
    expect(port2.calls.length, m);
  });

  test('attach failure: removeAll, not attached, attach helper returns null (old map)', () async {
    final l = layer(source: FakeSource([spot('a')]));
    final port = FakePort()..failOnLayer = true;
    expect(await l.attach(port), isFalse);
    expect(port.calls.last, 'removeAll');
    expect(l.attached.value, isFalse);
    final l2 = layer(source: FakeSource([spot('a')]));
    expect(await DiscoveryAttach.attachLayer(l2, FakePort()..failOnLayer = true), isNull);
  });

  test('flag off or no data: attach helper declines without touching the map', () async {
    final off = FakeSource([spot('a')])..enabled = false;
    expect(DiscoveryAttach.wanted(off), isFalse);
    final none = FakeSource([spot('a')])..state.value = DiscoveryDataState.none;
    expect(DiscoveryAttach.wanted(none), isFalse);
    final loading = FakeSource([])..state.value = DiscoveryDataState.loading;
    expect(DiscoveryAttach.wanted(loading), isTrue);
    expect(await DiscoveryAttach.maybe(null, mode: DiscoveryMode.full, host: const DiscoveryHost.readOnly(), source: off), isNull);
  });

  test('late data: source turns ready, layer sets disc-all once with the new set', () async {
    final src = FakeSource([])..state.value = DiscoveryDataState.loading;
    final l = layer(source: src);
    final port = FakePort();
    await l.attach(port);
    expect(l.dataState.value, DiscoveryDataState.loading);
    expect(l.hasSpotsHere.value, isFalse);
    src.spots = [spot('a'), spot('b')];
    port.calls.clear();
    src.state.value = DiscoveryDataState.ready;
    await settle();
    expect(port.count('set:disc-all'), 1);
    expect(l.hasSpotsHere.value, isTrue);
    await l.refreshData();
    expect(port.count('set:disc-all'), 1);
  });

  test('plan edit while the card is open: added spot turns planned, removed spot returns, vanished spot closes', () async {
    final planned = <String, int>{};
    final src = FakeSource([spot('a'), spot('b')]);
    final l = layer(source: src, plannedDayOf: (id) => planned[id]);
    await l.refreshData();
    final port = FakePort();
    await l.attach(port);
    await l.onFeatureTap(DiscIds.layerBadge, 'a');
    planned['a'] = 2;
    await l.setPlannedIds({'a'});
    expect(l.selectedKind.value, DiscSelKind.planned);
    expect(l.selectedPlannedDay.value, 2);
    planned.remove('a');
    await l.setPlannedIds({});
    expect(l.selectedKind.value, DiscSelKind.badge);
    expect(l.selectedPlannedDay.value, isNull);
    src.spots = [spot('b')];
    await l.refreshData();
    expect(l.selected.value, isNull);
  });

  test('planned spot not in the pack opens from the host model', () async {
    final l = layer(source: FakeSource([]), plannedDayOf: (_) => 1);
    final port = FakePort();
    await l.attach(port);
    await l.select('x', planned: true, spot: spot('x'));
    expect(l.selected.value?.id, 'x');
    expect(l.selectedPlannedDay.value, 1);
    expect(features(port.geo['disc-sel']).single['properties']['kind'], 'planned');
  });

  test('lift: a marker under the card band moves the camera once, a clear marker does not', () async {
    final l = layer(source: FakeSource([spot('a')]), viewSize: () => const Size(360, 760));
    await l.refreshData();
    final port = FakePort()..screen = (pts) => [(x: 180.0, y: 120.0), (x: 180.0, y: 20.0), (x: 280.0, y: 120.0)];
    await l.attach(port);
    port.calls.clear();
    await l.onFeatureTap(DiscIds.layerBadge, 'a');
    expect(port.calls, ['set:disc-sel', 'screen:3', 'animate']);
    // centre was 30.474 (marker 260 px above it); marker must land at top 100 + card 150 + photo halo (72 x DS)
    final target = 100 + 150 + DiscTuning.trip.haloPhotoDp;
    expect(port.animated!.lat, closeTo(30.5 - (380 - target) / 10000, 1e-9));
    expect(port.animated!.lon, closeTo(78.2, 1e-9));
    port
      ..calls.clear()
      ..screen = (pts) => [(x: 180.0, y: 500.0), (x: 180.0, y: 400.0), (x: 280.0, y: 500.0)];
    await l.onFeatureTap(DiscIds.layerBadge, 'a');
    expect(port.calls, ['set:disc-sel', 'screen:3']);
  });

  test('stay area: photos only within the area, eye hint false when no spot is in the area', () async {
    final far = spot('far', thumb: true, lat: 32.0, lon: 77.0);
    final near = spot('near', rank: 2, thumb: true);
    final l = TripDiscoveryLayer(
      mode: DiscoveryMode.readOnly,
      host: const DiscoveryHost.readOnly(),
      source: FakeSource([far, near]),
      images: images(),
    );
    await l.refreshData();
    final port = FakePort();
    await l.attach(port);
    await settle();
    expect(port.count('image:disc-p-'), 0);
    await l.setPhotoArea(30.5, 78.2, 10);
    await settle();
    expect(port.count('image:disc-p-'), 1);
    expect(features(port.geo['disc-photo']).map((f) => f['id']), ['near']);
    expect(l.hasSpotsHere.value, isTrue);
    await l.setPhotoArea(10, 10, 5);
    expect(l.hasSpotsHere.value, isFalse);
  });

  test('blocked taps (stay sheet open) close the card and select nothing', () async {
    var blocked = false;
    final l = layer(source: FakeSource([spot('a')]), blocked: () => blocked);
    await l.refreshData();
    final port = FakePort();
    await l.attach(port);
    await l.onFeatureTap(DiscIds.layerBadge, 'a');
    blocked = true;
    expect(await l.onFeatureTap(DiscIds.layerBadge, 'a'), isTrue);
    expect(l.selected.value, isNull);
  });

  test('re-attach after a style reload re-adds everything from memory', () async {
    final l = layer(source: FakeSource([spot('a', thumb: true)]));
    await l.refreshData();
    await l.attach(FakePort());
    await settle();
    await l.detach();
    final port = FakePort();
    expect(await l.attach(port), isTrue);
    await settle();
    expect(port.count('source:'), 3);
    expect(port.calls.contains('image:${DiscIds.photoSlot(0)}'), isTrue);
    expect(features(port.geo['disc-photo']).single['properties']['img'], DiscIds.photoSlot(0));
  });

  test('L-08: photo area moves 40 times: distinct image names stay at or below photoMax', () async {
    final spots = [
      for (var i = 0; i < 60; i++) spot('s$i', rank: i + 1, thumb: true, lat: 30 + i * 0.05, lon: 78),
    ];
    final l = TripDiscoveryLayer(
      mode: DiscoveryMode.readOnly,
      host: const DiscoveryHost.readOnly(),
      source: FakeSource(spots),
      images: images(),
    );
    await l.refreshData();
    final port = FakePort();
    await l.attach(port);
    for (var k = 0; k < 40; k++) {
      await l.setPhotoArea(30 + k * 0.075, 78, 3);
      await settle();
    }
    final names = {for (final c in port.calls) if (c.startsWith('image:disc-p-')) c};
    expect(names.length, lessThanOrEqualTo(l.tuning.photoMax));
    expect(port.count('image:disc-p-'), greaterThan(l.tuning.photoMax));
    final shown = features(port.geo['disc-photo']);
    expect({for (final f in shown) f['properties']['img']}.length, shown.length, reason: 'no two shown spots share a slot');
  });

  test('L-14: disk trim keeps the newest files instead of wiping the folder', () async {
    final dir = Directory.systemTemp.createTempSync('disc_trim');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = DiscMarkerFolderStore(root: () => dir);
    final base = DateTime(2026, 1, 1);
    for (var i = 0; i < 301; i++) {
      await store.write('k$i', Uint8List.fromList([1]));
      File('${dir.path}${Platform.pathSeparator}${DiscMarkerFolderStore.folder}${Platform.pathSeparator}k$i.png').setLastModifiedSync(base.add(Duration(minutes: i)));
    }
    await TripMarkerImages(disk: store).trimDisk(DiscTuning.trip);
    expect(await store.count(), 200);
    expect(await store.read('k300'), isNotNull);
    expect(await store.read('k0'), isNull);
  });

  group('APP-8 retryPhotos', () {
    test('fetch fails for 3 spots: retryPhotos registers them; a second call makes zero fetches', () async {
      final fail = {'/p1.jpg', '/p2.jpg', '/p3.jpg'};
      final spots = [for (var i = 1; i <= 5; i++) spot('p$i', rank: i, thumb: true)];
      final l = layer(source: FakeSource(spots), fail: fail);
      await l.refreshData();
      final port = FakePort();
      await l.attach(port);
      await l.setPhotoArea(30.5, 78.2, 5);
      await settle();
      expect(port.count('image:disc-p-'), 2);
      fail.clear();
      l.retryPhotos();
      await settle();
      expect(port.count('image:disc-p-'), 5);
      final before = port.calls.length;
      l.retryPhotos();
      await settle();
      expect(port.calls.length, before, reason: 'every top photo is registered: no work');
      l.dispose();
    });

    test('detached: retryPhotos does nothing', () async {
      final l = layer(source: FakeSource([spot('p1', thumb: true)]), fail: {'/p1.jpg'});
      await l.refreshData();
      l.retryPhotos();
      await settle();
      l.dispose();
    });
  });

  group('APP-9 the open card follows its row when the top list changes', () {
    test('a selected photo spot dropped from the top falls back to a badge or dot, never a slot image', () async {
      final spots = [for (var i = 1; i <= 3; i++) spot('p$i', rank: i, thumb: true)];
      final l = layer(source: FakeSource(spots));
      await l.refreshData();
      final port = FakePort();
      await l.attach(port);
      await l.setPhotoArea(30.5, 78.2, 5);
      await settle();
      await l.select('p1');
      final first = features(port.geo['disc-sel']).single['properties'] as Map;
      expect(first['kind'], 'photo');
      expect('${first['img']}', startsWith('disc-p-'));
      await l.setPhotoArea(10.0, 10.0, 1);
      await settle();
      final after = features(port.geo['disc-sel']).single['properties'] as Map;
      expect(after['kind'], isNot('photo'));
      expect('${after['img']}', isNot(startsWith('disc-p-')));
      expect(l.selected.value?.id, 'p1');
      l.dispose();
    });

    test('a selected spot that keeps its slot causes no extra setGeoJson of the selection', () async {
      final spots = [for (var i = 1; i <= 3; i++) spot('p$i', rank: i, thumb: true)];
      final l = layer(source: FakeSource(spots));
      await l.refreshData();
      final port = FakePort();
      await l.attach(port);
      await l.setPhotoArea(30.5, 78.2, 5);
      await settle();
      await l.select('p1');
      final sels = port.count('set:disc-sel');
      await l.setPhotoArea(30.5, 78.2, 6);
      await settle();
      expect(port.count('set:disc-sel'), sels);
      l.dispose();
    });

    test('a selected spot that leaves the data closes the card', () async {
      final source = FakeSource([spot('p1', thumb: true), spot('p2', rank: 2)]);
      final l = layer(source: source);
      await l.refreshData();
      final port = FakePort();
      await l.attach(port);
      await l.select('p2');
      await l.setData([spot('p1', thumb: true)]);
      await settle();
      expect(l.selected.value, isNull);
      l.dispose();
    });
  });

  test('APP-16: the trip map refreshes the layer data when the pack changes while it is attached', () {
    final src = File('lib/features/trip/screens/trip_map_screen.dart').readAsStringSync().replaceAll('\r\n', '\n');
    expect(src.contains('    if (DiscoveryAttach.wanted(_discSource)) {\n      d.refreshData().ignore();\n      return;\n    }'), isTrue);
  });

  test('APP-16: new rows after a revision are set once; unchanged rows cause no setGeoJson', () async {
    final source = FakeSource([spot('a'), spot('b')]);
    final l = layer(source: source);
    await l.refreshData();
    final port = FakePort();
    await l.attach(port);
    final sets = port.count('set:disc-all');
    await l.refreshData();
    expect(port.count('set:disc-all'), sets);
    source.spots = [spot('a'), spot('b'), spot('c')];
    source.version++;
    await l.refreshData();
    expect(port.count('set:disc-all'), sets + 1);
    expect(features(port.geo['disc-all']).length, 3);
    l.dispose();
  });

  test('APP-8 guard: no ensure call inside a camera callback of either screen', () {
    for (final f in ['lib/features/trip/screens/trip_map_screen.dart', 'lib/features/stay/guest/stay_map_screen.dart']) {
      final src = File(f).readAsStringSync().replaceAll('\r\n', '\n');
      final idle = RegExp(r'void _onCameraIdle\(\)[\s\S]*?\n  \}|Future<void> _onCameraIdle\(\) async \{[\s\S]*?\n  \}').firstMatch(src)?.group(0) ?? '';
      expect(idle.contains('ensure'), isFalse, reason: f);
      final move = RegExp(r'onCameraMove: \(CameraPosition pos\) \{[\s\S]*?\n\s*\},').firstMatch(src)?.group(0) ?? '';
      expect(move.contains('ensure'), isFalse, reason: f);
    }
  });
}
