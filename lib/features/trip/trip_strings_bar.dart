import 'utils/trip_format.dart';

class TripStringsBar {
  static const String inProgress = 'IN PROGRESS';
  static const String ready = 'READY';
  static String groupHeader(String group, int n) => '$group · $n';
  static String pastTrips(int n) => 'Past trips · $n';
  static const String noActiveTrips = 'No trips in progress';
  static const String noPastTrips = 'No past trips yet';
  static const String noPastSub = 'Finished trips show here.';

  static String move(String from, String to) => '$from → $to';

  static const String continueAction = 'Continue';

  static const String startsToday = 'Starts today';
  static const String startsTomorrow = 'Starts tomorrow';
  static String startsIn(int days) => 'Starts in $days days';
  static String dayOf(int day, int count) => 'Day $day of $count';
  static const String checkOutToday = 'Check-out today';
  static const String ended = 'Trip ended';
  static String withDates(String lead, DateTime a, DateTime b) => '$lead · ${TripFormat.dayMonthRange(a, b)}';

  static String next(String step) => 'Next: $step';
  static const String readyLine = 'Your trip is ready';
  static const String todayLine = 'Today · your trip starts';
  static const String tomorrowLine = 'Tomorrow · all set';
  static String more(int n) => '+$n more';

  static const String hideTitle = 'Hide the trip bar?';
  static const String hideBody =
      'Your trip stays in My Trips with its progress. The bar comes back when the trip changes or a reply arrives.';
  static const String hideAction = 'Hide the bar';
  static const String keepShowing = 'Keep showing';
  static const String hideTooltip = 'Hide';
}
