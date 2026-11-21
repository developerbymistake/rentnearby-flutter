import '../json/owner_dates.dart';
import 'models/calendar_models.dart';

enum BarPart { none, single, start, middle, end }

class DayCell {
  const DayCell({
    required this.date,
    required this.inMonth,
    this.isToday = false,
    this.isPast = false,
    this.outsideWindow = false,
    this.appCount = 0,
    this.ownCount = 0,
    this.cancelledCount = 0,
    this.blocked = false,
    this.specialPrice = false,
    this.festivalName,
    this.bar = BarPart.none,
    this.entryIds = const [],
  });

  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final bool isPast;
  final bool outsideWindow;
  final int appCount;
  final int ownCount;
  final int cancelledCount;
  final bool blocked;
  final bool specialPrice;
  final String? festivalName;
  final BarPart bar;
  final List<String> entryIds;

  bool get hasEntries => appCount + ownCount + cancelledCount > 0;
  bool get onlyCancelled => cancelledCount > 0 && appCount + ownCount == 0;
  bool get tappable => inMonth && !isPast && !outsideWindow;
}

abstract final class MonthGridData {
  static const int cells = 42;

  static List<DateTime> entryDays(CalendarEntry e, {required bool stayNights}) {
    final from = e.dateFrom;
    if (from == null) return const [];
    var to = e.dateTo ?? from;
    if (stayNights && to.isAfter(from)) to = OwnerDates.addDays(to, -1);
    if (to.isBefore(from)) to = from;
    final out = <DateTime>[];
    var d = from;
    while (!d.isAfter(to) && out.length < 400) {
      out.add(d);
      d = OwnerDates.addDays(d, 1);
    }
    return out;
  }

  static List<DayCell> build({
    required DateTime month,
    required List<CalendarEntry> entries,
    List<CalendarBlock> blocks = const [],
    List<SpecialPriceBand> bands = const [],
    List<FestivalRow> festivals = const [],
    required DateTime today,
    CalendarWindow window = const CalendarWindow(),
    bool stayNights = true,
    bool mondayFirst = true,
  }) {
    final first = OwnerDates.firstOfMonth(month);
    final lead = mondayFirst ? (first.weekday - DateTime.monday) % 7 : first.weekday % 7;
    final start = OwnerDates.addDays(first, -lead);
    final t = OwnerDates.only(today);

    final app = <DateTime, int>{};
    final own = <DateTime, int>{};
    final cancelled = <DateTime, int>{};
    final ids = <DateTime, List<String>>{};
    final barDays = <DateTime>{};
    for (final e in entries) {
      final days = entryDays(e, stayNights: stayNights);
      for (final d in days) {
        if (e.cancelled) {
          cancelled[d] = (cancelled[d] ?? 0) + 1;
        } else if (e.isAuto) {
          app[d] = (app[d] ?? 0) + 1;
        } else {
          own[d] = (own[d] ?? 0) + 1;
        }
        (ids[d] ??= <String>[]).add(e.id);
        if (!e.cancelled && days.length > 1) barDays.add(d);
      }
    }

    bool inAny<T>(DateTime d, List<T> rows, DateTime? Function(T) from, DateTime? Function(T) to) {
      for (final r in rows) {
        final f = from(r);
        final l = to(r);
        if (f != null && l != null && OwnerDates.within(d, f, l)) return true;
      }
      return false;
    }

    String? festivalOn(DateTime d) {
      for (final f in festivals) {
        final a = f.dateFrom;
        final b = f.dateTo;
        if (a != null && b != null && OwnerDates.within(d, a, b)) return f.name;
      }
      return null;
    }

    final monthFrom = window.monthFrom == null ? null : OwnerDates.firstOfMonth(window.monthFrom!);
    final monthTo = window.monthTo == null ? null : OwnerDates.lastOfMonth(window.monthTo!);
    final activeBands = bands.where((b) => b.active).toList();

    final out = <DayCell>[];
    for (var i = 0; i < cells; i++) {
      final d = OwnerDates.addDays(start, i);
      final inMonth = d.month == first.month && d.year == first.year;
      final prev = OwnerDates.addDays(d, -1);
      final next = OwnerDates.addDays(d, 1);
      var bar = BarPart.none;
      if (barDays.contains(d)) {
        final p = barDays.contains(prev);
        final n = barDays.contains(next);
        bar = p && n
            ? BarPart.middle
            : p
                ? BarPart.end
                : n
                    ? BarPart.start
                    : BarPart.single;
      }
      final outside = (monthFrom != null && d.isBefore(monthFrom)) || (monthTo != null && d.isAfter(monthTo));
      out.add(DayCell(
        date: d,
        inMonth: inMonth,
        isToday: OwnerDates.sameDay(d, t),
        isPast: d.isBefore(t),
        outsideWindow: outside,
        appCount: app[d] ?? 0,
        ownCount: own[d] ?? 0,
        cancelledCount: cancelled[d] ?? 0,
        blocked: inAny(d, blocks, (b) => b.dateFrom, (b) => b.dateTo),
        specialPrice: inAny(d, activeBands, (b) => b.dateFrom, (b) => b.dateTo),
        festivalName: festivalOn(d),
        bar: bar,
        entryIds: List.unmodifiable(ids[d] ?? const <String>[]),
      ));
    }
    return List.unmodifiable(out);
  }

  static List<CalendarEntry> entriesOn(DateTime day, List<CalendarEntry> entries, {required bool stayNights, bool includeCheckout = true}) {
    final d = OwnerDates.only(day);
    final out = <CalendarEntry>[];
    for (final e in entries) {
      final from = e.dateFrom;
      if (from == null) continue;
      final to = e.dateTo ?? from;
      final last = stayNights && !includeCheckout && to.isAfter(from) ? OwnerDates.addDays(to, -1) : to;
      if (OwnerDates.within(d, from, last)) out.add(e);
    }
    out.sort(dayOrder);
    return out;
  }

  static int dayOrder(CalendarEntry a, CalendarEntry b) {
    if (a.isAuto != b.isAuto) return a.isAuto ? -1 : 1;
    final ta = a.timeOfDay ?? '';
    final tb = b.timeOfDay ?? '';
    final c = ta.compareTo(tb);
    if (c != 0) return c;
    final fa = a.dateFrom;
    final fb = b.dateFrom;
    if (fa != null && fb != null && fa != fb) return fa.compareTo(fb);
    return a.id.compareTo(b.id);
  }

  static Map<String, List<CalendarEntry>> groupByMonth(List<CalendarEntry> entries) {
    final out = <String, List<CalendarEntry>>{};
    for (final e in entries) {
      final d = e.dateFrom;
      if (d == null) continue;
      (out[OwnerDates.monthKey(d)] ??= <CalendarEntry>[]).add(e);
    }
    return out;
  }
}
