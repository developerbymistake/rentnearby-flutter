import '../../owner_core/strings/owner_shared_strings.dart';

abstract final class StayFormat {
  static String clock(DateTime t) {
    final l = t.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    return '$h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'am' : 'pm'}';
  }

  static String day(DateTime d) => OwnerSharedStrings.dayMonth(d);

  static String range(DateTime from, DateTime? to) {
    if (to == null || (to.year == from.year && to.month == from.month && to.day == from.day)) return day(from);
    if (to.year == from.year && to.month == from.month) return '${from.day} – ${day(to)}';
    return '${day(from)} – ${day(to)}';
  }

  static String rangeTo(DateTime from, DateTime? to) {
    if (to == null || (to.year == from.year && to.month == from.month && to.day == from.day)) return day(from);
    if (to.year == from.year && to.month == from.month) return '${from.day} to ${day(to)}';
    return '${day(from)} to ${day(to)}';
  }
}
