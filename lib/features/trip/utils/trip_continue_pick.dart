import '../models/trip_model.dart';
import 'trip_bar_rules.dart';

class TripContinuePick {
  static TripSummaryModel? pick(List<TripSummaryModel> trips, DateTime today) {
    TripSummaryModel? dated;
    TripSummaryModel? undated;
    for (final t in trips) {
      if (t.isCompleted || TripBarRules.isPast(t, today)) continue;
      final s = t.startDate;
      if (s == null) {
        if (undated == null || t.updatedAt.isAfter(undated.updatedAt)) undated = t;
        continue;
      }
      final d = dated;
      if (d == null || s.isBefore(d.startDate!) || (s == d.startDate && t.updatedAt.isAfter(d.updatedAt))) dated = t;
    }
    return dated ?? undated;
  }
}
