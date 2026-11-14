import 'dart:math';

class MapCluster<T> {
  final List<T> items;
  double _x, _y;
  double _sumLat, _sumLon;

  MapCluster._(T item, double lat, double lon, this._x, this._y)
      : items = [item],
        _sumLat = lat,
        _sumLon = lon;

  int get count => items.length;
  double get latitude => _sumLat / items.length;
  double get longitude => _sumLon / items.length;
  T get first => items.first;

  void _absorb(MapCluster<T> other) {
    items.addAll(other.items);
    _sumLat += other._sumLat;
    _sumLon += other._sumLon;
  }
}

// Never drops a point: over budget, the clusters are re-clustered at twice the radius.
class MapClustering {
  MapClustering._();

  static const double tileSize = 512;
  static const double _maxLat = 85.05112878;

  static bool needsRebuild({required double lastBuildZoom, required double idleZoom}) =>
      (idleZoom - lastBuildZoom).abs() >= 0.4;

  static (double, double) project(double lat, double lon, double zoom) {
    final scale = tileSize * pow(2.0, zoom);
    final s = sin(lat.clamp(-_maxLat, _maxLat) * pi / 180);
    final y = (0.5 - log((1 + s) / (1 - s)) / (4 * pi)) * scale;
    final x = (lon + 180) / 360 * scale;
    return (x, y);
  }

  static List<MapCluster<T>> cluster<T>(
    Iterable<T> items, {
    required double Function(T) lat,
    required double Function(T) lon,
    required double zoom,
    double radiusPx = 48,
    int maxClusters = 50,
  }) {
    final seeds = <MapCluster<T>>[];
    for (final item in items) {
      final la = lat(item), lo = lon(item);
      if (!la.isFinite || !lo.isFinite) continue;
      final (x, y) = project(la, lo, zoom);
      seeds.add(MapCluster<T>._(item, la, lo, x, y));
    }
    if (seeds.isEmpty) return [];
    final budget = max(1, maxClusters);
    var radius = radiusPx > 0 ? radiusPx : 1.0;
    var result = _pass(seeds, radius);
    while (result.length > budget) {
      radius *= 2;
      for (final c in result) {
        final (x, y) = project(c.latitude, c.longitude, zoom);
        c._x = x;
        c._y = y;
      }
      result = _pass(result, radius);
    }
    return result;
  }

  static List<MapCluster<T>> _pass<T>(List<MapCluster<T>> nodes, double radius) {
    final grid = <(int, int), List<MapCluster<T>>>{};
    final leaders = <MapCluster<T>>[];
    final r2 = radius * radius;
    for (final n in nodes) {
      final gi = (n._x / radius).floor();
      final gj = (n._y / radius).floor();
      MapCluster<T>? target;
      var best = double.infinity;
      for (var di = -1; di <= 1; di++) {
        for (var dj = -1; dj <= 1; dj++) {
          final cell = grid[(gi + di, gj + dj)];
          if (cell == null) continue;
          for (final c in cell) {
            final dx = n._x - c._x, dy = n._y - c._y;
            final d = dx * dx + dy * dy;
            if (d <= r2 && d < best) {
              best = d;
              target = c;
            }
          }
        }
      }
      if (target != null) {
        target._absorb(n);
      } else {
        grid.putIfAbsent((gi, gj), () => []).add(n);
        leaders.add(n);
      }
    }
    return leaders;
  }
}
