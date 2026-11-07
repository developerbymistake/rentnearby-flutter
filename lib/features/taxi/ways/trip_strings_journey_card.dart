class TripStringsJourneyCard {

  static const String pickStart = 'Pick your starting city';

  static const String undo = 'Undo';
  static const String searchAgain = 'Search again';

  static const String carNotAsked = 'Not asked';
  static const String carAsked = 'Waiting for driver';
  static const String carFree = 'Free · book it';
  static const String carBookedByYou = 'Booked by you · driver not confirmed';
  static const String carConfirmed = 'Confirmed';
  static const String carOwn = 'Your own';
  static const String carNotAvailable = 'No driver';
  static const String carNoReply = 'No reply';
  static const String carPaused = 'Driver paused';
  static String useBackup(String name) => 'Use backup $name';
  static const String findAnotherCar = 'Find another car';
  static String arrangeCar(int car) => 'I will arrange car $car myself';
  static String cancelBookingQ(String driver) => "Cancel $driver's booking?";
  static const String cancelBookingBody = 'The driver is told at once.';
  static const String cancelBooking = 'Cancel booking';
  static String cancelDriverBooking(String driver) => "Cancel $driver's booking";
  static const String carClosedFailed = "Couldn't update this car. Try again.";

  static const String startChanged = 'Start changed';
  static String searchFromAgain(String city) => city.isEmpty ? 'Search the way again?' : 'Search the way again from $city?';
  static const String later = 'Later';

}
