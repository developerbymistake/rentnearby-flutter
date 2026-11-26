abstract final class TaxiSearchErrors {
  static const invalidDate = 'InvalidDate';
}

abstract final class TaxiSearchStrings {
  static const from = 'From';
  static const to = 'To';
  static const nearYou = 'Near you';
  static const toHint = 'Search a place';
  static const dateCaption = 'Date of journey';
  static const today = 'Today';
  static const searchTaxis = 'Search taxis';
  static const popularRoutes = 'Popular routes';
  static const samePlace = 'From and To must be different places';
  static const dateSheetTitle = 'Date of journey';
  static const dateSheetBody = 'Today up to 90 days ahead';
  static const done = 'Done';
  static const pageTitle = 'Taxi';
  static const pageSubtitle = 'Taxis for your route';
  static const sort = 'Sort';
  static const nearest = 'Nearest';
  static const cheapest = 'Cheapest';
  static const errorTitle = 'Could not load taxis';
  static const errorBody = 'Check your connection and try again.';
  static const tryAgain = 'Try again';
  static const emptyBody = 'Try another day or another place.';
  static const clearTo = 'Clear To';
  static const useMyCentre = 'Use my centre';
  static const swapLabel = 'Swap From and To';
  static const prevDay = 'Previous day';
  static const nextDay = 'Next day';

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String shortDay(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  static String dayText(DateTime d) => '${_weekdays[d.weekday - 1]} ${shortDay(d)}';

  static String barText(DateTime d, {required bool isToday}) => isToday ? '$today, ${dayText(d)}' : dayText(d);

  static String freeCount(int n, DateTime d) => '$n ${n == 1 ? 'taxi' : 'taxis'} free on ${shortDay(d)}';

  static String emptyTitle(DateTime d) => 'No taxi is free on ${shortDay(d)}';

  static String routeTitle(String a, String b) => '$a → $b';

  static String routeSemantics(String a, String b) => '$a to $b';

  static String fromFare(String inr) => 'From $inr';

  static String taxis(int n) => '$n ${n == 1 ? 'taxi' : 'taxis'}';

  static String dateRowSemantics(DateTime d, {required bool isToday}) => '$dateCaption, ${barText(d, isToday: isToday)}';
}
