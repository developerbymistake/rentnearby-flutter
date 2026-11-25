import '../../../utils/money_format.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../strings/stay_work_strings.dart';

abstract final class StayWorkFormat {
  static DateTime Function() now = DateTime.now;

  static String _mon(DateTime d) => OwnerSharedStrings.monthsShort[d.month - 1];

  static String dayMonth(DateTime d) => '${d.day} ${_mon(d)}';

  static String range(DateTime a, DateTime b) {
    if (a.year == b.year && a.month == b.month) return '${a.day} – ${b.day} ${_mon(b)}';
    return '${dayMonth(a)} – ${dayMonth(b)}';
  }

  static String dates(TripEnquiryModel e) {
    final a = e.checkIn;
    final b = e.checkOut;
    return a != null && b != null ? range(a, b) : e.datesLabel;
  }

  static String inr(int v) => Money.exact(v);

  static String clock(DateTime t) {
    final l = t.toLocal();
    final h12 = l.hour % 12 == 0 ? 12 : l.hour % 12;
    return '$h12:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'am' : 'pm'}';
  }

  /// "2 h" / "40 min"; null when the time is gone or unknown.
  static String? left(DateTime? until, DateTime now) {
    if (until == null) return null;
    final d = until.difference(now);
    if (d.inMinutes <= 0) return null;
    if (d.inMinutes < 60) return StayWorkStrings.minutes(d.inMinutes);
    return StayWorkStrings.hours(d.inHours);
  }

  static bool short(DateTime? until, DateTime now) => until != null && until.difference(now).inMinutes <= 120;

  static int guests(TripEnquiryModel e) {
    final c = e.context;
    final n = (c.adults ?? 0) + (c.kids ?? 0);
    if (n > 0) return n;
    final o = e.acceptedOffer ?? e.openOffer;
    return o?.guests ?? 0;
  }

  static int rooms(TripEnquiryModel e) {
    final r = e.context.rooms;
    if (r != null && r > 0) return r;
    final o = e.acceptedOffer ?? e.openOffer;
    final n = o?.rooms ?? 0;
    return n > 0 ? n : 1;
  }

  static String datesGuests(TripEnquiryModel e) {
    final g = guests(e);
    final d = dates(e);
    return g > 0 ? '$d · ${StayWorkStrings.guests(g)}' : d;
  }

  static bool startsWithin72h(TripEnquiryModel e, DateTime now) {
    final s = e.tripStartDate ?? e.checkIn;
    if (s == null) return false;
    return s.difference(now).inHours < 72;
  }

  static int? daysUntil(DateTime? start, DateTime now) {
    if (start == null) return null;
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(start.year, start.month, start.day);
    return b.difference(a).inDays;
  }

  static String? waiting(TripEnquiryModel e, DateTime now) {
    final at = e.createdAt;
    final mins = at == null ? null : now.difference(at).inMinutes;
    if (mins != null && mins < 60) return StayWorkStrings.waitingMin(mins < 1 ? 1 : mins);
    final h = e.waitingHours ?? (mins == null ? null : mins ~/ 60);
    return h == null ? null : StayWorkStrings.waiting(h);
  }
}
