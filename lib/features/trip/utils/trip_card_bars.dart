import '../models/trip_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_strings_hub_trips.dart';
import 'trip_parts.dart';

class TripCardBar {
  final double fraction;
  final String caption;
  const TripCardBar(this.fraction, this.caption);
}

class TripCardBars {
  final TripCardBar stay;
  final TripCardBar taxi;
  final TripCardBar plan;
  const TripCardBars(this.stay, this.taxi, this.plan);

  static TripCardBars of(TripSummaryModel t) {
    final parts = t.parts;
    final rows = t.progress.rows;
    return TripCardBars(
      _stay(parts.stay, [for (final r in rows) if (r.kind == TripEasyRowKind.stay) r]),
      _taxi(parts.taxi, rows.where((r) => r.kind == TripEasyRowKind.taxi).firstOrNull),
      parts.itinerary == TripPartState.open
          ? const TripCardBar(0, TripStringsHubTrips.notSaved)
          : const TripCardBar(1, TripStringsHubTrips.saved),
    );
  }

  static TripCardBar _stay(TripPartState s, List<TripEasyRowModel> r) {
    if (s == TripPartState.open) return const TripCardBar(0, TripStringsHubTrips.notAdded);
    if (s == TripPartState.skipped) return const TripCardBar(1, TripStringsHubTrips.skipped);
    final counted = [for (final e in r) if (TripParts.arranged(e.state)) e];
    if (counted.isNotEmpty && counted.every((e) => e.nightsTotal != null)) {
      final total = r.fold<int>(0, (n, e) => n + (e.nightsTotal ?? 0));
      final covered = counted.fold<int>(0, (n, e) => n + (e.nightsCovered ?? e.nightsTotal ?? 0));
      if (total > 0) {
        return TripCardBar(1, covered >= total ? TripStringsHubTrips.nights(total) : TripStringsHubTrips.nightsOf(covered, total));
      }
    }
    return const TripCardBar(1, TripStringsHubTrips.asked);
  }

  static TripCardBar _taxi(TripPartState s, TripEasyRowModel? r) => switch (s) {
        TripPartState.open => const TripCardBar(0, TripStringsHubTrips.notAdded),
        TripPartState.skipped => const TripCardBar(1, TripStringsHubTrips.skipped),
        TripPartState.arranged => TripCardBar(1, r != null && r.state.isDone ? TripStringsHubTrips.booked : TripStringsHubTrips.requested),
      };
}
