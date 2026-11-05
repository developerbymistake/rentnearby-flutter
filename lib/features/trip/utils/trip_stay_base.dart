import '../models/trip_plan_model.dart';
import 'trip_geo.dart';
import 'trip_map_geo.dart';

// The one stay every day of a leg starts and ends at (every day has a night), sent as the plan anchor.
// Null when the leg has no chosen stay, mixes stays, skips a night or a stay has no point.
class TripStayBase {
  TripStayBase._();

  static const double maxKmFromCity = TripMapGeo.spotMaxKmFromCity - 1;

  static TripPoint? of(TripPlan p, int legIndex) {
    final leg = p.legAt(legIndex);
    if (leg == null || !leg.hasPoint) return null;
    TripPoint? base;
    for (final d in p.days) {
      if (d.leg != leg.index) continue;
      final stay = d.stay;
      if (stay == null) continue;
      if (stay.isSkipped) return null;
      final point = pointOf(p, stay);
      if (point == null) return null;
      if (base == null) {
        base = point;
      } else if (!_same(base, point)) {
        return null;
      }
    }
    if (base == null) return null;
    if (TripGeo.km(base, (lat: leg.latitude, lng: leg.longitude)) > maxKmFromCity) return null;
    return base;
  }

  static Map<String, double> bodyOf(TripPlan p, int legIndex) {
    final b = of(p, legIndex);
    return b == null ? const {} : {'anchorLatitude': b.lat, 'anchorLongitude': b.lng};
  }

  // Where day d starts: the stay of night d - 1 in the same city leg.
  static TripPoint? startOf(TripPlan p, int day) {
    final prev = p.dayAt(day - 1);
    final stay = prev?.stay;
    if (prev == null || stay == null || stay.isSkipped || p.dayAt(day)?.leg != prev.leg) return null;
    return pointOf(p, stay);
  }

  static TripPoint? pointOf(TripPlan p, TripStayChoice s) {
    var cur = s;
    final seen = <int>{};
    while (true) {
      if (cur.hasCoordinates) {
        final point = (lat: cur.latitude!, lng: cur.longitude!);
        return point.lat.isFinite && point.lng.isFinite && TripGeo.valid(point) ? point : null;
      }
      final same = cur.sameAsDay;
      if (same == null || !seen.add(same)) return null;
      final next = p.dayAt(same)?.stay;
      if (next == null || next.isSkipped) return null;
      cur = next;
    }
  }

  static bool _same(TripPoint a, TripPoint b) =>
      (a.lat * 1e6).round() == (b.lat * 1e6).round() && (a.lng * 1e6).round() == (b.lng * 1e6).round();
}
