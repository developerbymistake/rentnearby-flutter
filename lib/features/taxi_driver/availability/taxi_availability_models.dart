import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/json/owner_json.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';

enum TaxiAvailDay { past, booked, off, free }

abstract final class TaxiReasonText {
  static const int max = 200;

  static int length(String text) => text.runes.length;

  static String cut(String text) => length(text) <= max ? text : String.fromCharCodes(text.runes.take(max));

  static String? clean(String? text) {
    if (text == null) return null;
    final t = cut(text.trim()).trim();
    return t.isEmpty ? null : t;
  }
}

class TaxiDayOff {
  const TaxiDayOff({required this.date, this.reason});

  final DateTime date;
  final String? reason;

  String get key => OwnerDates.dayText(date);

  static TaxiDayOff? maybe(Map<String, dynamic> j) {
    final d = OwnerDates.day(j['date']);
    if (d == null) return null;
    return TaxiDayOff(date: d, reason: TaxiReasonText.clean(OwnerJson.strOrNull(j['reason'])));
  }

  Map<String, dynamic> toJson() => {'date': key, 'reason': reason};
}

class TaxiAvailabilityCounts {
  const TaxiAvailabilityCounts({this.month, this.bookings, this.daysOff, this.raw = const {}});

  final DateTime? month;
  final int? bookings;
  final int? daysOff;
  final Map<String, dynamic> raw;

  static TaxiAvailabilityCounts? maybe(Object? v) {
    final j = OwnerJson.mapOrNull(v);
    if (j == null) return null;
    return TaxiAvailabilityCounts(
      month: OwnerDates.month(j['month']),
      bookings: OwnerJson.intOrNull(j['bookings']),
      daysOff: OwnerJson.intOrNull(j['daysOff']),
      raw: j,
    );
  }
}

class TaxiAvailability {
  const TaxiAvailability({
    this.today,
    this.window = const CalendarWindow(),
    this.monthsAhead = 0,
    this.switchOn,
    this.daysOff = const {},
    this.bookedDays = const {},
    this.counts,
    this.raw = const {},
  });

  final DateTime? today;
  final CalendarWindow window;
  final int monthsAhead;
  final bool? switchOn;
  final Map<String, TaxiDayOff> daysOff;
  final Set<String> bookedDays;
  final TaxiAvailabilityCounts? counts;
  final Map<String, dynamic> raw;

  Set<String> get offKeys => daysOff.keys.toSet();

  static String keyOf(DateTime d) => OwnerDates.dayText(d);

  bool isBooked(DateTime d) => bookedDays.contains(keyOf(d));

  bool hasOff(DateTime d) => daysOff.containsKey(keyOf(d));

  factory TaxiAvailability.fromJson(Map<String, dynamic> j) {
    final today = OwnerDates.day(j['today']);
    final off = <String, TaxiDayOff>{};
    final rows = j['daysOff'];
    if (rows is List) {
      for (final r in rows) {
        final m = OwnerJson.mapOrNull(r);
        final d = m == null ? null : TaxiDayOff.maybe(m);
        if (d != null && !off.containsKey(d.key)) off[d.key] = d;
      }
    }
    final booked = <String>{};
    final days = j['bookedDays'];
    if (days is List) {
      for (final v in days) {
        final d = OwnerDates.day(v);
        if (d != null) booked.add(OwnerDates.dayText(d));
      }
    }
    final sorted = <String, TaxiDayOff>{};
    for (final k in off.keys.toList()..sort()) {
      final v = off[k];
      if (v != null) sorted[k] = v;
    }
    return TaxiAvailability(
      today: today,
      window: _window(OwnerJson.mapOrNull(j['window']), today),
      monthsAhead: OwnerJson.integer(j['monthsAhead']),
      switchOn: OwnerJson.boolOrNull(j['switchOn']),
      daysOff: Map<String, TaxiDayOff>.unmodifiable(sorted),
      bookedDays: Set.unmodifiable(booked),
      counts: TaxiAvailabilityCounts.maybe(j['counts']),
      raw: j,
    );
  }

  static CalendarWindow _window(Map<String, dynamic>? j, DateTime? today) {
    final w = j == null ? null : CalendarWindow.fromJson(j);
    if (w != null && w.monthFrom != null && w.monthTo != null) return w;
    final t = today ?? OwnerDates.only(DateTime.now());
    return CalendarWindow(
      monthFrom: OwnerDates.firstOfMonth(t),
      monthTo: OwnerDates.lastOfMonth(OwnerDates.addMonths(t, PlanGate.limit(PlanKey.monthsAhead))),
      locked: PlanGate.canUpgrade,
    );
  }
}
