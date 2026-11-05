import 'trip_constants.dart';

class TripStringsMcaA1 {
  static const int titleMax = 80;

  static String defaultTitle(List<String> cities) {
    final names = [
      for (final c in cities)
        if (c.trim().isNotEmpty) c.trim(),
    ];
    if (names.isEmpty) return 'Trip';
    final full = '${names.join(', ')} trip';
    final text = full.length <= titleMax || names.length == 1 ? full : moreTrip(names.first, names.length - 1);
    return text.length <= titleMax ? text : text.substring(0, titleMax);
  }

  static String moreTrip(String first, int n) => '$first + $n more trip';

  static String cityAdded(String c) => '$c added to your trip';

  static String cityRemoved(String c) => '$c removed';

  static const String differentCity = "Different city · add it from that city's places";

  static String cancelBookingsFirst(String c) => 'Cancel the bookings in $c first';

  static const String noDaysLeft = 'No days left · ${TripConstants.maxDaysCap} is the most';

  static const String maxCities = '${TripConstants.maxLegs} cities · the most in one trip';

  static String alreadyInTrip(String c) => '$c is already in this trip';

  static const String maxPlaces = 'A trip can have up to ${TripConstants.maxSpots} places';
}
