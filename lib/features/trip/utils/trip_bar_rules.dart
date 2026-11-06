import '../models/trip_model.dart';
import '../trip_strings_bar.dart';
import 'trip_clock.dart';
import 'trip_wizard_rules.dart';

enum TripBarLine { next, today, tomorrow }

class TripBarPick {
  final TripSummaryModel trip;
  final int more;
  final TripBarLine line;

  const TripBarPick(this.trip, {this.more = 0, this.line = TripBarLine.next});
}

class TripBarHide {
  final DateTime hiddenAt;
  final int? needYou;

  const TripBarHide(this.hiddenAt, {this.needYou});
}

class TripListGroups {
  final List<TripSummaryModel> inProgress;
  final List<TripSummaryModel> ready;

  const TripListGroups(this.inProgress, this.ready);
}

class TripBarRules {
  static bool isReady(TripSummaryModel t) {
    final p = t.progress;
    return p.total > 0 && p.counted >= p.total;
  }

  static DateTime? endOf(TripSummaryModel t) {
    final s = t.startDate;
    if (s == null) return null;
    return t.endDate ?? DateTime(s.year, s.month, s.day + (t.dayCount < 1 ? 0 : t.dayCount - 1));
  }

  // Past = completed, or the day after check-out has passed (EndDate + 1 < today).
  static bool isPast(TripSummaryModel t, DateTime today) {
    if (t.isCompleted) return true;
    final end = endOf(t);
    return end != null && TripClock.daysBetween(end, today) > 1;
  }

  static TripListGroups group(List<TripSummaryModel> active, DateTime today) {
    final inProgress = <TripSummaryModel>[];
    final ready = <TripSummaryModel>[];
    for (final t in active) {
      if (isPast(t, today)) continue;
      (isReady(t) ? ready : inProgress).add(t);
    }
    return TripListGroups(inProgress, ready);
  }

  static int? _daysToStart(TripSummaryModel t, DateTime today) {
    final s = t.startDate;
    return s == null ? null : TripClock.daysBetween(today, s);
  }

  static bool _running(TripSummaryModel t, DateTime today) => t.isRunningOn(today) || t.isCheckOutDay(today);

  static TripBarPick? pick(
    List<TripSummaryModel> trips,
    DateTime today, {
    bool Function(TripSummaryModel t)? isHidden,
  }) {
    final candidates = <TripSummaryModel>[];
    for (final t in trips) {
      if (isPast(t, today)) continue;
      if (isHidden != null && isHidden(t)) continue;
      if (isReady(t)) {
        final d = _daysToStart(t, today);
        if (d != 0 && d != 1) continue;
      }
      candidates.add(t);
    }
    if (candidates.isEmpty) return null;
    TripSummaryModel? chosen;
    for (final t in candidates) {
      if (_running(t, today)) {
        chosen = t;
        break;
      }
    }
    if (chosen == null) {
      for (final t in candidates) {
        if (isReady(t) || t.startDate == null) continue;
        final c = chosen;
        if (c == null ||
            t.startDate!.isBefore(c.startDate!) ||
            (t.startDate == c.startDate && t.updatedAt.isAfter(c.updatedAt))) {
          chosen = t;
        }
      }
    }
    if (chosen == null) {
      for (final t in candidates) {
        if (isReady(t)) continue;
        if (chosen == null || t.updatedAt.isAfter(chosen.updatedAt)) chosen = t;
      }
    }
    final picked = chosen ?? candidates.first;
    var line = TripBarLine.next;
    if (isReady(picked)) line = _daysToStart(picked, today) == 0 ? TripBarLine.today : TripBarLine.tomorrow;
    return TripBarPick(picked, more: candidates.length - 1, line: line);
  }

  static bool stillHidden(TripSummaryModel t, TripBarHide? hide, DateTime today) {
    if (hide == null) return false;
    final last = t.progress.lastEventAt;
    if (last != null && last.isAfter(hide.hiddenAt)) return false;
    final before = hide.needYou;
    if (before != null && t.progress.needYou > before) return false;
    final s = t.startDate;
    if (s != null) {
      final hiddenDay = TripClock.today(hide.hiddenAt.toUtc());
      if (TripClock.daysBetween(today, s) <= 1 && TripClock.daysBetween(hiddenDay, s) > 1) return false;
    }
    return true;
  }

  static String? nextTitle(TripSummaryModel t) {
    final next = t.progress.next;
    if (next == null) return null;
    final key = TripStepKey.parse(next.key);
    if (key == null) return null;
    switch (key.kind) {
      case TripWizardStepKind.basics:
        return TripStringsBar.tripBasics;
      case TripWizardStepKind.gettingThere:
        return TripStringsBar.gettingThere;
      case TripWizardStepKind.comingBack:
        return TripStringsBar.comingBack;
      case TripWizardStepKind.travel:
        final leg = key.legIndex ?? 0;
        final cities = t.legCities;
        return leg >= 2 && leg <= cities.length
            ? TripStringsBar.move(cities[leg - 2], cities[leg - 1])
            : TripStringsBar.cityChange;
      case TripWizardStepKind.places:
      case TripWizardStepKind.taxi:
      case TripWizardStepKind.stay:
        final day = next.day ?? _dayOf(t, key.legIndex, key.dayInLeg) ?? key.dayInLeg ?? 1;
        return switch (key.kind) {
          TripWizardStepKind.places => TripStringsBar.places(day),
          TripWizardStepKind.taxi => TripStringsBar.taxi(day),
          _ => TripStringsBar.stay(day),
        };
    }
  }

  static int? _dayOf(TripSummaryModel t, int? legIndex, int? dayInLeg) {
    if (legIndex == null || dayInLeg == null) return null;
    for (final l in t.legs) {
      if (l.index == legIndex && l.startDay > 0) return l.startDay + dayInLeg - 1;
    }
    return legIndex == 1 ? dayInLeg : null;
  }

  static Map<String, dynamic> continueArgs(TripSummaryModel t) {
    final key = t.progress.next?.key;
    return {'tripId': t.id, if (key != null && key.isNotEmpty) 'step': key};
  }

  static String actionLabel(TripSummaryModel t, {bool past = false}) {
    if (past) return TripStringsBar.summary;
    if (isReady(t)) return TripStringsBar.readySummary;
    final next = nextTitle(t);
    if (next == null) return TripStringsBar.continueAction;
    return t.progress.decided == 0 ? TripStringsBar.start(next) : TripStringsBar.continueTo(next);
  }

  static String datesLine(TripSummaryModel t, DateTime today) {
    final s = t.startDate;
    if (s == null) return TripStringsBar.draftNoDates;
    final end = endOf(t) ?? s;
    final d = TripClock.daysBetween(today, s);
    final String lead;
    if (d > 1) {
      lead = TripStringsBar.startsIn(d);
    } else if (d == 1) {
      lead = TripStringsBar.startsTomorrow;
    } else if (d == 0) {
      lead = TripStringsBar.startsToday;
    } else {
      final day = 1 - d;
      final count = TripClock.daysBetween(s, end) + 1;
      lead = day <= count
          ? TripStringsBar.dayOf(day, count)
          : (day == count + 1 ? TripStringsBar.checkOutToday : TripStringsBar.ended);
    }
    return TripStringsBar.withDates(lead, s, end);
  }
}
