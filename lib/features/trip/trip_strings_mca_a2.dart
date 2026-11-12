import 'trip_constants.dart';

class TripStringsMcaA2 {
  static String get maxPlaces => 'A trip can have up to ${TripConstants.maxSpots} places';

  static const String popularRoutes = 'Popular routes';
  static String routeTitle(String a, String b) => '$a then $b';
  static const String routeMeta = '2 cities';

  static const String addACity = 'Add a city';
  static String afterCity(String city) => 'After $city';
  static const String popularNextStops = 'Popular next stops';
  static const String inThisTrip = 'In this trip';
  static const String alreadyAdded = 'Already added';
  static const String noPlacesYet = 'No places yet · stay and taxi only';

  static String taxisGoFrom(String city) => 'Taxis go from $city';

  static const String addToTrip = 'Add to trip';
  static String spotsAddToTrip(int n) => '$n ${n == 1 ? 'spot' : 'spots'} · $addToTrip';

  static const String cantChangeTrip = 'This trip can not be changed now';
}
