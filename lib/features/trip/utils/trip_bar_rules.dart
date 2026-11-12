import '../models/trip_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_strings_bar.dart';
import '../trip_strings_v2_plan.dart';
import 'trip_clock.dart';

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
  static int needCount(TripSummaryModel t) {
    final p = t.progress;
    final n = p.rows.where((r) => r.needsYou).length;
    return n > 0 ? n : (p.needsYou ? 1 : 0);
  }

  static bool isReady(TripSummaryModel t) {
    final p = t.progress;
    return p.total > 0 && p.done >= p.total;
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
    if (before != null && needCount(t) > before) return false;
    final s = t.startDate;
    if (s != null) {
      final hiddenDay = TripClock.today(hide.hiddenAt.toUtc());
      if (TripClock.daysBetween(today, s) <= 1 && TripClock.daysBetween(hiddenDay, s) > 1) return false;
    }
    return true;
  }

  static String? nextTitle(TripSummaryModel t) {
    final p = t.progress;
    final key = TripEasyRowKey.parse(p.guideStep) ?? TripEasyRowKey.parse(p.next?.key);
    if (key == null) return null;
    final cities = t.legCities;
    final leg = key.legIndex ?? 0;
    switch (key.kind) {
      case TripEasyRowKind.gettingThere:
        return TripStringsV2Plan.rowGettingThere;
      case TripEasyRowKind.comingBack:
        return TripStringsV2Plan.rowComingBack;
      case TripEasyRowKind.taxi:
        return TripStringsV2Plan.rowTaxi;
      case TripEasyRowKind.between:
        return leg >= 2 && leg <= cities.length
            ? TripStringsBar.move(cities[leg - 2], cities[leg - 1])
            : TripStringsV2Plan.rowCityChange;
      case TripEasyRowKind.stay:
        return leg >= 1 && leg <= cities.length ? TripStringsV2Plan.rowStay(cities[leg - 1]) : TripStringsV2Plan.rowStay(t.cityName);
    }
  }

  // Continue opens the trip at its saved guide step; row and step go only with push deep links.
  static Map<String, dynamic> continueArgs(TripSummaryModel t) => {'tripId': t.id};

  static String actionLabel(TripSummaryModel t, {bool past = false}) {
    if (past || isReady(t)) return TripStringsV2Plan.myTripsSummary;
    return TripStringsV2Plan.myTripsContinue;
  }

  static String datesLine(TripSummaryModel t, DateTime today) {
    final s = t.startDate;
    if (s == null) return TripStringsV2Plan.myTripsDaysNoDates(t.dayCount);
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
