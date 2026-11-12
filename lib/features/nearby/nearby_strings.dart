import '../trip/trip_strings_city.dart';

class NearbyStrings {
  NearbyStrings._();

  static const String featuredTitle = 'Featured near you';
  static const double nearKm = 15;

  static const String staysNear = 'Stays near you';
  static const String staysNearest = 'Nearest stays';
  static String staysNearPlace(String p) => 'Stays near $p';
  static String staysNearestToPlace(String p) => 'Nearest stays to $p';

  static const String taxisNear = 'Taxis near you';
  static const String taxisNearest = 'Nearest taxis';
  static String taxisNearPlace(String p) => 'Taxis near $p';
  static String taxisNearestToPlace(String p) => 'Nearest taxis to $p';

  static String jobsNearCity(String c) => 'Jobs near $c';
  static const String jobsNearest = 'Nearest jobs';

  // Whole km from 10 up, one decimal below; never rounded down.
  static String kmText(double km) {
    if (km >= 10) return km.ceil().toString();
    final t = (km * 10).round() / 10;
    return t == t.roundToDouble() ? t.round().toString() : t.toStringAsFixed(1);
  }

  static String inCity(String c) => 'In $c';
  static String near(String? c, double km) =>
      _has(c) ? '$c. About ${kmText(km)} km away' : 'About ${kmText(km)} km away';
  static String far(String? c, String? s, double km) {
    if (!_has(c)) return 'About ${kmText(km)} km away';
    final place = _has(s) ? '$c, $s' : c!;
    return '$place. About ${kmText(km)} km away';
  }

  static const String byRoad = 'By road it can take longer.';
  static String basedIn(String? c, double km) =>
      _has(c) ? 'Based near $c. About ${kmText(km)} km away' : 'About ${kmText(km)} km away';
  static const String notListedForRoute = 'Based nearby. Not listed for this route.';

  static const String driversOnRoute = 'Drivers on this route';
  static const String driversPassing = 'Drivers passing your area';
  static String basedNearFrom(String c) => 'Based near $c. Not listed for this route';
  static String taxisInTo(String c) => 'Taxis in $c';
  static const String showMore = 'Show more';

  static String usingPin(String label) => 'Showing near $label';
  static const String usingGps = 'Showing near you';
  static const String usingMyLocation = 'Using my location';
  static const String searchAnyPlace = 'Search any place';
  static const String useMyLocation = 'Use my location';
  static String nearestTown(String c, double km) => 'Nearest town: $c, about ${kmText(km)} km';
  static const String searchFailed = 'Could not search that place. Please try again.';

  static const String staysEmptyTitle = 'No stays listed yet';
  static const String staysEmptyBody = 'New stays are added often. Please check again soon.';
  static const String taxisEmptyTitle = 'No taxis listed yet';
  static const String taxisEmptyBody = 'New drivers join often. Please check again soon.';
  static const String routeEmptyTitle = 'No driver is listed on this route yet.';
  static const String routeEmptyBody = 'Try another place or check again soon.';
  static const String jobsEmptyTitle = 'No jobs listed yet';
  static const String jobsEmptyBody = 'New jobs are added often. Please check again soon.';
  static const String thin = 'That is all we have for now.';
  static const String errorTitle = 'Could not load the list';
  static const String errorBody = 'Please try again.';
  static const String tryAgain = 'Try again';

  static const String citiesLoadingTitle = TripStringsCity.citiesLoadingTitle;
  static const String citiesLoadingBody = TripStringsCity.citiesLoadingBody;

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;
}
