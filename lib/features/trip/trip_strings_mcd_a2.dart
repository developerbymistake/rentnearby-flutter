class TripStringsMcdA2 {
  static String mapSubtitle(String route) => '$route trip';
  static String daysCities(int d, int c) => '$d ${d == 1 ? 'day' : 'days'} · $c cities';
  static String inCitiesLine(String km, int travelDays) =>
      '$km in cities · $travelDays ${travelDays == 1 ? 'travel day' : 'travel days'}';
  static const String travelLegend = 'Travel';
  static const String tapCityHint = 'Tap a city to zoom to it, a number for one day.';
  static const String all = 'All';
  static String citySemantics(String city, String range) => '$city, $range';
}
