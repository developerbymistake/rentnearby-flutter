import 'dart:math' as math;
import '../../../utils/search_fold.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../widgets/trip_status.dart';

class TripPreviewDay {
  final int day;
  final List<String> spots;

  const TripPreviewDay({required this.day, this.spots = const []});
}

class WrongCityInfo {
  static const int removedCityLeg = 0;
  static const int serverOnlyLeg = -1;

  final int wrong;
  final int total;
  final int firstWrongDay;
  final String dayCity;
  final int homeLegIndex;
  final int dayLegIndex;

  const WrongCityInfo({
    required this.wrong,
    required this.total,
    required this.firstWrongDay,
    required this.dayCity,
    required this.homeLegIndex,
    required this.dayLegIndex,
  });

  bool get partial => wrong < total;

  bool get cityRemoved => homeLegIndex == removedCityLeg;
}

class TripEnquiryRules {
  static const int istOffsetMinutes = 330;
  static const int maxTextLen = 80;
  static const int maxSpotsInText = 8;
  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static DateTime istMidnightUtc(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).subtract(const Duration(minutes: istOffsetMinutes));

  static DateTime todayIst(DateTime nowUtc) {
    final ist = nowUtc.toUtc().add(const Duration(minutes: istOffsetMinutes));
    return DateTime(ist.year, ist.month, ist.day);
  }

  static DateTime nightDate(DateTime start, int day) => DateTime(start.year, start.month, start.day + day - 1);

  static bool isUrgent(DateTime start, DateTime nowUtc) =>
      istMidnightUtc(start).difference(nowUtc.toUtc()) < const Duration(hours: TripConstants.urgentHours);

  static ({DateTime expiresAt, bool veryShortNotice}) enquiryExpiry(DateTime start, DateTime checkIn, DateTime nowUtc) {
    final now = nowUtc.toUtc();
    final ref = todayIst(now).isBefore(DateTime(start.year, start.month, start.day))
        ? istMidnightUtc(start)
        : istMidnightUtc(checkIn);
    final normal = now.add(const Duration(hours: TripConstants.enquiryHours));
    final limit = ref.subtract(const Duration(hours: TripConstants.replyBeforeHours));
    var expires = normal.isBefore(limit) ? normal : limit;
    final floor = now.add(const Duration(hours: TripConstants.floorHours));
    final applied = expires.isBefore(floor);
    if (applied) expires = floor;
    return (expiresAt: expires, veryShortNotice: applied);
  }

  static bool hostRefused(TripEnquiryModel e) {
    if (e.isOpen) return false;
    final s = e.display;
    final reason = e.failReason;
    return s == TripDisplayStatus.notAvailable ||
        (reason != null && reason.isNotEmpty) ||
        (s == TripDisplayStatus.cancelled && e.cancelledBy == 'owner');
  }

  static bool nightsOverlap(DateTime aIn, DateTime aOut, DateTime bIn, DateTime bOut) =>
      aIn.isBefore(bOut) && bIn.isBefore(aOut);

  static int nightsFor(int dayCount, int day, bool allNights) {
    if (!allNights) return 1;
    final n = dayCount - day + 1;
    return n < 1 ? 1 : n;
  }

  static int daysUntil(DateTime start, DateTime nowUtc) {
    final today = todayIst(nowUtc);
    final d = DateTime.utc(start.year, start.month, start.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    return d < 0 ? 0 : d;
  }

  static String clean(String? s, [int max = maxTextLen]) {
    if (s == null) return '';
    var t = s.replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), ' ');
    t = t.replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '').replaceAll(RegExp(r'www\.\S+', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length > max ? t.substring(0, max).trimRight() : t;
  }

  static String shortDay(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}';

  static String previewText({
    required String city,
    required DateTime checkIn,
    required DateTime checkOut,
    required bool allNights,
    int? adults,
    int? kids,
    int? rooms,
    List<String> needs = const [],
    List<TripPreviewDay> days = const [],
  }) {
    final nights = DateTime.utc(checkOut.year, checkOut.month, checkOut.day)
        .difference(DateTime.utc(checkIn.year, checkIn.month, checkIn.day))
        .inDays;
    final nightsPart = allNights && nights > 1 ? ' ($nights nights)' : '';
    final b = StringBuffer('Hi, trip to ${clean(city)}, ${shortDay(checkIn)} to ${shortDay(checkOut)}$nightsPart, ${_people(adults, kids)}');
    if (rooms != null) b.write(', ${rooms == 1 ? '1 room' : '$rooms rooms'}');
    b.write('.');
    final words = {for (final n in needs) ?_needWord(n)}.toList();
    if (words.isNotEmpty) b.write(' We need ${_join(words)}.');
    for (final d in days) {
      final spots = [for (final s in d.spots) clean(s)].where((s) => s.isNotEmpty).toList();
      if (spots.isEmpty) continue;
      final shown = spots.take(maxSpotsInText).join(', ');
      final extra = spots.length > maxSpotsInText ? ' +${spots.length - maxSpotsInText} more' : '';
      b.write(' Day ${d.day} spots: $shown$extra.');
    }
    b.write(' Is a room free? Please share the best price.');
    return b.toString();
  }

  static String _people(int? adults, int? kids) {
    if (adults == null) return '2 people';
    final a = adults == 1 ? '1 adult' : '$adults adults';
    final k = kids ?? 0;
    return k > 0 ? '$a, $k ${k == 1 ? 'kid' : 'kids'}' : a;
  }

  static String? _needWord(String key) => switch (key) {
        TripNeeds.noStairs => 'no stairs',
        TripNeeds.kidsSafe => 'a safe room for kids',
        TripNeeds.vegFood => 'vegetarian food',
        _ => null,
      };

  static String _join(List<String> w) {
    if (w.length == 1) return w.first;
    return '${w.sublist(0, w.length - 1).join(', ')} and ${w.last}';
  }

  static String closesInLabel(DateTime expiresAt, DateTime now) {
    final diff = expiresAt.difference(now);
    if (diff.inMinutes <= 0) return TripStrings.expired;
    if (diff.inHours >= 48) return '${diff.inDays} d';
    if (diff.inHours >= 1) return '${diff.inHours} h';
    return '${diff.inMinutes} min';
  }

  static List<DateTime> datesOf(TripEnquiryModel e) {
    if (e.isTaxi && e.days.isNotEmpty) return e.taxiDates;
    final a = e.checkIn;
    if (a == null || (e.isTaxi && e.checkOut == null)) return const [];
    final n = e.nights;
    return [for (var k = 0; k < (n < 1 ? 1 : n); k++) DateTime(a.year, a.month, a.day + k)];
  }

  static int? dayOf(DateTime start, DateTime date, int dayCount) {
    final n = DateTime.utc(date.year, date.month, date.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays + 1;
    return n >= 1 && n <= dayCount ? n : null;
  }

  static double _km(double lat1, double lon1, double lat2, double lon2) {
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 6371 * 2 * math.asin(math.min(1.0, math.sqrt(a)));
  }

  static int? homeLegIndex(TripEnquiryModel e, TripPlan plan) {
    if (plan.legs.isEmpty) return null;
    final city = SearchFold.fold(e.context.city);
    if (city.isNotEmpty) {
      for (final l in plan.legs) {
        if (SearchFold.fold(l.cityName) == city) return l.index;
      }
      return WrongCityInfo.removedCityLeg;
    }
    final lat = e.listingLatitude;
    final lon = e.listingLongitude;
    if (lat == null || lon == null) return null;
    int? best;
    var bestKm = double.infinity;
    for (final l in plan.legs) {
      if (!l.hasPoint) continue;
      final km = _km(lat, lon, l.latitude, l.longitude);
      if (km < bestKm) {
        bestKm = km;
        best = l.index;
      }
    }
    return best;
  }

  static WrongCityInfo? wrongCity(TripEnquiryModel e, TripPlan plan, TripSettings settings) {
    final start = settings.startDate;
    if (e.isSegment || start == null) return null;
    final home = homeLegIndex(e, plan);
    if (home == null || (!plan.isMultiCity && home != WrongCityInfo.removedCityLeg)) return null;
    final dates = [...datesOf(e)]..sort();
    var total = 0;
    var wrong = 0;
    int? first;
    for (final date in dates) {
      final day = dayOf(start, date, plan.days.length);
      if (day == null) continue;
      total++;
      if (plan.legIndexOf(day) == home) continue;
      wrong++;
      first ??= day;
    }
    if (wrong == 0 || first == null) return null;
    return WrongCityInfo(
      wrong: wrong,
      total: total,
      firstWrongDay: first,
      dayCity: plan.cityNameOf(first),
      homeLegIndex: home,
      dayLegIndex: plan.legIndexOf(first),
    );
  }

  static Map<String, dynamic> keepStoredNights(TripEnquiryModel? stored, Map<String, dynamic> fields) {
    final n = fields['nights'];
    if (stored == null || n is! int || n != stored.nights) return fields;
    return {
      for (final f in fields.entries)
        if (f.key != 'nights' && f.key != 'allNights') f.key: f.value,
    };
  }

  static bool isOutsideTrip(TripEnquiryModel e, TripSettings settings, int dayCount) {
    final start = settings.startDate;
    if (e.isSegment || start == null) return false;
    return datesOf(e).any((d) => dayOf(start, d, dayCount) == null);
  }
}
