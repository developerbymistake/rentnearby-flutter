import '../../../trip/trip_strings_taxi_driver.dart';

class DriverRingStrings {
  DriverRingStrings._();

  static const String eyebrow = 'Incoming request';
  static const String title = 'New taxi request';
  static const String decline = TripStringsTaxiDriver.decline;
  static const String accept = TripStringsTaxiDriver.accept;
  static const String missed = TripStringsTaxiDriver.stateMissed;
  static const String missedNote = TripStringsTaxiDriver.missedNote;
  static const String close = 'Close';
  static const String loading = 'Getting the request';
  static const String loadFailedTitle = 'Could not open the request';
  static const String loadFailedNote = 'Check your connection and try again';
  static const String retry = 'Try again';
  static const String actionFailed = 'Could not send your answer. Try again.';
  static const String paused = 'Taxi requests are paused for now';
  static const String swipeHint = 'Swipe up to answer';

  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String dateRange(DateTime? from, DateTime? to) {
    if (from == null || to == null) return '';
    final end = '${to.day} ${_months[to.month - 1]}';
    if (from.month == to.month && from.year == to.year) return '${from.day} to $end';
    return '${from.day} ${_months[from.month - 1]} to $end';
  }

  static String summary(int days, int nights, DateTime? from, DateTime? to) {
    final length = '$days ${days == 1 ? 'day' : 'days'} · $nights ${nights == 1 ? 'night' : 'nights'}';
    final range = dateRange(from, to);
    return range.isEmpty ? length : '$length · $range';
  }

  static String seats(int seats, int travellers) => TripStringsTaxiDriver.seatsLine(seats, travellers);

  static String sightseeing(int days) => TripStringsTaxiDriver.sectionSightseeing(days);

  static const String pickup = TripStringsTaxiDriver.sectionPickup;
  static const String drop = TripStringsTaxiDriver.sectionDrop;
}
