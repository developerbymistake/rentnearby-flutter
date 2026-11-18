class TripStringsTaxiRequest {
  static const String title = 'Request taxi';
  static const String subtitle = 'Choose what you need, then send';
  static const String intro = 'Turn a section on or off. Only turned-on sections are sent.';
  static const String send = 'Request taxi';

  static const String pickupTitle = 'Pickup from hub';
  static const String pickupSub = 'Where drivers meet you';
  static const String choosePickupLabel = 'Choose pickup';
  static const String sightseeingTitle = 'Sightseeing taxi';
  static const String sightseeingSub = 'Taxi on the days you pick';
  static const String dropTitle = 'Drop to hub';
  static const String dropSub = 'Where the trip ends';
  static const String chooseDropLabel = 'Choose drop';
  static const String sameAsPickup = 'Same as pickup';
  static const String change = 'Change';
  static const String carTitle = 'Your car';
  static const String seats4 = '4 seater';
  static const String seats6 = '6 seater';
  static const String seats7 = '7+ seater';

  static const String noDriversTitle = 'No taxi drivers registered near here yet';
  static const String skipTaxi = 'Skip taxi';
  static const String tryAnotherCity = 'Try another city';

  static const String summaryNoSection = 'Turn on at least one section';
  static const String summaryChoosePickup = 'Choose a pickup';
  static const String summaryChooseDrop = 'Choose a drop';
  static const String summaryNoPickup = 'No pickup available here';
  static const String summaryNoDrop = 'No drop available here';
  static const String summaryDropSame = 'drop same as pickup';

  static const String legacyTitle = 'Taxi already asked';
  static const String legacyBody = 'This trip has a taxi ask from an older app version. Cancel it to send a new request.';
  static const String legacyKeep = 'Keep it';
  static const String legacyCancel = 'Cancel old ask';

  static const String noDropTitle = 'No drop places available near here yet';
  static const String paused = 'Requests are paused right now';
  static const String loadFailed = 'Could not load pickup places.';
  static const String retry = 'Try again';
  static const String offline = 'No internet connection. Please try again.';
  static const String sendFailed = 'Could not send your request. Please try again.';
  static const String pickupGone = 'That pickup is no longer available. Please choose again.';
  static const String dropGone = 'That drop is no longer available. Please choose again.';
  static const String dayOn = 'Include this day';

  static String groupDays(int n) => '$n ${n == 1 ? 'day' : 'days'}';
  static String dayTitle(int day, String city) => 'Day $day · $city';
  static String aboutKm(int km) => 'About $km km';
  static String setFromTravellers(int n) => 'Set from $n ${n == 1 ? 'traveller' : 'travellers'}';
  static String drivers(int n) => '$n ${n == 1 ? 'driver' : 'drivers'}';
  static String pickupNotAvailableFor(String city) => 'Pickup is not available for $city right now.';
  static String summaryPickupAt(String city) => 'Pickup at $city';
  static String summaryDropAt(String city) => 'drop at $city';
  static String summaryDays(int n) => '$n sightseeing ${n == 1 ? 'day' : 'days'}';
  static String seatsLabel(int seats) => seats == 4 ? seats4 : (seats == 6 ? seats6 : seats7);
}
