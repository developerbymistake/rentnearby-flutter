import 'trip_constants.dart';

class TripStringsMcaA2 {
  static String get maxPlaces => 'A trip can have up to ${TripConstants.maxSpots} places';

  static const String popularRoutes = 'Popular routes';
  static String routeTitle(String a, String b) => '$a then $b';
  static const String routeMeta = '2 cities';

  static const String addACity = 'Add a city';
  static const String addACityRow = '+ Add a city';
  static String afterCity(String city) => 'After $city';
  static String citiesIn(List<String> states) => switch (states.length) {
        1 => 'Cities in ${states[0]}',
        2 => 'Cities in ${states[0]} and ${states[1]}',
        _ => 'Cities in your trip states',
      };
  static String noCityMatchIn(String q, String state) => 'No city in $state matches "$q"';
  static String otherState(String state) => 'This trip stays in $state';
  static const String popularNextStops = 'Popular next stops';
  static const String inThisTrip = 'In this trip';
  static const String alreadyAdded = 'Already added';
  static const String noPlacesYet = 'No places yet · stay and taxi only';

  static String taxisGoFrom(String city) => 'Taxis go from $city';

  static const String addToTrip = 'Add to trip';
  static String spotsAddToTrip(int n) => '$n ${n == 1 ? 'spot' : 'spots'} · $addToTrip';

  static const String cantChangeTrip = 'This trip can not be changed now';
}
