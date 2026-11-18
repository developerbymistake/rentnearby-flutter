class DriverRequestDetailStrings {
  static const String titleRinging = 'Request details';
  static const String titleAccepted = 'Request accepted';
  static const String titleSelected = 'Booking request';
  static const String titleBooked = 'Booking';
  static const String titleEnded = 'Request';

  static const String loadFailed = 'Could not load this request.';
  static const String tryAgain = 'Try again';
  static const String loading = 'Loading request';
  static const String actionFailed = 'That did not work. Please try again.';
  static const String actionOffline = 'No internet. Please try again.';

  static const String waitingForTraveller = 'Waiting for traveller to choose';
  static const String openBookings = 'My bookings';
  static const String bookedNote = 'This booking is confirmed.';

  static const String sectionTrip = 'Trip';
  static const String sectionRoute = 'Route';
  static const String sectionDays = 'Day by day';
  static const String rowDates = 'Dates';
  static const String rowLength = 'Length';
  static const String rowTravellers = 'Travellers';
  static const String rowCar = 'Car';
  static const String rowIncludes = 'Includes';

  static const String pickup = 'Pickup';
  static const String drop = 'Drop';
  static const String taxiNeeded = 'Taxi needed';
  static const String noTaxiNeeded = 'No taxi needed';
  static const String ownPlan = 'Own plan';

  static String selectedCountdown(String left) => 'Selected you · confirm in $left';

  static String datesBooked(String from, String to) => 'Dates already booked. You have another booking from $from to $to.';

  static String length(int days, int nights) =>
      '$days ${days == 1 ? 'day' : 'days'} · $nights ${nights == 1 ? 'night' : 'nights'}';

  static String travellers(int n) => '$n ${n == 1 ? 'traveller' : 'travellers'}';

  static String car(int seats) => '$seats seater';

  static String includes({required bool pickup, required int sightseeingDays, required bool drop}) => [
        if (pickup) pickupWord,
        if (sightseeingDays > 0) '$sightseeingDays sightseeing ${sightseeingDays == 1 ? 'day' : 'days'}',
        if (drop) dropWord,
      ].join(', ');

  static const String pickupWord = 'Pickup';
  static const String dropWord = 'Drop';

  static String hubDate(String name, String date) => '$name hub · $date';

  static String sameAsPickup(String name, String date) => 'Same as pickup · $name hub · $date';

  static String nightsRange(int nights, String range) => '$nights ${nights == 1 ? 'night' : 'nights'} · $range';

  static String daysCount(int n) => '$n ${n == 1 ? 'day' : 'days'}';

  static String dayTitle(int day, String date) => 'Day $day · $date';

  static String km(int km, int minutes) => '$km km · ${duration(minutes)}';

  static String duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m m';
    return m == 0 ? '$h h' : '$h h $m m';
  }

  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  static String weekdayDate(DateTime d) => '${_weekdays[d.weekday - 1]} ${shortDate(d)}';

  static String range(DateTime a, DateTime b) {
    if (a.month == b.month && a.year == b.year) return '${a.day} to ${shortDate(b)}';
    return '${shortDate(a)} to ${shortDate(b)}';
  }

  static String fullRange(DateTime a, DateTime b) => '${shortDate(a)} to ${shortDate(b)}';
}
