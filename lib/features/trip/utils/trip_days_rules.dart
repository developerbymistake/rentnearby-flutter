import 'dart:math' as math;
import '../models/trip_plan_model.dart';
import '../trip_constants.dart';

class TripDaysRules {
  static const int perDay = TripConstants.maxSpotsPerDay;

  static int _need(int places) {
    final n = (places / perDay).ceil();
    return n < 1 ? 1 : n;
  }

  static List<int> _padded(int cityCount, List<int> placesPerCity) => [
        for (var i = 0; i < math.max(cityCount, placesPerCity.length); i++) i < placesPerCity.length ? placesPerCity[i] : 0,
      ];

  static int minDays(int cityCount, List<int> placesPerCity) {
    final places = _padded(cityCount, placesPerCity);
    final sum = places.fold<int>(0, (n, p) => n + _need(p));
    return math.max(1, math.max(cityCount, sum));
  }

  static int limitFor(int days, List<int> placesPerCity, int cityIndex) {
    var others = 0;
    var otherPlaces = 0;
    for (var i = 0; i < placesPerCity.length; i++) {
      if (i == cityIndex) continue;
      others += _need(placesPerCity[i]);
      otherPlaces += placesPerCity[i] < 0 ? 0 : placesPerCity[i];
    }
    final left = days - others;
    if (left < 1) return 0;
    final byTrip = TripConstants.maxSpots - otherPlaces;
    return math.min(left * perDay, byTrip < 0 ? 0 : byTrip);
  }

  static int total(int days) => math.min(days * perDay, TripConstants.maxSpots);

  static int autoDaysFor(List<int> visits, int paceMinutes) {
    final n = visits.length;
    if (n == 0) return 1;
    final minutes = visits.fold<int>(0, (a, b) => a + b) + (n - 1) * TripConstants.driveHopMinutes;
    final byTime = (minutes / (paceMinutes < 1 ? 1 : paceMinutes)).ceil();
    return math.max(1, math.max(byTime, _need(n)));
  }

  static int autoTotal(List<List<int>> visitsPerCity, int paceMinutes) =>
      visitsPerCity.fold<int>(0, (n, v) => n + autoDaysFor(v, paceMinutes));

  static int limitForAuto(List<List<int>> visitsPerCity, int cityIndex, int paceMinutes) {
    var others = 0;
    var otherPlaces = 0;
    for (var i = 0; i < visitsPerCity.length; i++) {
      if (i == cityIndex) continue;
      others += autoDaysFor(visitsPerCity[i], paceMinutes);
      otherPlaces += visitsPerCity[i].length;
    }
    final left = TripConstants.maxDaysCap - others;
    if (left < 1) return 0;
    final byTrip = TripConstants.maxSpots - otherPlaces;
    final upper = math.min(left * perDay, byTrip < 0 ? 0 : byTrip);
    final own = cityIndex >= 0 && cityIndex < visitsPerCity.length ? visitsPerCity[cityIndex] : const <int>[];
    if (upper <= own.length) return upper;
    final sum = own.fold<int>(0, (a, b) => a + b);
    final avg = own.isEmpty ? TripConstants.defaultVisitMinutes : (sum / own.length).ceil();
    for (var n = upper; n > own.length; n--) {
      final more = [...own, for (var k = own.length; k < n; k++) avg];
      if (autoDaysFor(more, paceMinutes) <= left) return n;
    }
    return own.length;
  }

  static List<int> allocate(int days, List<List<int>> visitsPerCity, [int paceMinutes = TripPace.relaxed]) {
    final n = visitsPerCity.length;
    if (n == 0) return const [];
    final base = [for (final v in visitsPerCity) autoDaysFor(v, paceMinutes)];
    var sum = base.fold<int>(0, (a, b) => a + b);
    final floor = [for (final v in visitsPerCity) _need(v.length)];
    while (sum > days) {
      var at = -1;
      for (var i = 0; i < n; i++) {
        if (base[i] > floor[i] && (at < 0 || base[i] > base[at])) at = i;
      }
      if (at < 0) break;
      base[at]--;
      sum--;
    }
    if (days > sum) {
      var at = 0;
      for (var i = 1; i < n; i++) {
        if (visitsPerCity[i].length > visitsPerCity[at].length) at = i;
      }
      base[at]++;
    }
    return base;
  }

  static int suggestedDays(int spotCount) => (spotCount / perDay).ceil().clamp(1, 3).toInt();

  static bool canAddOnDay(TripPlan p, int day) => (p.dayAt(day)?.spots.length ?? perDay) < perDay;

  static bool canRemoveDay(TripPlan p, int day) {
    final d = p.dayAt(day);
    if (d == null) return false;
    final leg = p.legIndexOf(day);
    final legDays = p.legDayCount(leg);
    if (legDays <= 1) return false;
    return p.legSpotCount(leg) <= (legDays - 1) * perDay;
  }
}
