class TaxiInvalidDateError implements Exception {
  const TaxiInvalidDateError();
}

abstract final class TaxiJourneyDate {
  static const int daysAhead = 90;
  static const Duration _ist = Duration(hours: 5, minutes: 30);
  static final RegExp _api = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static DateTime today([DateTime? now]) {
    final ist = (now ?? DateTime.now()).toUtc().add(_ist);
    return DateTime(ist.year, ist.month, ist.day);
  }

  static Duration untilNextDay([DateTime? now]) {
    final utc = (now ?? DateTime.now()).toUtc();
    final ist = utc.add(_ist);
    final next = DateTime.utc(ist.year, ist.month, ist.day + 1).subtract(_ist);
    return next.difference(utc);
  }

  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  static DateTime last(DateTime today) => addDays(today, daysAhead);

  static bool same(DateTime? a, DateTime? b) => a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime clamp(DateTime d, DateTime today) {
    final day = dayOf(d);
    if (day.isBefore(today)) return today;
    final end = last(today);
    return day.isAfter(end) ? end : day;
  }

  static bool canPrev(DateTime d, DateTime today) => dayOf(d).isAfter(today);

  static bool canNext(DateTime d, DateTime today) => dayOf(d).isBefore(last(today));

  static String apiText(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? parse(Object? raw) {
    if (raw is! String) return null;
    final m = _api.firstMatch(raw.trim());
    if (m == null) return null;
    final y = int.tryParse(m.group(1) ?? '');
    final mo = int.tryParse(m.group(2) ?? '');
    final d = int.tryParse(m.group(3) ?? '');
    if (y == null || mo == null || d == null) return null;
    final v = DateTime(y, mo, d);
    return v.year == y && v.month == mo && v.day == d ? v : null;
  }
}
