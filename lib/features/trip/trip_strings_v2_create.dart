import 'trip_constants.dart';

class TripStringsV2Create {
  static const String daysTitle = 'Your trip';
  static String daysSubtitle(List<String> names) =>
      '${names.join(' + ')} · ${names.length} ${names.length == 1 ? 'city' : 'cities'}';
  static String daysCount(int d) => '$d ${d == 1 ? 'day' : 'days'}';
  static String bestFitPill(int days) => 'Best fit: ${daysCount(days)}';
  static String suggested(int days) => 'Suggested ${daysCount(days)}';
  static const String noDatesNote = 'No dates yet. We ask only if you want help with stay, taxi or ways.';
  static const String citiesHint = 'Pick one city or more. We plan them as one trip.';
  static const String searchCity = 'Search a city';
  static const String popularCities = 'Popular cities';
  static String cityMeta(int n) => '$n ${n == 1 ? 'place' : 'places'} · stays and taxis';
  static const String choosePlaces = 'Choose places';
  static String minDaysNote(int d) => 'At least ${daysCount(d)} for ${d == 1 ? 'this city' : 'these cities'}';
  static const String maxDaysNote = 'Up to ${TripConstants.maxDaysCap} days';
  static const String lessDaysBlocked = 'Remove places first to use fewer days';

  static String spotsHeader(int i, int n, int d) => 'Places to visit · city $i of $n · ${daysCount(d)}';
  static String spotsHeaderOne(int d) => 'Places to visit · ${daysCount(d)}';
  static String barCities(List<(String, int)> parts) => parts.map((e) => '${e.$1} ${e.$2}').join(' · ');
  static String barTotal(int total) => ' · total $total places';
  static String doneCity(String name, int n) => '$name · $n';
  static String next(String city) => 'Next: $city';
  static const String makeMyPlan = 'Make my plan';
  static const String limitReached = 'Place limit reached. Remove one to add another.';
  static const String maxDaysReached = 'This is the longest trip. Remove a place to add another.';
  static const String dayFull = 'This day has ${TripConstants.maxSpotsPerDay} places';

  static String pickHeading(int day, int n) => 'Add a place to Day $day · $n of ${TripConstants.maxSpotsPerDay} places';
  static const String dayFullMove = 'This day has ${TripConstants.maxSpotsPerDay} places. Move one to another day or add a day.';
  static const String legFull = 'No room left in this city. Add a day on the plan for more places.';
  static String placesLine(int n) => '$n ${n == 1 ? 'place' : 'places'} to visit';
  static const String pickOnePlace = 'Pick at least one place';
}
