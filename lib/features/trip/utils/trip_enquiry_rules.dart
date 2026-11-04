import '../trip_constants.dart';
import '../trip_strings.dart';

class TripPreviewDay {
  final int day;
  final List<String> spots;

  const TripPreviewDay({required this.day, this.spots = const []});
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

  static bool nightsOverlap(DateTime aIn, DateTime aOut, DateTime bIn, DateTime bOut) =>
      aIn.isBefore(bOut) && bIn.isBefore(aOut);

  static int nightsFor(int dayCount, int day, bool allNights) {
    if (!allNights) return 1;
    final n = dayCount - day;
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
}
