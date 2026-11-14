import '../models/trip_model.dart';
import 'trip_bar_rules.dart';

class TripContinuePick {
  static const int railMax = 3;

  /// Incomplete trips, soonest start first (newest edit breaks ties); undated trips follow, newest edit first.
  static List<TripSummaryModel> pickMany(List<TripSummaryModel> trips, DateTime today, [int max = railMax]) {
    final dated = <TripSummaryModel>[];
    final undated = <TripSummaryModel>[];
    for (final t in trips) {
      if (t.isCompleted || TripBarRules.isPast(t, today)) continue;
      (t.startDate == null ? undated : dated).add(t);
    }
    int newest(TripSummaryModel a, TripSummaryModel b) => b.updatedAt.compareTo(a.updatedAt);
    dated.sort((a, b) {
      final c = a.startDate!.compareTo(b.startDate!);
      return c != 0 ? c : newest(a, b);
    });
    undated.sort(newest);
    return [...dated, ...undated].take(max).toList();
  }
}
