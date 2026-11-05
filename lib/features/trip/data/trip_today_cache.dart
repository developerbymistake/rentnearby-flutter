import '../../../services/storage_service.dart';
import '../models/trip_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_plan_result_model.dart';

class TripTodayCache {
  static void saveTrip(TripModel t) {
    final raw = t.raw;
    if (raw != null) StorageService.saveTripCache(t.id, raw);
  }

  static void savePlan(TripModel t, TripPlan plan) {
    final cached = StorageService.getTripCache(t.id);
    final base = cached ?? t.raw;
    if (base == null) return;
    StorageService.saveTripCache(t.id, {
      ...base,
      'plan': plan.toJson(),
      'legCount': plan.legs.length,
      'legCities': plan.legs.map((l) => l.cityName).toList(),
      if (t.journeysKnown) 'journeys': t.journeys.map((j) => j.toJson()).toList(),
    });
  }

  static TripModel? trip(String id) {
    final json = StorageService.getTripCache(id);
    if (json == null) return null;
    try {
      return TripModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static void saveResult(String tripId, TripPlanResult r) => StorageService.saveTripResultCache(tripId, r.toJson());

  static TripPlanResult? result(String tripId) {
    final json = StorageService.getTripResultCache(tripId);
    if (json == null) return null;
    try {
      return TripPlanResult.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static void queueProblem(Map<String, dynamic> item) =>
      StorageService.saveTripProblemQueue([...StorageService.getTripProblemQueue(), item]);

  static List<Map<String, dynamic>> drainProblems() {
    final items = StorageService.getTripProblemQueue();
    if (items.isNotEmpty) StorageService.saveTripProblemQueue(const []);
    return items;
  }
}
