abstract final class OwnerDates {
  static DateTime? day(Object? v) {
    if (v is! String || v.length < 10) return null;
    final y = int.tryParse(v.substring(0, 4));
    final m = int.tryParse(v.substring(5, 7));
    final d = int.tryParse(v.substring(8, 10));
    if (y == null || m == null || d == null || v[4] != '-' || v[7] != '-') return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final out = DateTime(y, m, d);
    return out.month == m ? out : null;
  }

  static ({int hour, int minute})? time(Object? v) {
    if (v is! String || v.length < 5 || v[2] != ':') return null;
    final h = int.tryParse(v.substring(0, 2));
    final m = int.tryParse(v.substring(3, 5));
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return (hour: h, minute: m);
  }

  static DateTime? month(Object? v) {
    if (v is! String || v.length < 7 || v[4] != '-') return null;
    final y = int.tryParse(v.substring(0, 4));
    final m = int.tryParse(v.substring(5, 7));
    if (y == null || m == null || m < 1 || m > 12) return null;
    return DateTime(y, m);
  }

  static DateTime only(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String dayText(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  static String? dayTextOrNull(DateTime? d) => d == null ? null : dayText(d);

  static String monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}';

  static String timeText(int hour, int minute) => '${_two(hour)}:${_two(minute)}';

  static DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  static DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month);

  static DateTime lastOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

  static DateTime addMonths(DateTime d, int months) => DateTime(d.year, d.month + months);

  static int daysBetween(DateTime from, DateTime to) => only(to).difference(only(from)).inHours ~/ 24 + (only(to).difference(only(from)).inHours % 24 > 12 ? 1 : 0);

  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static bool within(DateTime d, DateTime from, DateTime to) => !only(d).isBefore(only(from)) && !only(d).isAfter(only(to));
}
