import 'package:flutter/material.dart';
import '../trip_strings.dart';

class TripFormat {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  static String km(double value) => '${number(value)} km';

  static String visit(int minutes) {
    if (minutes < 60) return '$minutes min';
    return '${_trim(minutes / 60)} h';
  }

  static String number(double value) => value < 10 ? _trim(value) : value.round().toString();

  static String _trim(double value) {
    final s = value.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  static String shortDate(DateTime d) =>
      '${_days[d.weekday - 1]} ${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}';

  static String dateRange(DateTime start, DateTime end) {
    final same = start.year == end.year && start.month == end.month && start.day == end.day;
    return same ? shortDate(start) : '${shortDate(start)} - ${shortDate(end)}';
  }

  static String dayMonth(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}';

  static String dayMonthRange(DateTime a, DateTime b) {
    if (a.year == b.year && a.month == b.month) {
      return a.day == b.day ? dayMonth(a) : '${a.day.toString().padLeft(2, '0')}-${dayMonth(b)}';
    }
    return '${dayMonth(a)} - ${dayMonth(b)}';
  }

  static String time12(String hhmm) {
    final m = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(hhmm);
    if (m == null) return hhmm;
    final h = int.parse(m.group(1)!);
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.group(2)} ${h < 12 ? 'am' : 'pm'}';
  }

  static String time12Of(DateTime d) {
    final l = d.toLocal();
    final h12 = l.hour % 12 == 0 ? 12 : l.hour % 12;
    return '$h12:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'am' : 'pm'}';
  }

  static String dayTime(DateTime d, {DateTime? now}) {
    final l = d.toLocal();
    final ref = (now ?? DateTime.now()).toLocal();
    final today = l.year == ref.year && l.month == ref.month && l.day == ref.day;
    return today ? '${TripStrings.today}, ${time12Of(l)}' : '${shortDate(l)}, ${time12Of(l)}';
  }

  static String monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  static String hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
