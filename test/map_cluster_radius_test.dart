import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/utils/map_clustering.dart';

const _lat0 = 30.0, _lon0 = 78.0;

List<(double, double)> _ring(double km, int n) {
  final out = <(double, double)>[];
  for (var i = 0; i < n; i++) {
    final a = 2 * pi * i / n;
    out.add((_lat0 + km * cos(a) / 111.0, _lon0 + km * sin(a) / (111.0 * cos(_lat0 * pi / 180))));
  }
  return out;
}

List<MapCluster<(double, double)>> _run(List<(double, double)> pts, double zoom) =>
    MapClustering.cluster<(double, double)>(pts, lat: (p) => p.$1, lon: (p) => p.$2, zoom: zoom);

void main() {
  final pts = [
    for (final km in [1.0, 6.0, 12.0, 20.0]) ..._ring(km, 30),
    ..._ring(0.05, 5),
  ];

  test('close pins merge at zoom 9, none dropped, within 50 clusters', () {
    final r = _run(pts, 9);
    expect(r.length, lessThanOrEqualTo(50));
    expect(r.fold<int>(0, (s, c) => s + c.count), pts.length);
    expect(r.any((c) => c.count > 1), isTrue);
  });

  test('the 20 km pins are kept at every zoom', () {
    for (final z in [8.0, 9.0, 11.0, 14.0, 17.0]) {
      final r = _run(pts, z);
      expect(r.fold<int>(0, (s, c) => s + c.count), pts.length);
      expect(r.length, lessThanOrEqualTo(50));
    }
  });

  test('pins split at a high zoom', () {
    final close = _ring(0.05, 5);
    expect(_run(close, 9).length, 1);
    expect(_run(close, 18).length, 5);
  });

  test('rebuild rule uses a 0.4 zoom gap from the last build', () {
    expect(MapClustering.needsRebuild(lastBuildZoom: 12.0, idleZoom: 12.39), isFalse);
    expect(MapClustering.needsRebuild(lastBuildZoom: 12.0, idleZoom: 12.4), isTrue);
    expect(MapClustering.needsRebuild(lastBuildZoom: 12.0, idleZoom: 11.5), isTrue);
    expect(MapClustering.needsRebuild(lastBuildZoom: 0, idleZoom: 13.0), isTrue);
  });
}
