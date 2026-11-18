class DriverBookingsStrings {
  static const String title = 'My bookings';
  static const String calendar = 'Calendar';
  static const String bookings = 'Bookings';
  static const String withdraw = 'Withdraw';
  static const String endTrip = 'End trip';
  static const String call = 'Call';
  static const String stateOccupied = 'Occupied';
  static const String stateCompleted = 'Completed';
  static const String stateCancelled = 'Cancelled';
  static const String previousMonth = 'Previous month';
  static const String nextMonth = 'Next month';
  static const String occupiedDay = 'Booked';

  static const String sheetTitle = 'Withdraw from booking';
  static const String confirmWithdraw = 'Confirm withdraw';

  static const String emptyTitle = 'No bookings yet';
  static const String emptyMessage = 'Trips you confirm will show up here.';
  static const String loadFailedTitle = 'Could not load bookings';
  static const String loadFailedMessage = 'Please check your connection and try again.';
  static const String retry = 'Try again';

  static const String withdrawn = 'You withdrew from this booking';
  static const String ended = 'Trip ended';
  static const String alreadyChanged = 'This booking has already changed';
  static const String offline = 'No connection. Please try again.';
  static const String failed = 'Something went wrong. Please try again.';

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const List<String> _short = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String monthName(DateTime m) => _months[m.month - 1];

  static String monthYear(DateTime m) => '${monthName(m)} ${m.year}';

  static String dayLabel(DateTime d) => '${d.day} ${_short[d.month - 1]}';

  static String range(DateTime? from, DateTime? to) {
    if (from == null) return '';
    if (to == null) return dayLabel(from);
    return '${dayLabel(from)} to ${dayLabel(to)}';
  }

  static String detail(String pickup, String traveller) {
    final p = pickup.isEmpty ? '' : '$pickup pickup';
    if (p.isEmpty) return traveller;
    return traveller.isEmpty ? p : '$p · $traveller';
  }
}
