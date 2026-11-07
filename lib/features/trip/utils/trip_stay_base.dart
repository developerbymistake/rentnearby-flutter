import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import 'trip_geo.dart';
import 'trip_map_geo.dart';

// The one confirmed stay of a leg is where every day of that leg starts and ends (sent as the plan anchor).
// Null when the leg has no confirmed stay, confirmed stays differ, or the stay has no point.
class TripStayBase {
  TripStayBase._();

  static const double maxKmFromCity = TripMapGeo.spotMaxKmFromCity - 1;

  static TripPoint? of(TripPlan p, int legIndex, List<TripEnquiryModel> enquiries) {
    final leg = p.legAt(legIndex);
    if (leg == null || !leg.hasPoint) return null;
    final days = {for (final d in p.daysOf(legIndex)) d.day};
    final start = p.settings.startDate;
    TripPoint? base;
    for (final e in enquiries) {
      if (e.isTaxi || e.isSegment || !e.isBooked) continue;
      if (!_inLeg(e, days, start)) continue;
      final point = pointOf(e);
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

  static bool _inLeg(TripEnquiryModel e, Set<int> days, DateTime? start) {
    final ci = e.checkIn;
    final first = days.isEmpty ? null : days.reduce((a, b) => a < b ? a : b);
    if (ci != null && start != null && first != null) {
      final offset = DateTime.utc(ci.year, ci.month, ci.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays + 1;
      final nights = e.nights < 1 ? 1 : e.nights;
      for (var n = 0; n < nights; n++) {
        if (days.contains(offset + n)) return true;
      }
      return false;
    }
    final d = e.day;
    return d != null && days.contains(d);
  }

  static String? nameOf(TripPlan p, int legIndex, List<TripEnquiryModel> enquiries) {
    final base = of(p, legIndex, enquiries);
    if (base == null) return null;
    final days = {for (final d in p.daysOf(legIndex)) d.day};
    for (final e in enquiries) {
      if (e.isTaxi || e.isSegment || !e.isBooked || !_inLeg(e, days, p.settings.startDate)) continue;
      final point = pointOf(e);
      if (point != null && same(point, base)) return e.listingName.trim().isEmpty ? null : e.listingName.trim();
    }
    return null;
  }

  static Map<String, double> bodyOf(TripPlan p, int legIndex, List<TripEnquiryModel> enquiries) {
    final b = of(p, legIndex, enquiries);
    return b == null ? const {} : {'anchorLatitude': b.lat, 'anchorLongitude': b.lng};
  }

  static ({TripPoint? start, TripPoint? end}) dayEnds(TripPlan p, int day, List<TripEnquiryModel> enquiries) {
    if (p.dayAt(day) == null) return (start: null, end: null);
    final base = of(p, p.legIndexOf(day), enquiries);
    return (start: base, end: base);
  }

  static Map<String, double> dayBodyOf(TripPlan p, int day, List<TripEnquiryModel> enquiries) {
    final e = dayEnds(p, day, enquiries);
    final s = e.start;
    final t = e.end;
    return {
      if (s != null) 'startLatitude': s.lat,
      if (s != null) 'startLongitude': s.lng,
      if (t != null) 'endLatitude': t.lat,
      if (t != null) 'endLongitude': t.lng,
    };
  }

  static TripPoint? startOf(TripPlan p, int day, List<TripEnquiryModel> enquiries) {
    final k = p.legIndexOf(day);
    if (day <= p.legStart(k)) return null;
    return of(p, k, enquiries);
  }

  static TripPoint? pointOf(TripEnquiryModel e) {
    final lat = e.listingLatitude;
    final lng = e.listingLongitude;
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) return null;
    final point = (lat: lat, lng: lng);
    return TripGeo.valid(point) ? point : null;
  }

  static bool same(TripPoint a, TripPoint b) =>
      (a.lat * 1e6).round() == (b.lat * 1e6).round() && (a.lng * 1e6).round() == (b.lng * 1e6).round();
}
