class DriverRatingStrings {
  static const String title = 'My rating';
  static const String subtitle = 'Your driver record';
  static const String average = 'Average stars';
  static const String ratings = 'Ratings';
  static const String completedRides = 'Completed rides';
  static const String latest = 'Latest ratings';
  static const String noRatings = 'No ratings yet';
  static const String dash = '-';
  static const String loadFailed = 'Could not load your rating';
  static const String tryAgain = 'Try again';

  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String averageText(double value) => value.toStringAsFixed(1);

  static String dateText(String raw) {
    final d = DateTime.tryParse(raw);
    return d == null ? raw : '${d.day} ${_months[d.month - 1]}';
  }
}
