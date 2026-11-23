import 'dart:typed_data';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/discovery_overlay.dart';
import 'package:bakhli/features/trip/map/trip_discovery_layer.dart';
import 'package:bakhli/features/trip/map/trip_marker_images.dart';
import 'package:bakhli/features/trip/widgets/trip_map_scale_bar.dart';
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

TripDiscoveryLayer _layer(DiscoveryMode mode) => TripDiscoveryLayer(
      mode: mode,
      host: mode == DiscoveryMode.full
          ? DiscoveryHost(anchorLayerId: () => null, plannedDayOf: (_) => null, topInset: () => 100, bottomInset: () => 0)
          : const DiscoveryHost.readOnly(),
      images: TripMarkerImages(fetch: (_) async => null, disk: _Disk(), painter: _Painter()),
    );

Future<void> _pump(WidgetTester t, Widget child) async {
  t.view.physicalSize = const Size(360, 760);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await t.pump();
}

void main() {
  final restore = (size: DS.size, font: DS.font, gap: DS.gapRel, floor: DS.fontFloor);
  tearDown(() {
    DS.debugSet(size: restore.size, font: restore.font, gapRel: restore.gap, fontFloor: restore.floor);
    Get.reset();
  });

  test('nice lengths: largest 1/2/5 x 10^n that fits in 96 dp', () {
    DS.debugReset();
    final a = TripMapScaleBar.pick(0.5)!;
    expect((a.meters, a.width), (20, 40.0));
    final b = TripMapScaleBar.pick(12)!;
    expect((b.meters, b.width), (1000, 1000 / 12));
    expect(TripMapScaleBar.label(b.meters), '1 km');
    expect(TripMapScaleBar.label(500), '500 m');
    expect(TripMapScaleBar.label(2000), '2 km');
    expect(TripMapScaleBar.pick(null), isNull);
    expect(TripMapScaleBar.pick(0), isNull);
    expect(TripMapScaleBar.pick(double.nan), isNull);
    for (final mpd in [0.3, 1.0, 7.0, 33.0, 250.0, 4000.0]) {
      final p = TripMapScaleBar.pick(mpd)!;
      expect(p.width, lessThanOrEqualTo(96));
      expect(p.width, greaterThan(96 / 2.5 - 0.01), reason: 'the next nice value would not fit');
    }
  });

  testWidgets('widget: label and bar width; null shows nothing; approved scale: height 11.2 and width cap 76.8', (t) async {
    DS.debugReset();
    await _pump(t, const Center(child: TripMapScaleBar(metersPerDp: 12)));
    expect(find.text('1 km'), findsOneWidget);
    final bar = find.descendant(of: find.byKey(const ValueKey('disc-scale')), matching: find.byType(Container));
    expect(t.getSize(bar).width, closeTo(1000 / 12, 0.01));
    expect(t.getSize(bar).height, 14);
    await _pump(t, const Center(child: TripMapScaleBar(metersPerDp: null)));
    expect(find.byKey(const ValueKey('disc-scale')), findsNothing);
    DS.applyApproved();
    await _pump(t, const Center(child: TripMapScaleBar(metersPerDp: 12)));
    expect(find.text('500 m'), findsOneWidget);
    expect(t.getSize(bar).height, closeTo(11.2, 0.001));
    expect(t.getSize(bar).width, closeTo(500 / 12, 0.01));
    final style = t.widget<Text>(find.text('500 m')).style!;
    final role = Ink3D.text(10, FontWeight.w500, FitnessAppTheme.darkText);
    expect((style.fontFamily, style.fontSize, style.fontWeight), (role.fontFamily, role.fontSize, role.fontWeight));
  });

  testWidgets('overlay: the bar shows in full mode while attached, bottom right; not in read-only mode, not when detached', (t) async {
    DS.debugReset();
    final mpd = ValueNotifier<double?>(12);
    final full = _layer(DiscoveryMode.full);
    await _pump(t, Stack(fit: StackFit.expand, children: [DiscoveryOverlay(layer: full, mode: DiscoveryMode.full, metersPerDp: mpd)]));
    expect(find.byKey(const ValueKey('disc-scale')), findsNothing, reason: 'not attached');
    await t.runAsync(() => full.attach(_Port()));
    await t.pump();
    expect(find.byKey(const ValueKey('disc-scale')), findsOneWidget);
    final r = t.getRect(find.byKey(const ValueKey('disc-scale')));
    expect(r.right, closeTo(360 - DiscoveryOverlay.scaleRight, 0.5));
    expect(r.bottom, closeTo(760 - DiscoveryOverlay.scaleBottom, 0.5));
    mpd.value = 0.5;
    await t.pump();
    expect(find.text('20 m'), findsOneWidget);
    await t.runAsync(() => full.detach());
    await t.pump();
    expect(find.byKey(const ValueKey('disc-scale')), findsNothing);
    full.dispose();

    final ro = _layer(DiscoveryMode.readOnly);
    await t.runAsync(() => ro.attach(_Port()));
    await _pump(t, Stack(fit: StackFit.expand, children: [DiscoveryOverlay(layer: ro, placement: DiscoveryPlacement.bottom, metersPerDp: mpd)]));
    expect(find.byKey(const ValueKey('disc-scale')), findsNothing);
    ro.dispose();
  });
}
