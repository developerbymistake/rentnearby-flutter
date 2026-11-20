import '../shared/buddy_format.dart';
import 'models/viewer_models.dart';
import 'viewer_strings.dart';

abstract final class ViewerRules {
  static DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);

  static String footLine({DateTime? start, DateTime? end, required int dayCount, required DateTime today}) {
    if (start == null) return ViewerStrings.datesNotSet;
    final t = _d(today);
    final s = _d(start);
    final e = end == null ? s.add(Duration(days: dayCount < 1 ? 0 : dayCount - 1)) : _d(end);
    if (t.isBefore(s)) return ViewerStrings.startsOn(BuddyFormat.dayMonth(s));
    if (t.isAfter(e)) return ViewerStrings.endedOn(BuddyFormat.dayMonth(e));
    return ViewerStrings.dayOf(t.difference(s).inDays + 1, dayCount);
  }

  static bool ended(DateTime? end, DateTime today) => end != null && _d(end).isBefore(_d(today));

  static String duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m m';
    if (m == 0) return '$h h';
    return '$h h $m m';
  }

  static String road(int minutes) => '$minutes min';

  static DateTime? dateOfDay(ViewerTrip t, int day) {
    for (final d in t.days) {
      if (d.day == day && d.date != null) return d.date;
    }
    final s = t.startDate;
    return s == null ? null : _d(s).add(Duration(days: day - 1));
  }

  static String legDates(ViewerTrip t, ViewerLeg leg) {
    final a = dateOfDay(t, leg.firstDay);
    final b = dateOfDay(t, leg.lastDay);
    if (a == null || b == null) return '';
    if (leg.firstDay == leg.lastDay) return BuddyFormat.dayMonth(a);
    if (a.month == b.month) return '${a.day}-${b.day} ${BuddyFormat.month(b)}';
    return '${BuddyFormat.dayMonth(a)}-${BuddyFormat.dayMonth(b)}';
  }

  static String taxiWhen(ViewerTaxi taxi) {
    final d = taxi.pickupDate;
    final time = BuddyFormat.time12(taxi.pickupTime);
    if (d == null) return time;
    return time.isEmpty ? BuddyFormat.dayMonth(d) : '${BuddyFormat.dayMonth(d)}, $time';
  }

  static String moneyLine(int myNet, String? owesToName) {
    if (myNet < 0) return ViewerStrings.youOwe(owesToName ?? '', -myNet);
    if (myNet > 0) return ViewerStrings.youGetBack(myNet);
    return '';
  }
}
