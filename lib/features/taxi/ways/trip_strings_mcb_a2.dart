class TripStringsMcbA2 {
  static String fromYourTrip(int day) => 'From your trip · Day $day';
  static const String travelDayOfTrip = 'Travel day of your trip';
  static const String openJourney = 'Open journey';
  static const String searchAgain = 'Search again';
  static const String removeTravelQ = 'Remove travel?';
  static String bookedCarsCancelled(int n) =>
      n == 1 ? '1 booked car is cancelled and the driver is told.' : '$n booked cars are cancelled and the drivers are told.';
  static const String cancelAndRemove = 'Cancel and remove';
  static const String replaceTravelQ = 'Replace travel?';
  static const String replace = 'Replace';
  static const String keep = 'Keep';
  static String carsAbout(int n, String total) => n == 1 ? '1 car · about $total' : '$n cars · about $total';
  static const String iBooked = 'I booked';
  static const String bookedByYou = 'Booked by you';
  static const String confirmedByBoth = 'Confirmed by both';
  static String driversUnavailable(int n) => n == 1 ? '1 driver unavailable' : '$n drivers unavailable';
  static String replaceWith(String name) => 'Replace with $name';
  static String carNoDriver(int n) => 'Car $n has no driver · Ask a backup';
  static String carNoReply(int n) => 'Car $n · no reply · Ask a backup';
  static const String driverPaused = 'Driver paused his listing · Call to check';
  static const String getThereMyself = "I'll get there myself";
  static String noDriverGoes(String from, String to) => 'No driver goes from $from to $to yet';
  static const String nobodyListed = 'Nobody is listed on this road';
  static String reachHubThen(String hub, String to) => 'Reach $hub by train or bus, then your $to plan starts.';
  static String carTo(int i, String place) => 'Car $i · to $place';
  static String quoted(String money) => '$money · quoted';
  static String listed(String money) => '$money · listed';
  static String about(String money) => 'about $money';
  static const String call = 'Call';
  static const String free = 'Free';
  static const String asked = 'Asked';
  static const String notAsked = 'Not asked';
  static const String changeCar = 'change car';
  static String agreed(String money) => '$money · agreed';
  static const String driverFallback = 'Driver';
}
