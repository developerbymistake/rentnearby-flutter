import 'trip_strings_shortlist.dart';

class TripStringsGuide {
  const TripStringsGuide._();

  static const String optFind = 'Help me find';
  static const String optOwn = 'I will arrange it myself';
  static const String optSkip = 'Skip this';
  static const String previous = 'Previous';
  static const String next = 'Next';
  static const String overview = 'Overview';
  static const String overviewTitle = 'Your trip so far';
  static const String statusToDo = 'To do';
  static const String statusLooking = 'In progress';
  static const String statusOwn = 'You arrange';
  static const String statusSkipped = 'Skipped';
  static const String statusDone = 'Arranged';
  static const String chooseHint = 'Choose an option to continue';
  static const String findHint = 'Pick up to 3 from the list, or choose another option';
  static const String reviewHint = 'Send your enquiry, or tap Not now to continue';
  static const String openList = 'Open the list';
  static const String noTaxiNote = 'We will not show taxis for this trip.';
  static const String skipBlocked = 'You already sent an enquiry here. Withdraw it first.';
  static const String ownBlocked = 'This one is already booked.';
  static const String offline = 'Connect to the internet to continue.';

  static String percent(int n) => '$n% done';
  static String stepOf(int i, int n) => 'Step $i of $n';

  static const String nameGettingThere = 'Getting there';
  static const String nameTaxi = 'Sightseeing taxi';
  static const String nameWayBack = 'Way back';
  static String nameStay(String city) => 'Stay in $city';
  static String nameBetween(String next) => 'To $next';

  static const String gettingThereTitle = "Let's get you there";
  static String gettingThereBody(String from, String city) => 'Would you like to see taxis from $from to $city?';
  static String stayTitle(String city) => 'Where will you stay in $city?';
  static String stayBody(String city) => 'Would you like to see stays in $city?';
  static String taxiTitle(String cities) => 'See the sights in $cities';
  static const String taxiBody = 'Do you need a taxi to see the sights?';
  static String betweenTitle(String next) => 'On to $next';
  static String betweenBody(String city, String next) => 'Do you need a taxi from $city to $next?';
  static const String backTitle = 'Getting back home';
  static const String backBody = 'Do you need a taxi for the way back?';

  static const String reviewTitle = 'Great picks';
  static String reviewBody(bool stays) =>
      'Send an enquiry to all your shortlisted ${stays ? 'stays' : 'taxis'} together?';
  static String shortlisted(int n) => '$n of 3 shortlisted';
  static const String sendAll = 'Yes, send to all';
  static const String notNow = 'Not now';
  static const String sentTitle = 'Enquiry sent';
  static String sentBody(int n, {bool taxi = false}) {
    final who = taxi ? 'driver' : 'host';
    return 'We told $n ${n == 1 ? who : '${who}s'}. You will see replies here.';
  }
  static const String sendFailed = 'Try again';
  static String failedNote(int n, {bool? taxi}) => taxi == null
      ? (n == 1 ? 'One enquiry could not be sent.' : '$n enquiries could not be sent.')
      : TripStringsShortlist.failedNote(n, taxi: taxi);
  static const String retrySend = 'Try again';
  static const String sending = 'Sending';

  static String nudgeTitle(String name) => 'Did you book $name?';
  static const String nudgeBody = 'If you already booked it, mark it as booked.';
  static const String nudgeNameFallback = 'it';
  static const String markBooked = 'Mark as booked';
  static const String chooseNew = 'Choose new options';

  static const String reopenTitle = 'No reply yet';
  static const String reopenBody = 'Your shortlist ended without a reply. Did you already book?';
  static const String bookedMyself = 'I booked it myself';
  static const String findNew = 'Find new options';

  static const String skipArranged = 'This is already arranged. Remove it first.';
  static const String backToSteps = 'Back to steps';
  static const String carReviewBody = 'Pick your car and send your enquiry.';
  static const String chooseAndSend = 'Choose and send';
  static const String changePicks = 'Change my picks';
  static const String finishSavedTitle = 'Your plan is saved';
  static const String finishSavedBody = 'See what is still to do.';
  static const String seeStillToDo = 'See what is still to do';

  static const String finishTitle = 'Your trip is ready to go';
  static const String finishName = 'All done';
  static const String finishBody = 'Review everything in your summary.';
  static const String openSummary = 'Open summary';
  static const String summaryLocked = 'Answer every step to see the summary';
}
