abstract final class SeekerHomeStrings {
  static String greeting(String firstName) => 'Hi, $firstName';
  static const String greetingFallbackName = 'there';
  static const String whereToNext = 'Where to next?';

  static const String tripEyebrow = 'Find your next destination?';
  static const String noTripTitle = 'Plan your trip';
  static const String failedEyebrow = 'Travel Planner';
  static const String failedTitle = 'Your trips';
  static const String noTripBody = 'Make your itinerary.';
  static const String planTrip = 'Plan a trip';
  static const String browseStays = 'Browse stays';
  static const String seeTaxis = 'See taxis';

  static const String continueTitle = 'Continue your trip';
  static const String continueAction = 'Continue';
  static const String viewerTitle = 'Shared with me';
  static const String openTrip = 'Open trip';
  static String eyebrow(String title, String? dates) => dates == null ? title : '$title · $dates';
  static String progress(int done, int total) => '$done of $total done';
  static String next(String step) => 'Next: $step';
  static String confirmed(String listingName) => '$listingName confirmed your stay';
  static String replied(int count) => count == 1 ? '1 stay replied. Pick one.' : '$count stays replied. Pick one.';
  static String dateRange(String from, String to) => '$from to $to';

  static String dayOf(int day, int total) => 'Day $day of $total';
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
  static const String tileBuddyTitle = 'Find a buddy';
  static const String tileBuddyBody = 'Travel together';

  static const String railsErrorTitle = 'Couldn’t load';
  static const String railsErrorBody = 'Check your internet and try again.';
  static const String retry = 'Retry';
  static const String loading = 'Loading';
  static String slideOf(int i, int n) => 'Slide $i of $n';
}
