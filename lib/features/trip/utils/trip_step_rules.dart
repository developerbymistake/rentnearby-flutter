import '../../taxi/taxi_option_sets.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_constants.dart';

class TripStepRules {
  const TripStepRules._();

  static TripStepDisplay display(TripStep step, TripJourney? journey) => switch (step.status) {
        TripStepStatus.own => TripStepDisplay.own,
        TripStepStatus.skipped => TripStepDisplay.skipped,
        TripStepStatus.notNeeded => TripStepDisplay.notNeeded,
        TripStepStatus.notStarted => TripStepDisplay.notStarted,
        TripStepStatus.booked =>
          step.hasJourney && journey != null && journey.id == step.journeyId ? TripStepDisplay.booked : TripStepDisplay.notStarted,
        TripStepStatus.chosen => !step.hasJourney || journey == null || journey.id != step.journeyId
            ? TripStepDisplay.notStarted
            : (journey.isAsked ? TripStepDisplay.asked : TripStepDisplay.chosen),
      };

  static bool isSorted(TripStepDisplay d) => d != TripStepDisplay.notStarted;

  static DateTime? expectedDate(TripStepRole role, TripStep step, TripSettings settings, int dayCount) {
    final own = step.date;
    if (own != null) return DateTime(own.year, own.month, own.day);
    return role == TripStepRole.gettingThere ? settings.startDate : settings.checkOutDate(dayCount);
  }

  static bool dateChanged(DateTime? expected, DateTime travel) =>
      expected != null &&
      (expected.year != travel.year || expected.month != travel.month || expected.day != travel.day);

  static bool _hasPoint(double lat, double lon) => !(lat == 0 && lon == 0);

  static bool startChanged(
    TripStepRole role,
    TripStartFrom? start,
    TripJourney j, {
    double? cityLat,
    double? cityLon,
  }) =>
      _startMoved(role, start, j) || cityChanged(role, j, cityLat, cityLon);

  static bool _startMoved(TripStepRole role, TripStartFrom? start, TripJourney j) {
    if (start == null) return false;
    final lat = role == TripStepRole.gettingThere ? j.fromLat : j.toLat;
    final lon = role == TripStepRole.gettingThere ? j.fromLng : j.toLng;
    if (!_hasPoint(lat, lon)) return false;
    return TaxiOptionSets.distanceMeters(start.lat, start.lon, lat, lon) > TripConstants.sameCityMeters;
  }

  static bool cityChanged(TripStepRole role, TripJourney j, double? cityLat, double? cityLon) {
    if (cityLat == null || cityLon == null || !_hasPoint(cityLat, cityLon)) return false;
    final lat = role == TripStepRole.gettingThere ? j.toLat : j.fromLat;
    final lon = role == TripStepRole.gettingThere ? j.toLng : j.fromLng;
    if (!_hasPoint(lat, lon)) return false;
    return TaxiOptionSets.distanceMeters(cityLat, cityLon, lat, lon) > TripConstants.sameCityMeters;
  }

  static bool insideCity(TripStartFrom? start, double? lat, double? lon) {
    if (start == null || lat == null || lon == null || !_hasPoint(lat, lon)) return false;
    return TaxiOptionSets.distanceMeters(start.lat, start.lon, lat, lon) < TripConstants.sameCityMeters;
  }

  static bool needsNudge(TripStep step, TripStartFrom? start, DateTime? startDate, DateTime today) {
    if (step.status != TripStepStatus.notStarted || start == null || startDate == null) return false;
    final left = DateTime.utc(startDate.year, startDate.month, startDate.day)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;
    return left >= 0 && left <= TripConstants.stepNudgeDays;
  }

  static int sortedCount(List<TripStepDisplay> five) => five.where(isSorted).length;

  static TripSteps withAutoNotNeeded(
    TripSteps steps,
    double? firstLat,
    double? firstLon, [
    double? lastLat,
    double? lastLon,
  ]) {
    final hasLast = lastLat != null && lastLon != null;
    final insideFirst = insideCity(steps.startFrom, firstLat, firstLon);
    final insideLast = hasLast ? insideCity(steps.startFrom, lastLat, lastLon) : insideFirst;
    var out = steps;
    for (final r in TripStepRole.values) {
      final inside = r == TripStepRole.gettingThere ? insideFirst : insideLast;
      final s = out.of(r);
      if (inside && s.status == TripStepStatus.notStarted && s.journeyId == null) {
        out = out.withStep(r, s.copyWith(status: TripStepStatus.notNeeded, clearDate: true));
      } else if (!inside && s.status == TripStepStatus.notNeeded) {
        out = out.withStep(r, s.copyWith(status: TripStepStatus.notStarted));
      }
    }
    return out;
  }

  static TripStepDisplay groupDisplay({required int total, required int sorted, required int skipped, required int own}) {
    if (total < 1 || sorted < total) return TripStepDisplay.notStarted;
    if (skipped == total) return TripStepDisplay.skipped;
    if (own == total) return TripStepDisplay.own;
    return TripStepDisplay.chosen;
  }
}
