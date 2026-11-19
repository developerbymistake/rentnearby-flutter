import '../models/trip_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_summary_model.dart';

enum TripPart { itinerary, taxi, stay }

enum TripPartState { open, arranged, skipped }

class TripParts {
  final TripPartState itinerary;
  final TripPartState taxi;
  final TripPartState stay;

  const TripParts({required this.itinerary, required this.taxi, required this.stay});

  static const TripParts none =
      TripParts(itinerary: TripPartState.open, taxi: TripPartState.open, stay: TripPartState.open);

  static const TripParts saved =
      TripParts(itinerary: TripPartState.arranged, taxi: TripPartState.open, stay: TripPartState.open);

  static const int total = 3;

  int get handled => [itinerary, taxi, stay].where((s) => s != TripPartState.open).length;

  int get percent => (handled * 100 / total).round();

  bool get complete => handled == total;

  TripPart? get next => stay == TripPartState.open
      ? TripPart.stay
      : taxi == TripPartState.open
          ? TripPart.taxi
          : null;

  TripPartState of(TripPart p) => switch (p) {
        TripPart.itinerary => itinerary,
        TripPart.taxi => taxi,
        TripPart.stay => stay,
      };

  static bool arranged(TripRowState s) =>
      s == TripRowState.asked ||
      s == TripRowState.offer ||
      s == TripRowState.booked ||
      s == TripRowState.confirmed ||
      s == TripRowState.own;

  static TripParts from({required bool hasItinerary, required Iterable<(TripEasyRowKind, TripRowState)> rows}) {
    final stays = [for (final r in rows) if (r.$1 == TripEasyRowKind.stay) r.$2];
    final taxis = [for (final r in rows) if (r.$1 == TripEasyRowKind.taxi) r.$2];
    TripPartState stay;
    if (stays.any(arranged)) {
      stay = TripPartState.arranged;
    } else if (stays.isNotEmpty && stays.every((s) => s == TripRowState.skipped)) {
      stay = TripPartState.skipped;
    } else {
      stay = TripPartState.open;
    }
    final t = taxis.isEmpty ? null : taxis.first;
    final taxi = t == null
        ? TripPartState.open
        : arranged(t)
            ? TripPartState.arranged
            : t == TripRowState.skipped
                ? TripPartState.skipped
                : TripPartState.open;
    return TripParts(
      itinerary: hasItinerary ? TripPartState.arranged : TripPartState.open,
      taxi: taxi,
      stay: stay,
    );
  }

  static TripParts ofSummary(TripSummaryModel t) =>
      from(hasItinerary: t.spotCount > 0, rows: [for (final r in t.progress.rows) (r.kind, r.state)]);

  static TripParts ofRecord(TripSummaryRecord r) =>
      from(hasItinerary: r.hasItinerary, rows: [for (final a in r.arrangements) (a.key.kind, a.state)]);

  @override
  bool operator ==(Object other) =>
      other is TripParts && other.itinerary == itinerary && other.taxi == taxi && other.stay == stay;

  @override
  int get hashCode => Object.hash(itinerary, taxi, stay);
}

extension TripSummaryParts on TripSummaryModel {
  TripParts get parts => TripParts.ofSummary(this);
}
