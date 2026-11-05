import 'dart:math';

import 'package:bakhli/utils/map_clustering.dart';
import 'package:flutter_test/flutter_test.dart';

typedef P = ({int id, double lat, double lon});

List<MapCluster<P>> run(List<P> pts, {double zoom = 13, int max = 50}) => MapClustering.cluster<P>(
      pts,
      lat: (p) => p.lat,
      lon: (p) => p.lon,
      zoom: zoom,
      radiusPx: 48,
      maxClusters: max,
    );

List<P> spread(int n, int seed) {
  final r = Random(seed);
  return [
    for (var i = 0; i < n; i++)
      (id: i, lat: 29.22 + (r.nextDouble() - 0.5) * 0.2, lon: 79.51 + (r.nextDouble() - 0.5) * 0.2),
  ];
}

void main() {
  test('120 rooms in 12 km: every room is counted, markers stay in budget', () {
    final pts = spread(120, 7);
    for (final zoom in [10.0, 12.0, 13.0, 15.0]) {
      final c = run(pts, zoom: zoom);
      expect(c.fold<int>(0, (s, x) => s + x.count), 120);
      expect(c.length, lessThanOrEqualTo(50));
      expect({for (final x in c) ...x.items.map((p) => p.id)}.length, 120);
    }
  });

  test('a far paid listing first in server order keeps its own pin', () {
    final pts = [(id: 0, lat: 29.30, lon: 79.60), ...spread(80, 3).map((p) => (id: p.id + 1, lat: p.lat, lon: p.lon))];
    final c = run(pts, zoom: 14);
    expect(c.first.first.id, 0);
    expect(c.fold<int>(0, (s, x) => s + x.count), 81);
  });

  test('a cluster lists its items in input order', () {
    final c = run(spread(60, 11), zoom: 9);
    for (final x in c) {
      final ids = x.items.map((p) => p.id).toList();
      expect(ids.first, ids.reduce(min));
    }
  });

  test('empty, single, duplicates, invalid coordinates', () {
    expect(run(const []), isEmpty);
    final one = run([(id: 1, lat: 29.0, lon: 79.0)]);
    expect(one.single.count, 1);
    expect(one.single.latitude, closeTo(29.0, 1e-9));
    final dup = run([for (var i = 0; i < 5; i++) (id: i, lat: 29.0, lon: 79.0)]);
    expect(dup.single.count, 5);
    final bad = run([(id: 1, lat: double.nan, lon: 79.0), (id: 2, lat: 29.0, lon: 79.0)]);
    expect(bad.single.items.single.id, 2);
  });

  test('budget of one merges everything, never drops', () {
    final c = run(spread(40, 5), zoom: 16, max: 1);
    expect(c.single.count, 40);
  });
}
