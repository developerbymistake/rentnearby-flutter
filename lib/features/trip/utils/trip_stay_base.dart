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
      } else if (!same(base, point)) {
        return null;
      }
    }
    if (base == null) return null;
    if (TripGeo.km(base, (lat: leg.latitude, lng: leg.longitude)) > maxKmFromCity) return null;
    return base;
  }

  static String? nameOf(TripPlan p, int legIndex, TripPoint base) {
    for (final d in p.days) {
      final stay = d.stay;
      if (d.leg != legIndex || stay == null) continue;
      final point = pointOf(p, stay);
      if (point != null && same(point, base)) return stay.name.trim().isEmpty ? null : stay.name.trim();
    }
    return null;
  }

  static Map<String, double> bodyOf(TripPlan p, int legIndex) {
    final b = of(p, legIndex);
    return b == null ? const {} : {'anchorLatitude': b.lat, 'anchorLongitude': b.lng};
  }

  // Day d of the planner runs from last night's stay to tonight's; the leg base where a night has no point.
  static ({TripPoint? start, TripPoint? end}) dayEnds(TripPlan p, int day) {
    final d = p.dayAt(day);
    if (d == null) return (start: null, end: null);
    final leg = p.legIndexOf(day);
    final base = of(p, leg);
    final stay = d.stay;
    final tonight = stay == null || stay.isSkipped ? null : _near(p, leg, pointOf(p, stay));
    return (start: _near(p, leg, startOf(p, day)) ?? base, end: tonight ?? base);
  }

  static Map<String, double> dayBodyOf(TripPlan p, int day) {
    final e = dayEnds(p, day);
    final s = e.start;
    final t = e.end;
    return {
      if (s != null) 'startLatitude': s.lat,
      if (s != null) 'startLongitude': s.lng,
      if (t != null) 'endLatitude': t.lat,
      if (t != null) 'endLongitude': t.lng,
    };
  }

  static TripPoint? _near(TripPlan p, int legIndex, TripPoint? point) {
    final leg = p.legAt(legIndex);
    if (point == null || leg == null || !leg.hasPoint) return null;
    return TripGeo.km(point, (lat: leg.latitude, lng: leg.longitude)) > maxKmFromCity ? null : point;
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

  static bool same(TripPoint a, TripPoint b) =>
      (a.lat * 1e6).round() == (b.lat * 1e6).round() && (a.lng * 1e6).round() == (b.lng * 1e6).round();
}
