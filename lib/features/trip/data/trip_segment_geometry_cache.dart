import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import '../../taxi/ways/models/taxi_ways_models.dart';

class TripSegmentGeometryCache {
  TripSegmentGeometryCache._();

  static final Map<String, List<LatLng>> _byPlan = {};

  static void put(String planKey, List<LatLngPair> points) {
    if (planKey.isEmpty || points.length < 2) return;
    _byPlan[planKey] = List.unmodifiable([for (final p in points) LatLng(p.lat, p.lng)]);
  }

  static void putPlan(WayPlan plan) {
    if (plan.planKey.isEmpty || plan.legs.isEmpty) return;
    final legs = [...plan.legs]..sort((a, b) => a.index.compareTo(b.index));
    final points = <LatLngPair>[];
    for (final leg in legs) {
      final g = leg.geometry;
      if (g == null || g.length < 2) return;
      points.addAll(g);
    }
    put(plan.planKey, points);
  }

  static List<LatLng>? get(String? planKey) => planKey == null ? null : _byPlan[planKey];

  static void clear() => _byPlan.clear();
}
