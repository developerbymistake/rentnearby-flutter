import 'dart:typed_data';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay/guest/stay_map_screen.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/discovery_overlay.dart';
import 'package:bakhli/features/trip/map/trip_discovery_layer.dart';
import 'package:bakhli/features/trip/map/trip_marker_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Port implements DiscoveryMapPort {
  @override
  Future<void> addGeoJsonSource(String sourceId, Map<String, dynamic> data) async {}
  @override
  Future<void> setGeoJson(String sourceId, Map<String, dynamic> data) async {}
  @override
  Future<void> addLayer(DiscLayerSpec spec, DiscTuning tuning, {String? belowLayerId}) async {}
  @override
  Future<void> addImage(String name, Uint8List bytes) async {}
  @override
  Future<void> setFilter(String layerId, List<Object>? filter) async {}
  @override
  Future<void> setVisibility(String layerId, bool visible) async {}
  @override
  Future<List<Object?>> queryRect(double left, double top, double right, double bottom, List<String> layerIds) async => const [];
  @override
  Future<List<({double x, double y})>> toScreen(List<({double lat, double lon})> points) async => [for (final _ in points) (x: 0.0, y: 0.0)];
  @override
  Future<void> animateTo(double lat, double lon, {double? zoom}) async {}
  @override
  Future<void> removeAll() async {}
}

class _Source implements DiscoveryDataSource {
  @override
  final Rx<DiscoveryDataState> state;
  final List<DiscoverySpot> spots;
  _Source(this.spots, [DiscoveryDataState s = DiscoveryDataState.ready]) : state = s.obs;
  @override
  bool get enabled => true;
  @override
  int get version => 1;
  @override
  List<DiscoverySpot> all() => spots;
  @override
  DiscoverySpot? byId(String id) => spots.where((s) => s.id == id).firstOrNull;
  @override
  List<DiscoverySpot> forCities(Iterable<int> cityKeys) => spots;
  @override
  List<DiscoverySpot> near(double lat, double lon, double km) => spots;
  @override
  Future<void> ensureForCities(Iterable<int> cityKeys) async {}
  @override
  Future<void> ensureForPoint(double lat, double lon) async {}
}

class _Painter implements MarkerPainter {
  @override
  Future<Uint8List> badge(String category, DiscTuning t) async => Uint8List.fromList([1]);
  @override
  Future<Uint8List?> photo(Uint8List thumb, DiscTuning t) async => null;
  @override
  Future<bool> valid(Uint8List png) async => true;
}

class _Disk implements MarkerDiskStore {
  @override
  Future<void> clear() async {}
  @override
  Future<int> count() async => 0;
  @override
  Future<Uint8List?> read(String key) async => null;
  @override
  Future<void> write(String key, Uint8List bytes) async {}
  @override
  Future<void> trimTo(int keep) async {}
}

const _centre = (lat: 31.10, lon: 77.17);

DiscoverySpot _spot(String id, {double lat = 31.101, double lon = 77.171}) => DiscoverySpot(
      id: id,
      lat: lat,
      lon: lon,
      category: 'temple',
      rank: 1,
      name: 'Christ Church',
      cityKey: 7,
    );

TripDiscoveryLayer _layer(List<DiscoverySpot> spots, {DiscoveryDataState state = DiscoveryDataState.ready, bool Function()? blocked, void Function(DiscoverySpot)? onDetails}) =>
    TripDiscoveryLayer(
      mode: DiscoveryMode.readOnly,
      host: DiscoveryHost.readOnly(onDetails: onDetails, lineFor: (_) => 'Shimla', bottomInset: () => 120, topInset: () => 180),
      source: _Source(spots, state),
      tuning: DiscTuning.stay,
      images: TripMarkerImages(fetch: (_) async => null, disk: _Disk(), painter: _Painter()),
      tapsBlocked: blocked,
    );

Future<TripDiscoveryLayer> _attached(List<DiscoverySpot> spots, {DiscoveryDataState state = DiscoveryDataState.ready, bool Function()? blocked, void Function(DiscoverySpot)? onDetails}) async {
  final l = _layer(spots, state: state, blocked: blocked, onDetails: onDetails);
  await l.refreshData();
  await l.attach(_Port());
  await l.setPhotoArea(_centre.lat, _centre.lon, 2);
  return l;
}

const _fab = SizedBox(key: ValueKey('old-fab'), width: 46, height: 46);

Future<void> _pump(WidgetTester tester, Widget child, {double width = 360, double textScale = 1.0}) async {
  tester.view.physicalSize = Size(width, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 760), textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

Widget _row(DiscoveryLayerApi? layer) => Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: DS.gv(12), left: DS.s(StayMapTopControls.side), right: DS.s(StayMapTopControls.side)),
        child: StayMapTopControls(layer: layer, fab: _fab, map: () => null, onLocate: () {}),
      ),
    );

void _expectEqualGaps(WidgetTester tester, List<String> keys, double width) {
  final rects = [for (final k in keys) tester.getRect(find.byKey(ValueKey(k)))];
  final pad = DS.s(StayMapTopControls.side);
  final gaps = <double>[rects.first.left - pad];
  for (var i = 1; i < rects.length; i++) {
    gaps.add(rects[i].left - rects[i - 1].right);
  }
  gaps.add(width - pad - rects.last.right);
  for (final g in gaps) {
    expect(g, closeTo(gaps.first, 0.01));
    expect(g, greaterThan(0));
  }
  for (var i = 1; i < rects.length; i++) {
    expect(rects[i].top, closeTo(rects[0].top, 0.01));
  }
}

const _four = ['disc-eye', 'disc-zoom-in', 'disc-zoom-out', 'disc-locate'];
const _three = ['disc-zoom-in', 'disc-zoom-out', 'disc-locate'];

void main() {
  tearDown(Get.reset);

  testWidgets('no layer (flag off or no pack): the old FAB stays at the right edge and nothing new shows', (tester) async {
    await _pump(tester, _row(null));
    expect(find.byKey(const ValueKey('old-fab')), findsOneWidget);
    expect(tester.getRect(find.byKey(const ValueKey('old-fab'))).right, closeTo(360 - DS.s(StayMapTopControls.side), 0.01));
    for (final k in _four) {
      expect(find.byKey(ValueKey(k)), findsNothing);
    }
  });

  testWidgets('layer created but not attached: old FAB, no overlay content', (tester) async {
    final l = _layer([_spot('a')]);
    await _pump(tester, Stack(children: [_row(l), DiscoveryOverlay(layer: l, placement: DiscoveryPlacement.bottom)]));
    expect(find.byKey(const ValueKey('old-fab')), findsOneWidget);
    expect(find.byKey(const ValueKey('disc-eye')), findsNothing);
    expect(find.byKey(const ValueKey('disc-card')), findsNothing);
    expect(find.byKey(const ValueKey('disc-chip')), findsNothing);
    l.dispose();
  });

  for (final width in [360.0, 320.0, 411.0]) {
    testWidgets('spots here: eye, +, -, locate with equal gaps at $width', (tester) async {
      final l = await tester.runAsync(() => _attached([_spot('a')]));
      await _pump(tester, _row(l), width: width);
      expect(find.byKey(const ValueKey('old-fab')), findsNothing);
      final xs = [for (final k in _four) tester.getRect(find.byKey(ValueKey(k))).left];
      expect([...xs]..sort(), xs);
      _expectEqualGaps(tester, _four, width);
      expect(tester.getSize(find.byKey(const ValueKey('disc-locate'))).width, closeTo(DS.s(46), 0.01));
      l!.dispose();
    });

    testWidgets('no spots in this area: 3 buttons, no eye, equal gaps at $width', (tester) async {
      final l = await tester.runAsync(() => _attached([_spot('far', lat: 32.7, lon: 74.8)]));
      expect(l!.hasSpotsHere.value, isFalse);
      await _pump(tester, _row(l), width: width);
      expect(find.byKey(const ValueKey('disc-eye')), findsNothing);
      _expectEqualGaps(tester, _three, width);
      l.dispose();
    });
  }

  testWidgets('text scale 1.3 leaves the row unchanged', (tester) async {
    final l = await tester.runAsync(() => _attached([_spot('a')]));
    await _pump(tester, _row(l), width: 320, textScale: 1.3);
    _expectEqualGaps(tester, _four, 320);
    l!.dispose();
  });

  testWidgets('loading: ring on the eye and the Loading places chip under the row', (tester) async {
    final l = await tester.runAsync(() => _attached(const [], state: DiscoveryDataState.loading));
    await _pump(tester, Stack(fit: StackFit.expand, children: [_row(l), DiscoveryOverlay(layer: l!, placement: DiscoveryPlacement.bottom, palette: ListingPalette.forest, side: StayMapTopControls.side)]));
    expect(find.byKey(const ValueKey('disc-eye')), findsOneWidget);
    expect(find.byKey(const ValueKey('disc-eye-ring')), findsOneWidget);
    expect(find.text('Loading places'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('disc-chip'))).dy, greaterThanOrEqualTo(180));
    l.dispose();
  });

  testWidgets('eye off hides places for the session and strikes the glyph', (tester) async {
    final l = await tester.runAsync(() => _attached([_spot('a')]));
    await _pump(tester, _row(l));
    await tester.tap(find.byKey(const ValueKey('disc-eye')));
    await tester.pump();
    expect(l!.eyeOn.value, isFalse);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    final next = _layer([_spot('a')]);
    expect(next.eyeOn.value, isFalse);
    await tester.tap(find.byKey(const ValueKey('disc-eye')));
    await tester.pump();
    expect(l.eyeOn.value, isTrue);
    l.dispose();
    next.dispose();
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('read-only card at $width: only Details, at the bottom above the pills', (tester) async {
      DiscoverySpot? opened;
      final l = await tester.runAsync(() => _attached([_spot('a')], onDetails: (s) => opened = s));
      await tester.runAsync(() => l!.select('a'));
      await _pump(
        tester,
        Stack(fit: StackFit.expand, children: [DiscoveryOverlay(layer: l!, placement: DiscoveryPlacement.bottom, palette: ListingPalette.forest, side: StayMapTopControls.side)]),
        width: width,
        textScale: 1.3,
      );
      expect(find.byKey(const ValueKey('disc-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('disc-card-details')), findsOneWidget);
      for (final k in ['disc-card-add', 'disc-card-remove', 'disc-card-inday']) {
        expect(find.byKey(ValueKey(k)), findsNothing);
      }
      expect(find.text('Shimla'), findsOneWidget);
      final card = tester.getRect(find.byKey(const ValueKey('disc-card')));
      expect(card.bottom, lessThanOrEqualTo(760 - 120));
      expect(card.left, closeTo(DS.s(StayMapTopControls.side), 0.5));
      expect(card.right, closeTo(width - DS.s(StayMapTopControls.side), 0.5));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('disc-card-details')));
      expect(opened?.id, 'a');
      await tester.tap(find.byKey(const ValueKey('disc-card-close')));
      await tester.pump();
      expect(l.selected.value, isNull);
      l.dispose();
    });
  }

  test('while a stay sheet or the nearest preview is open, spot taps close the card instead of opening one', () async {
    var blocked = false;
    final l = await _attached([_spot('a')], blocked: () => blocked);
    await l.select('a');
    expect(l.selected.value?.id, 'a');
    blocked = true;
    expect(await l.onFeatureTap('disc-badge', 'a'), isTrue);
    expect(l.selected.value, isNull);
    await l.onMapTap(10, 10);
    expect(l.selected.value, isNull);
    blocked = false;
    expect(await l.onFeatureTap('disc-badge', 'a'), isTrue);
    expect(l.selected.value?.id, 'a');
    l.dispose();
  });
}
