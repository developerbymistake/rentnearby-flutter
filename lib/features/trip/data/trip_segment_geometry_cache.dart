import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import '../../taxi/ways/models/taxi_ways_models.dart';

typedef TripChangePlace = ({LatLng at, String name});

class TripSegmentGeometryCache {
  TripSegmentGeometryCache._();

  static final Map<String, List<LatLng>> _byPlan = {};
  static final Map<String, List<TripChangePlace>> _changes = {};
  static final Map<String, List<TripChangePlace>> _via = {};

  static void put(String planKey, List<LatLngPair> points) {
    if (planKey.isEmpty || points.length < 2) return;
    _byPlan[planKey] = List.unmodifiable([for (final p in points) LatLng(p.lat, p.lng)]);
  }

  static void putPlan(WayPlan plan) {
    if (plan.planKey.isEmpty || plan.legs.isEmpty) return;
    final legs = [...plan.legs]..sort((a, b) => a.index.compareTo(b.index));
    _via[plan.planKey] = List.unmodifiable([
      for (final leg in legs)
        for (final v in leg.passStops) (at: LatLng(v.lat, v.lng), name: v.name),
    ]);
    final points = <LatLngPair>[];
    for (final leg in legs) {
      final g = leg.geometry;
      if (g == null || g.length < 2) return;
      points.addAll(g);
    }
    put(plan.planKey, points);
    _changes[plan.planKey] = List.unmodifiable([
      for (var i = 0; i < legs.length - 1; i++)
        if (legs[i].to.resolved) (at: LatLng(legs[i].to.lat, legs[i].to.lng), name: legs[i].to.name),
    ]);
  }

  static List<LatLng>? get(String? planKey) => planKey == null ? null : _byPlan[planKey];

  static List<TripChangePlace> changePlacesFor(String? planKey) =>
      planKey == null ? const [] : (_changes[planKey] ?? const []);

  // The cities the road runs through between the two ends, in order (never the ends themselves).
  static List<TripChangePlace> viaFor(String? planKey) => planKey == null ? const [] : (_via[planKey] ?? const []);

  static void clear() {
    _byPlan.clear();
    _changes.clear();
    _via.clear();
  }
}
