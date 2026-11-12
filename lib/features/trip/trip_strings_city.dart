class TripStringsCity {
  const TripStringsCity._();

  static const String citiesLoadingTitle = 'Cities are loading';
  static const String citiesLoadingBody = 'Please try again in a moment.';
  static const String tryAgain = 'Try again';
  static const String roadLineMissing = 'Road line not available';

  static String viaLine(List<String> names) => 'Via ${names.join(', ')}';

  static String noTaxisTitle(String city) => city.isEmpty ? 'No taxis here yet' : 'No taxis in $city yet';
  static String noStaysTitle(String city) => city.isEmpty ? 'No stays here yet' : 'No stays in $city yet';
  static const String noSupplyBody = 'Try a nearby city, or check again soon.';
}
