import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_strings.dart';
import '../../trip/trip_strings_mcb_a3.dart';
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

  static List<DateTime> _taxiDates(TripEnquiryModel e) {
    var list = e.taxiDates;
    if (list.isEmpty) list = [for (final d in e.context.days) if (d.date != null) d.date!];
    final out = {for (final d in list) DateTime(d.year, d.month, d.day)}.toList()..sort();
    return out;
  }

  static String dates(TripEnquiryModel e) {
    if (e.isTaxi) {
      final list = _taxiDates(e);
      if (list.isNotEmpty) {
        final runs = <List<DateTime>>[];
        for (final d in list) {
          final last = runs.isEmpty ? null : runs.last.last;
          if (last != null && DateTime(last.year, last.month, last.day + 1) == d) {
            runs.last.add(d);
          } else {
            runs.add([d]);
          }
        }
        if (runs.length == 1) return TripFormat.dateRange(list.first, list.last);
        return runs.map((r) => TripFormat.dayMonthRange(r.first, r.last)).join(', ');
      }
    }
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

  static final RegExp _journeyText =
      RegExp(r'^(?:Car (\d) of (\d): )?(.+?) to (.+?), (\d{2} [A-Za-z]{3}),');

  static String? journeyLineOfText(String text, {required bool segment, int? car}) {
    final m = _journeyText.firstMatch(text.trim());
    if (m == null || (!segment && m.group(1) == null)) return null;
    final i = int.tryParse(m.group(1) ?? '') ?? car ?? 1;
    final n = int.tryParse(m.group(2) ?? '') ?? 1;
    return TripStringsMcbA3.journeyLine(
        TripStringsMcbA3.journeyCarOf(i, n), m.group(3)!.trim(), m.group(4)!.trim(), m.group(5)!);
  }

  static final RegExp _journeyTail =
      RegExp(r'^Car \d of \d: .+? to .+?, \d{2} [A-Za-z]{3},\s*(.*)$', dotAll: true);

  static String? journeyExtra(TripEnquiryModel e) {
    final m = _journeyTail.firstMatch(e.context.text.trim());
    final t = m?.group(1)?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  static String? journeyLine(TripEnquiryModel e) =>
      journeyLineOfText(e.context.text, segment: e.isSegment, car: e.context.journeyLegIndex);

  static String summary(TripEnquiryModel e) => [
        TripStrings.tripMapSubtitle(e.context.city),
        dates(e),
        if (e.isTaxi && dayCount(e) > 1) TripStrings.nDays(dayCount(e)),
        people(e) ?? '',
        pickup(e),
      ].where((s) => s.isNotEmpty).join(' · ');

  static String spots(TripEnquiryModel e) =>
      [for (final d in e.context.days) ...d.spots].where((s) => s.isNotEmpty).join(' · ');
}
