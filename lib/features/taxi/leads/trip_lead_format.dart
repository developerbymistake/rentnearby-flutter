import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_strings.dart';
import '../../trip/utils/trip_format.dart';

class TripLeadFormat {
  static String guest(TripEnquiryModel e) {
    final name = (e.traveller.name ?? e.context.travellerName ?? '').trim();
    return name.isEmpty ? TripStrings.guests : name;
  }

  static String driver(TripEnquiryModel e) {
    final name = (e.owner.name ?? '').trim();
    return name.isEmpty ? e.listingName : name;
  }

  static String dates(TripEnquiryModel e) {
    final a = e.checkIn;
    final b = e.checkOut;
    if (a == null) return '';
    final last = b == null ? a : DateTime(b.year, b.month, b.day - 1);
    return TripFormat.dateRange(a, last.isBefore(a) ? a : last);
  }

  static int dayCount(TripEnquiryModel e) {
    final n = e.days.isNotEmpty ? e.days.length : e.context.days.length;
    return n < 1 ? 1 : n;
  }

  static int? listedTotal(TripEnquiryModel e) {
    final t = e.taxi;
    if (t == null) return null;
    final total = t.listedTotal;
    if (total != null) return total;
    final rate = t.listedRate;
    return rate == null ? null : rate * dayCount(e);
  }

  static String? people(TripEnquiryModel e) {
    final a = e.context.adults;
    return a == null ? null : TripStrings.peopleCount(a + (e.context.kids ?? 0));
  }

  static String pickup(TripEnquiryModel e) {
    final time = e.taxi?.pickupTime ?? e.context.pickupTime;
    final place = (e.taxi?.pickupPlace ?? e.context.pickupPlace)?.trim() ?? '';
    if (time == null && place.isEmpty) return '';
    if (time != null && place.isNotEmpty) return TripStrings.pickupLine(TripFormat.time12(time), place);
    return '${TripStrings.pickup} ${time != null ? TripFormat.time12(time) : place}';
  }

  static String summary(TripEnquiryModel e) => [
        TripStrings.tripMapSubtitle(e.context.city),
        dates(e),
        people(e) ?? '',
        pickup(e),
      ].where((s) => s.isNotEmpty).join(' · ');

  static String spots(TripEnquiryModel e) =>
      [for (final d in e.context.days) ...d.spots].where((s) => s.isNotEmpty).join(' · ');
}
