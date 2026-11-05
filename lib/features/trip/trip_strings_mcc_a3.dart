import 'trip_strings.dart';

class TripStringsMccA3 {
  static String legLine(String city, int a, int b) {
    final days = a >= b ? 'Day $a' : 'Days $a-$b';
    return city.trim().isEmpty ? days : '$city · $days';
  }

  static const String oldDates = 'Old dates';

  static String oldDatesLine(String range, {String price = ''}) =>
      price.isEmpty ? '$oldDates · $range' : TripStrings.oldDates(range, price);
}
