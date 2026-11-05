import 'dart:math' as math;

typedef TripPoint = ({double lat, double lng});

typedef TripDisc = ({TripPoint centre, double radiusKm});

class TripGeo {
  static const double earthKm = 6371;

  static bool valid(TripPoint p) =>
      p.lat >= -90 && p.lat <= 90 && p.lng >= -180 && p.lng <= 180 && !(p.lat == 0 && p.lng == 0);

  static double km(TripPoint a, TripPoint b) {
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(b.lat - a.lat);
    final dLng = rad(b.lng - a.lng);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return earthKm * 2 * math.asin(math.min(1.0, math.sqrt(h)));
  }

  // Distance to the nearest point of the set and its index; null for an empty set.
  static ({double km, int index})? nearest(TripPoint p, List<TripPoint> set) {
    ({double km, int index})? best;
    for (var i = 0; i < set.length; i++) {
      final d = km(p, set[i]);
      if (best == null || d < best.km) best = (km: d, index: i);
    }
    return best;
  }

  // Farthest-point (Gonzalez) clustering: the fewest greedy discs, each centred on a point of the set, whose
  // radius is at most maxRadiusKm. A point within r of the set is within (disc radius + r) of its disc centre. O(k x n).
  static List<TripDisc> cover(List<TripPoint> points, double maxRadiusKm) {
    final pts = points.where(valid).toList();
    if (pts.isEmpty) return const [];
    final centres = <int>[0];
    final dist = [for (final p in pts) km(p, pts[0])];
    final owner = List<int>.filled(pts.length, 0);
    while (true) {
      var far = -1;
      var farKm = maxRadiusKm;
      for (var i = 0; i < pts.length; i++) {
        if (dist[i] > farKm) {
          farKm = dist[i];
          far = i;
        }
      }
      if (far < 0) break;
      centres.add(far);
      final c = centres.length - 1;
      for (var i = 0; i < pts.length; i++) {
        final d = km(pts[i], pts[far]);
        if (d < dist[i]) {
          dist[i] = d;
          owner[i] = c;
        }
      }
    }
    final radius = List<double>.filled(centres.length, 0);
    for (var i = 0; i < pts.length; i++) {
      if (dist[i] > radius[owner[i]]) radius[owner[i]] = dist[i];
    }
    return [for (var c = 0; c < centres.length; c++) (centre: pts[centres[c]], radiusKm: radius[c])];
  }
}
