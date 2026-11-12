import 'trip_constants.dart';

class TripStringsMcaA2 {
  static String get maxPlaces => 'A trip can have up to ${TripConstants.maxSpots} places';

  static const String addACity = 'Add a city';
  static String afterCity(String city) => 'After $city';
  static const String inThisTrip = 'In this trip';
  static const String alreadyAdded = 'Already added';
  static const String noPlacesYet = 'No places yet · stay and taxi only';

  static const String addToTrip = 'Add to trip';
  static String spotsAddToTrip(int n) => '$n ${n == 1 ? 'spot' : 'spots'} · $addToTrip';

  static const String cantChangeTrip = 'This trip can not be changed now';
}
