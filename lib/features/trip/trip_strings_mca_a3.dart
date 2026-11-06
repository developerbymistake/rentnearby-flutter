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
  static String travelToLine(String city, int day, DateTime? date) =>
      date == null ? 'Travel to $city · Day $day' : 'Travel to $city · Day $day · ${TripFormat.shortDate(date)}';
  static String fromTo(String from, String to) => '$from → $to';
  static const String notPlannedYet = 'Not planned yet';
  static const String arrangeMyself = "I'll arrange it myself";
  static const String ownTravel = 'Own travel';
  static const String ownTag = 'Own';
  static const String yourOwnTravel = 'Your own travel';
  static String ownTravelLine(String? how, String? leavesAt) {
    final parts = [ownTravel, ?how, if (leavesAt != null) TripFormat.time12(leavesAt)];
    return parts.join(' · ');
  }

  static const String how = 'How';
  static const String car = 'Car';
  static const String bus = 'Bus';
  static const String train = 'Train';
  static const String other = 'Other';
  static const String nameOrNumber = 'Name or number (optional)';
  static const String leavesAt = 'Leaves at';
  static const String pickTime = 'Pick a time';
  static const String phoneOptional = 'Phone (optional)';
  static const String phoneInvalid = 'Enter a 10-digit number';
  static const String roadTime = 'Road time';
  static const String halfDay = 'Half day · 4 h';
  static const String wholeDay = 'Whole day · 7.5 h';
  static const String noteOptional = 'Note (optional)';
  static const String saveTravel = 'Save travel';
  static const String removeTravel = 'Remove travel';
  static const String edit = 'Edit';
  static const String call = 'Call';
  static String roadTimeHelper(int day) => 'Road time keeps room on Day $day, so the planner fits fewer places.';

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
  static const String cancel = 'Cancel';
  static const String bookingsBlock = 'Bookings on these days · cancel them first';
  static const String runningBlock = "Running · can't change this city";
  static String cancelBookingsFirst(String city) => 'Cancel the bookings in $city first';
  static const String readOnlyBlock = 'This trip is read only';
  static const String fewerDays = 'Fewer days · places move to the last day';
  static const String changeDaysTitle = 'Change days';
  static String daysLeftNote(int max) => 'Up to ${days(max)} for this city';

  static String stayIn(String city) => 'Stay in $city';
  static String taxiIn(String city) => 'Taxi in $city';
  static const String noPlacesYet = 'No places yet · stay and taxi only';
  static String allNightsIn(String city, int n) => 'All nights in $city · ${nights(n)}';
  static String allDaysIn(String city) => 'All days in $city';
  static const String differentCity = "Different city · add it from that city's places";
  static String nightLine(int n, DateTime? date, String people) =>
      [ 'Night $n', if (date != null) TripFormat.shortDate(date), if (people.isNotEmpty) people].join(' · ');
  static String dayLine(int n, DateTime? date, String people) =>
      ['Day $n', if (date != null) TripFormat.shortDate(date), if (people.isNotEmpty) people].join(' · ');
}
