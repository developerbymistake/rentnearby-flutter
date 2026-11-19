abstract final class TripStringsHubTrips {
  static const String active = 'Active';
  static const String past = 'Past trips';
  static const String stepsDone = 'steps done';
  static const String needsYou = 'needs you';
  static const String ready = 'ready';
  static const String done = 'done';
  static const String doneLabel = 'Done';
  static const String stay = 'Stay';
  static const String taxi = 'Taxi';
  static const String plan = 'Plan';
  static const String notAdded = 'not added';
  static const String skipped = 'skipped';
  static const String asked = 'asked';
  static const String booked = 'booked';
  static const String requested = 'requested';
  static const String saved = 'saved';
  static const String notSaved = 'not saved';
  static String nights(int n) => n == 1 ? '1 night' : '$n nights';
  static String nightsOf(int covered, int total) => '$covered of $total nights';
  static const String completePlan = 'Complete my plan';
  static const String completePlanTitle = 'Complete this plan?';
  static String completePlanBody({required bool taxi, required bool stay}) => taxi && stay
      ? 'Complete this plan without taxi and stay? You can still add them any time.'
      : taxi
          ? 'Complete this plan without a taxi? You can still add one any time.'
          : 'Complete this plan without a stay? You can still add one any time.';
  static const String goBack = 'Go back';
  static const String completePlanFailed = "Couldn't complete the plan. Try again.";
  static const String nextStep = 'Next step';
  static const String readyStrip = 'Ready';
  static const String viewSummary = 'View summary';
  static const String completed = 'Completed';
  static const String tripFinished = 'Trip finished';
  static String stepsOf(int done, int total) => '$done of $total';
}
