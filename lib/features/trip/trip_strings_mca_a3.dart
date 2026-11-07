import 'utils/trip_format.dart';

class TripStringsMcaA3 {
  static const String addAnotherCity = 'Add another city';
  static const String upToFourCities = 'Up to 4 cities in one trip';
  static const String connectToAddCity = 'Connect to add a city';
  static const String maxCities = '4 cities · the most in one trip';
  static const String noDaysLeft = 'No days left · 14 is the most';
  static String cities(int n) => '$n cities';
  static String spots(int n) => n == 1 ? '1 spot' : '$n spots';
  static String nights(int n) => n == 1 ? '1 night' : '$n nights';
  static String dayRange(int a, int b) => a == b ? 'Day $a' : 'Days $a-$b';
  static String dayRangeWithDates(int a, int b, DateTime? from, DateTime? to) {
    final range = dayRange(a, b);
    if (from == null || to == null) return range;
    return '$range · ${dateSpan(from, to)}';
  }

  static String dateSpan(DateTime a, DateTime b) {
    if (a.year == b.year && a.month == b.month && a.day == b.day) return TripFormat.shortDate(a);
    if (a.year == b.year && a.month == b.month) {
      final first = TripFormat.shortDate(a);
      return '${first.substring(0, first.lastIndexOf(' '))} – ${TripFormat.shortDate(b)}';
    }
    return '${TripFormat.shortDate(a)} – ${TripFormat.shortDate(b)}';
  }

  static const String travelDay = 'Travel day';
  static String travelTo(String city) => 'Travel to $city';
  static String fromTo(String from, String to) => '$from → $to';
  static const String notPlannedYet = 'Not planned yet';
  static const String ownTravel = 'Own travel';

  static const String addPlaces = 'Add places';
  static const String changeDays = 'Change days';
  static String days(int n) => n == 1 ? '1 day' : '$n days';
  static const String moveUp = 'Move up';
  static const String moveDown = 'Move down';
  static const String lastCity = 'last city';
  static const String firstCity = 'first city';
  static const String removeCity = 'Remove city';
  static String removeCityQ(String city) => 'Remove $city?';
  static String removeShiftBody(int n) => 'Its ${days(n)}, spots, stay and taxi choices go.';
  static String removeKeepBody(String cities, int a, int b, String prev) =>
      'Bookings in $cities keep their dates. ${dayRange(a, b)} stay in $prev.';
  static String removeStartBody(DateTime date) => 'Your trip now starts on ${TripFormat.shortDate(date)}.';
  static const String remove = 'Remove';
  static const String keep = 'Keep';
  static const String save = 'Save';
  static const String bookingsBlock = 'Bookings on these days · cancel them first';
  static const String runningBlock = "Running · can't change this city";
  static String cancelBookingsFirst(String city) => 'Cancel the bookings in $city first';
  static const String readOnlyBlock = 'This trip is read only';
  static const String fewerDays = 'Fewer days · places move to the last day';
  static String daysLeftNote(int max) => 'Up to ${days(max)} for this city';

}
