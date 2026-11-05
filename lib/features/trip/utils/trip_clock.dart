import 'trip_enquiry_rules.dart';

enum TripCheckInWhen { past, tonight, tomorrow, later }

// The trip's calendar runs on the IST day, as on the server; date maths is done on date-only UTC values.
class TripClock {
  static DateTime today([DateTime? nowUtc]) => TripEnquiryRules.todayIst(nowUtc ?? DateTime.now().toUtc());

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  // 1-based day of a span that starts on `start` and has `count` days, or null outside it.
  static int? dayIndex(DateTime start, int count, DateTime today) {
    if (count < 1) return null;
    final n = daysBetween(start, today) + 1;
    return n >= 1 && n <= count ? n : null;
  }

  // Night k of `nights` for a stay checking in on `checkIn`, clamped to 1..nights.
  static int nightOf(DateTime checkIn, int nights, DateTime today) {
    final total = nights < 1 ? 1 : nights;
    return (daysBetween(checkIn, today) + 1).clamp(1, total).toInt();
  }

  static ({TripCheckInWhen when, int days}) checkInRelative(DateTime checkIn, DateTime nowUtc) {
    final d = daysBetween(today(nowUtc), checkIn);
    final when = d < 0
        ? TripCheckInWhen.past
        : d == 0
            ? TripCheckInWhen.tonight
            : d == 1
                ? TripCheckInWhen.tomorrow
                : TripCheckInWhen.later;
    return (when: when, days: d);
  }
}
