class TripStringsAlgoAa {
  static const String tomorrow = 'Tomorrow';
  static String inDays(int d) => 'In $d days';
  static String days(int n) => '$n ${n == 1 ? 'day' : 'days'}';

  static String cars(int n) => '$n cars';
  static String about(String amount) => 'about $amount';
  static String carsPerDay(int n) => '$n cars · per day';
  static String extraKm(int km) => '+$km km, ask driver';

  static const String doesNotFit = 'Does not fit your group';
  static const String perNightGroup = 'per night, your group';
  static String quoteLine(String room, int units) => units == 1 ? room : '$units x $room';
}
