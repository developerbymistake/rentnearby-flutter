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

  static List<int> allocate(int days, List<int> placesPerCity) {
    final n = placesPerCity.length;
    if (n == 0) return const [];
    final base = [for (final p in placesPerCity) _need(p)];
    var sum = base.fold<int>(0, (a, b) => a + b);
    while (sum > days) {
      var at = -1;
      for (var i = 0; i < n; i++) {
        if (base[i] > 1 && (at < 0 || base[i] > base[at])) at = i;
      }
      if (at < 0) break;
      base[at]--;
      sum--;
    }
    final extra = days - sum;
    if (extra <= 0) return base;
    final weight = [for (final p in placesPerCity) p < 0 ? 0 : p];
    final totalWeight = weight.fold<int>(0, (a, b) => a + b);
    final shares = [for (var i = 0; i < n; i++) totalWeight == 0 ? extra / n : extra * weight[i] / totalWeight];
    final out = [for (var i = 0; i < n; i++) base[i] + shares[i].floor()];
    var left = days - out.fold<int>(0, (a, b) => a + b);
    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) {
        final c = (shares[b] - shares[b].floor()).compareTo(shares[a] - shares[a].floor());
        return c != 0 ? c : a.compareTo(b);
      });
    for (var k = 0; left > 0; k++, left--) {
      out[order[k % n]]++;
    }
    return out;
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
