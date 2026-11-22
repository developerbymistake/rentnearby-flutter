import '../../nearby/nearby_strings.dart';

abstract final class SeekerHomeStrings {
  static String greeting(String firstName) => 'Hi, $firstName';
  static const String greetingFallbackName = 'there';
  static const String whereToNext = 'Where to next?';

  static const String tripEyebrow = 'Travel Planner';
  static const String noTripTitle = 'Plan your first trip';
  static const String failedTitle = 'Your trips';
  static const String noTripBody = 'Places, days, stay and taxi in one plan.';
  static const String planTrip = 'Plan a trip';

  static const String continueTitle = 'Continue your trip';
  static const String continueAction = 'Continue';
  static const String viewerTitle = 'Shared with me';
  static const String openTrip = 'Open trip';
  static String eyebrow(String title, String? dates) => dates == null ? title : '$title · $dates';
  static String subtitle(String title, String? dates) => dates == null ? title : '$title, $dates';
  static String progress(int done, int total) => '$done of $total done';
  static String next(String step) => 'Next: $step';
  static String confirmed(String listingName) => '$listingName confirmed your stay';
  static String replied(int count) => count == 1 ? '1 stay replied. Pick one.' : '$count stays replied. Pick one.';
  static String dateRange(String from, String to) => '$from to $to';

  static String dayOf(int day, int total) => 'Day $day of $total';
  static String dayIn(int day, String city) => 'Day $day in $city';
  static String todayIn(String city) => 'Today in $city';
  static String placesToday(int n) => n == 1 ? '1 place on today’s plan' : '$n places on today’s plan';
  static String placesSeen(int seen, int total) => '$seen of $total places seen';
  static const String todayPlan = 'Today’s plan';

  static String plansFull(int count, int limit) => '$count of $limit plans used. Delete one to plan more.';
  static const String myTrips = 'My trips';

  static const String stepTaxi = 'book a taxi';
  static String stepStay(String city) => 'find a stay in $city';
  static const String stepStayAny = 'find a stay';
  static const String stepJourney = 'plan the journey';
  static const String stepPlan = 'finish your plan';

  static const String quickActions = 'Quick actions';
  static const String tilePlanTitle = 'Plan a trip';
  static const String tilePlanBody = 'Pick a city and go';
  static const String tileTripsTitle = 'My trips';
  static const String tileTripsBody = 'Continue or review';
  static const String tileExpenseTitle = 'Add expense';
  static const String tileExpenseBody = 'Split with friends';
  static const String tileBuddyTitle = 'Find a buddy';
  static const String tileBuddyBody = 'Travel together';
  static const String planTripFirst = 'Plan a trip first';
  static const String expensePickTitle = 'Add expense to';

  static const String railsErrorTitle = 'Couldn’t load';
  static const String railsErrorBody = 'Check your internet and try again.';
  static const String retry = 'Retry';
  static const String seeAll = 'See all';
  static const String recentlyAdded = 'Recently added stays';
  static const String rowArrow = '›';
  static const String loading = 'Loading';
  static String slideOf(int i, int n) => 'Slide $i of $n';

  static const String perNight = '/night';
  static const String perDay = '/day';
  static const String fareFrom = 'FARE FROM';
  static const String localTaxi = 'Local taxi';
  static const String stayTag = 'FOR STAY';
  static const String taxiTag = 'TAXI';
  static const String from = 'FROM';

  static String kmShort(String? label) {
    var s = label?.trim() ?? '';
    if (s.endsWith(' away')) s = s.substring(0, s.length - 5).trim();
    return s;
  }

  static String kmOf(double km) => '${NearbyStrings.kmText(km)} km';
}
