class TripStringsMcaA4 {
  static const String routeJoin = ' → ';

  static String routeOf(List<String> cities) => cities.where((c) => c.isNotEmpty).join(routeJoin);

  static String citiesCount(int n) => '$n cities';
}
