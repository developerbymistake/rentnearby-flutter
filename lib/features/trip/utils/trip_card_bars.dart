import '../models/trip_model.dart';
import '../models/trip_plan_model.dart';

class TripCardBar {
  final double fraction;
  final String caption;
  const TripCardBar(this.fraction, this.caption);
}

class TripCardBars {
  final TripCardBar stay;
  final TripCardBar taxi;
  final TripCardBar travel;
  const TripCardBars(this.stay, this.taxi, this.travel);

  static const _notStarted = 'not started';
  static const _booked = 'booked';
  static const _done = 'done';

  static TripCardBars of(TripSummaryModel t) {
    final rows = t.progress.rows.where((r) => r.state != TripRowState.skipped).toList();
    List<TripEasyRowModel> pick(Set<TripEasyRowKind> kinds) => rows.where((r) => kinds.contains(r.kind)).toList();
    return TripCardBars(
      _stay(pick({TripEasyRowKind.stay})),
      _simple(pick({TripEasyRowKind.taxi})),
      _simple(pick({TripEasyRowKind.gettingThere, TripEasyRowKind.between, TripEasyRowKind.comingBack})),
    );
  }

  static int _doneCount(List<TripEasyRowModel> r) => r.where((e) => e.state.isDone).length;

  static double _fraction(List<TripEasyRowModel> r) => r.isEmpty ? 0 : _doneCount(r) / r.length;

  static TripCardBar _stay(List<TripEasyRowModel> r) {
    final f = _fraction(r);
    final started = r.any((e) => e.state.inProgress);
    final nights = r.isNotEmpty && r.every((e) => e.nightsTotal != null);
    final total = nights ? r.fold<int>(0, (n, e) => n + e.nightsTotal!) : 0;
    final covered = nights ? r.fold<int>(0, (n, e) => n + (e.nightsCovered ?? 0)) : 0;
    if (f >= 1 && r.isNotEmpty) return TripCardBar(1, nights ? '$total nights' : _done);
    if (covered == 0 && _doneCount(r) == 0 && !started) return TripCardBar(0, _notStarted);
    if (nights) return TripCardBar(total == 0 ? f : (covered / total).clamp(0.0, 1.0), '$covered of $total nights');
    return TripCardBar(f, '${_doneCount(r)} of ${r.length} done');
  }

  static TripCardBar _simple(List<TripEasyRowModel> r) {
    final f = _fraction(r);
    if (r.isNotEmpty && f >= 1) return TripCardBar(1, _booked);
    final started = r.any((e) => e.state.inProgress);
    if (r.isEmpty || (_doneCount(r) == 0 && !started)) return TripCardBar(f, _notStarted);
    return TripCardBar(f, '${_doneCount(r)} of ${r.length} done');
  }
}
