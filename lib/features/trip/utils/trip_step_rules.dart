import '../../taxi/taxi_option_sets.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_constants.dart';

class TripStepRules {
  const TripStepRules._();

  static DateTime? expectedDate(TripStepRole role, TripStep step, TripSettings settings, int dayCount) {
    final own = step.date;
    if (own != null) return DateTime(own.year, own.month, own.day);
    if (role == TripStepRole.gettingThere) return settings.startDate;
    return step.leaveOnOrDefault == TripLeaveOn.lastDayEvening
        ? settings.endDate(dayCount)
        : settings.checkOutDate(dayCount);
  }

  // The journey still fits the other leave time, so only "When do you leave?" moved it.
  static bool leaveMoved(TripStep step, DateTime travel, TripSettings settings, int dayCount) {
    final other = step.leaveOnOrDefault == TripLeaveOn.lastDayEvening ? TripLeaveOn.checkOut : TripLeaveOn.lastDayEvening;
    final was = expectedDate(TripStepRole.comingBack, step.copyWith(leaveOn: other, clearDate: true), settings, dayCount);
    return was != null && !dateChanged(was, travel);
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
}
