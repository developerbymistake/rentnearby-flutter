import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:get/get.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../utils/network_retry.dart';
import '../controllers/trip_plan_controller.dart';
import '../data/trip_repository.dart';
import '../data/trip_today_cache.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_summary_model.dart';
import 'trip_clock.dart';
import 'trip_day_load.dart';
import 'trip_wizard_rules.dart';

class TripSummarySnapshot {
  final TripSummaryRecord record;
  final DateTime? cachedAt;

  const TripSummarySnapshot(this.record, {this.cachedAt});

  bool get fromCache => cachedAt != null;
}

class TripSummarySource {
  static const String _savedKey = 'cachedAt';

  static final Map<String, TripWizardInput> _cachedInputs = {};

  static TripWizardInput wizardInput(TripSummaryRecord r) {
    final live = Get.isRegistered<TripPlanController>() ? Get.find<TripPlanController>() : null;
    if (live != null && live.trip.value?.id == r.tripId) return live.wizardInput;
    return _cachedInputs[r.tripId] ?? recordInput(r);
  }

  static TripWizardInput recordInput(TripSummaryRecord r) {
    final plan = TripPlan.singleCity(
      cityKey: 0,
      cityName: r.city,
      days: [for (final d in r.days) TripDay(day: d.day)],
      settings: TripSettings(startDate: r.startDate, adults: r.adults, kids: r.kids),
      steps: r.steps,
    );
    return TripWizardInput(
      plan: plan,
      enquiries: const [],
      journeys: [?r.gettingThere, ?r.comingBack],
      steps: r.steps,
      dismissedEnquiryIds: const {},
      today: TripClock.today(),
      readOnly: true,
      supplyKnown: (_) => true,
    );
  }

  static void _rememberInput(TripSummaryRecord r) {
    final t = TripTodayCache.trip(r.tripId);
    if (t == null) {
      _cachedInputs.remove(r.tripId);
      return;
    }
    _cachedInputs[r.tripId] = TripWizardInput(
      plan: t.plan,
      enquiries: t.enquiries,
      journeys: t.journeys,
      steps: t.plan.steps,
      dismissedEnquiryIds: t.plan.dismissedEnquiryIds.toSet(),
      today: TripClock.today(),
      readOnly: true,
      supplyKnown: (_) => true,
    );
  }

  static bool isGone(Object e) {
    if (DioErrorMapper.errorType(e) == TripErrorTypes.tripNotFound) return true;
    if (e is! DioException) return false;
    final code = e.response?.statusCode;
    return code == 404 || code == 403;
  }

  static Map<String, dynamic> _data(Map<String, dynamic> res) {
    final data = res['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  static TripSummaryRecord _withRoadTime(TripSummaryRecord r) {
    final live = Get.isRegistered<TripPlanController>() ? Get.find<TripPlanController>() : null;
    final byDay = <int, int>{};
    if (live != null && live.trip.value?.id == r.tripId) {
      for (final d in r.days) {
        final m = live.roadDayMinutes(d.day, d.spots);
        if (m != null && m > 0) byDay[d.day] = m;
      }
      return r.withDayMinutes(byDay);
    }
    final plan = TripTodayCache.trip(r.tripId)?.plan;
    final result = TripTodayCache.result(r.tripId);
    if (plan == null || result == null) return r;
    for (final d in r.days) {
      final pd = plan.dayAt(d.day);
      final rd = result.dayAt(d.day);
      if (pd == null || rd == null) continue;
      final minutes = TripDayLoad.route(serverTotal: rd.totalMinutes, visitMinutes: pd.visitMinutes);
      if (minutes <= 0) continue;
      if (!listEquals([for (final s in pd.spots) s.id], rd.spotIds)) continue;
      if (!listEquals([for (final s in pd.spots) s.name], d.spots)) continue;
      byDay[d.day] = minutes;
    }
    return r.withDayMinutes(byDay);
  }

  static TripSummarySnapshot? cached(String tripId) {
    final json = StorageService.getTripSummaryCache(tripId);
    if (json == null) return null;
    try {
      final record = TripSummaryRecord.fromJson(json);
      _rememberInput(record);
      return TripSummarySnapshot(
        _withRoadTime(record),
        cachedAt: DateTime.tryParse(json[_savedKey] as String? ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<TripSummarySnapshot> load(String tripId) async {
    final path = '/trips/$tripId/summary';
    final saved = cached(tripId);
    try {
      final data = _data(saved == null ? await withRetry(() => ApiService.get(path)) : await ApiService.get(path));
      final record = _withRoadTime(TripSummaryRecord.fromJson(data));
      _rememberInput(record);
      StorageService.saveTripSummaryCache(tripId, {...data, _savedKey: DateTime.now().toIso8601String()});
      return TripSummarySnapshot(record);
    } catch (e) {
      if (saved != null && DioErrorMapper.isNetworkError(e)) return saved;
      rethrow;
    }
  }
}
