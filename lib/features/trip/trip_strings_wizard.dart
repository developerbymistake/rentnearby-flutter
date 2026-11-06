import 'utils/trip_wizard_rules.dart';

class TripStringsWizard {
  const TripStringsWizard._();

  static const String trip = 'Trip';
  static const String list = 'List';
  static const String prev = 'Prev';
  static String nextTo(String title) => 'Next: $title';
  static const String doneBackToList = 'Done · back to the list';
  static String stepOf(String place, int i, int total) =>
      place.isEmpty ? 'Step $i of $total' : '$place · step $i of $total';

  static const String places = 'Places';
  static const String sightseeingTaxi = 'Sightseeing taxi';
  static const String stay = 'Stay';

  static const String start = 'Start';
  static const String yourTurn = 'Your turn';
  static const String seeReplies = 'See replies';
  static const String fix = 'Fix';
  static const String edit = 'Edit';

  static const String groupBefore = 'BEFORE THE TRIP';
  static String groupDay(int day, String city, String? date) =>
      ['DAY $day', if (city.isNotEmpty) city.toUpperCase(), ?date].join(' · ');
  static String groupBetween(int a, int b) => 'BETWEEN CITIES · Day $a → Day $b';
  static String groupEnd(String when) => 'AT THE END · $when';
  static String leaveCheckOut(String date) => 'check-out $date morning';
  static String leaveEvening(int day, String date) => 'Day $day evening · $date';
  static const String dateNotSet = 'date not set';
  static String startsAt(String heading) => 'Starts at $heading';
  static const String startNotChosen = "Start: last night's stay not chosen";
  static const String startNoStay = 'Start not set · no stay last night';

  static const String datesNotSet = 'Dates not set';
  static String startsIn(int days, String range) => days == 1 ? 'Starts tomorrow · $range' : 'Starts in $days days · $range';
  static String todayDay(int day) => 'Today · Day $day';
  static String stepsLine(int counted, int total, String? cost) =>
      '$counted of $total steps · ${cost == null ? 'Nothing booked yet' : '$cost so far'}';
  static String needYou(int n) => '$n need you';
  static String waitingForReply(int n) => '$n waiting for a reply';
  static String startNext(String title) => 'Start: $title';
  static String continueNext(String title) => 'Continue · $title';
  static const String tripReady = 'Your trip is ready';
  static String aboutTotal(String cost) => 'About $cost in all';
  static const String allSorted = 'Every step is sorted';
  static const String shareSummary = 'Share summary';
  static const String seeAll = 'See all';
  static const String summary = 'Summary';
  static String pickUp(String title) => 'Pick up where you left · $title';
  static const String offlineCopy = 'Offline copy';

  static const String planReady = 'Your plan is ready';
  static String planReadyLine(int places, int days) =>
      '$places ${places == 1 ? 'place' : 'places'} split into $days ${days == 1 ? 'day' : 'days'}';
  static const String addAnotherCity = 'Add another city';
  static String daySorted(int day) => 'Day $day sorted';
  static String percentHeading(int p) => p >= 100 ? 'Every step is sorted' : '$p% of your trip sorted';
  static String percentLine(int p) => p >= 100
      ? 'Your trip is ready'
      : p > 50
          ? 'More than half of your trip is done'
          : p >= 25
              ? 'Good start · keep going'
              : 'Keep going';
  static const String close = 'Close';

  static const String wishlistTitle = 'Still open';
  static String wishlistHint(int n) => '$n ${n == 1 ? 'step is' : 'steps are'} not sorted yet';
  static const String wishlistEmpty = 'Every step is sorted';

  static String undatedBookings(int n) => 'Bookings without a date · $n';
  static const String undatedHint = 'Add dates, or cancel them';
  static String outsideBookings(int n) => 'Bookings outside your dates · $n';
  static const String outsideHint = 'Dates changed. Ask for new dates, or cancel.';
  static const String changeDates = 'Change dates';
  static String bookingsOnDates(int n) => 'You have $n ${n == 1 ? 'booking' : 'bookings'} · Cancel them, or keep the dates?';
  static const String keepDates = 'Keep dates';
  static const String cancelAndClear = 'Cancel bookings and clear';

  static const String rename = 'Rename';
  static const String renameTrip = 'Rename trip';
  static const String tripName = 'Trip name';
  static const String mapOfTrip = 'Map of whole trip';
  static const String cancel = 'Cancel';
  static const String save = 'Save';

  static String stateLabel(TripStepState s, {bool needsYou = false, TripWizardStepKind? kind}) => switch (s) {
        TripStepState.todo => 'NOT SORTED',
        TripStepState.waiting => needsYou ? 'NEEDS YOU' : 'WAITING FOR A REPLY',
        TripStepState.attention => 'NEEDS A FIX',
        TripStepState.done =>
          kind == TripWizardStepKind.basics || kind == TripWizardStepKind.places ? 'DONE' : 'CONFIRMED',
        TripStepState.own => 'YOUR OWN',
        TripStepState.skipped => 'YOUR CHOICE',
      };

  static const String undo = 'Undo';
  static const String dismiss = 'Dismiss';
  static const String askAgain = 'Ask again';
  static const String askLater = 'Ask again later';
  static const String keepBooking = 'Keep booking';
  static const String keepOwn = 'Keep own · cancel booking';
  static const String keep = 'Keep';
  static const String replace = 'Replace';
  static const String editDetails = 'Edit details';
  static const String cancelBooking = 'Cancel booking';
  static const String seeBooking = 'See booking';
  static const String addDatesToAsk = 'Add dates to ask';
  static const String addDates = 'Add dates';
  static const String noteHint = 'Note (optional)';

  static const String basicsQuestion = 'Trip basics';
  static const String basicsHint = 'Dates, people and where you start';
  static const String dates = 'Dates';
  static const String people = 'People';
  static const String pace = 'Pace';
  static const String startingCity = 'Starting city';
  static const String addPeople = 'Add people';
  static const String addStartingCity = 'Add starting city';

  static String placesQuestion(int day) => 'What will you see on Day $day?';
  static const String cityNotReady = 'City not ready yet · add later';
  static const String addPlace = 'Add a place';
  static const String seeRouteOnMap = 'See route on map';
  static const String seeRoute = 'Route';
  static const String noPlacesThisDay = 'No places this day';
  static const String replacePlace = 'Replace';
  static const String moveToDay = 'Move to another day';
  static const String removePlace = 'Remove';
  static String pickOneFor(int day) => 'Pick one place for Day $day';
  static String dayLoad(String total, String limit) => '$total of $limit';
  static const String overDayLimit = 'Over the day limit';
  static String timeLeftToday(String t) => 'About $t left this day';
  static String overBy(String t) => 'Over the day limit by $t';
  static const String overLimitTitle = 'Over the day limit';
  static String overLimitBody(String t) => 'This place makes the day about $t too long.';
  static const String addAnyway = 'Add anyway';
  static const String pickAnother = 'Pick another';
  static String closedThatDay(String name) => '$name is closed on that day';
  static String dayStartsHere(int day) => 'DAY $day STARTS HERE';
  static const String leaveFrom = 'YOU LEAVE FROM';

  static String taxiQuestion(int day) => 'Taxi for sightseeing on Day $day?';
  static const String taxiCounts = 'Counts as done when the driver confirms';
  static const String findDriver = 'Find a driver';
  static const String askDriver = 'Ask driver';
  static const String findAnotherDriver = 'Find another driver';
  static const String haveTaxi = 'I have a taxi';
  static const String noTaxiThisDay = 'No taxi this day';
  static String noTaxiTitle(int day) => 'No taxi on Day $day';
  static const String checkingDrivers = 'Checking drivers...';
  static const String couldNotCheckDrivers = 'Could not check drivers';
  static const String taxisPaused = 'Taxis are paused right now';
  static String noDriversHere(String city) =>
      city.isEmpty ? 'No drivers with a day rate here yet' : 'No drivers with a day rate in $city yet';
  static String tellDriverNamed(String name) => 'WhatsApp $name';
  static String sendHostPlaces(String name) => 'Send $name the new places';
  static String callDriverNamed(String name) => 'Call $name';
  static String dayHasDriver(int day) => 'Day $day has a driver enquiry · withdraw it first';
  static String replaceOwnTaxi(String name) => name.isEmpty ? 'Replace your own taxi?' : 'Replace your own taxi $name?';

  static String stayQuestion(int day) => 'Where will you sleep on Night $day?';
  static const String stayCounts = 'Counts as done when the host confirms';
  static const String findStay = 'Find a stay';
  static const String askHosts = 'Ask hosts';
  static const String askHost = 'Ask host';
  static const String findDifferentStay = 'Find a different stay';
  static const String findAnotherStay = 'Find another stay';
  static const String changeStay = 'Change stay';
  static const String changeTaxi = 'Change taxi';
  static const String connectToAsk = 'Connect to ask hosts and drivers';
  static const String callDriver = 'Call driver';
  static const String editBooking = 'Edit booking';
  static const String callHost = 'Call host';
  static const String haveStay = 'I have my own stay';
  static const String checkingStays = 'Checking stays...';
  static const String staysPaused = 'Stays are paused right now';
  static String noStaysHere(String city) => city.isEmpty ? 'No stays listed here yet' : 'No stays listed in $city yet';
  static String nightHasEnquiry(int day) => 'Night $day has an enquiry · withdraw it first';
  static String replaceOwnStay(String name) => name.isEmpty ? 'Replace your own stay?' : 'Replace your own stay $name?';
  static String noStayTitle(int day) => 'No stay on Night $day';
  static const String noStayHint = 'You can undo this any time';
  static const String noStaySleepElsewhere = 'Sleep elsewhere, leave next morning';
  static String leaveOnDay(int day) => 'I leave on Day $day';
  static const String leaveSameEvening = 'No stay, come back the same evening';

  static const String whenLeave = 'When do you leave?';
  static const String ownDatesTitle = 'Your own bookings';
  static const String ownDatesBody = 'These were set for the old dates. Keep them if you moved them too.';
  static String ownDatesRow(int day, bool stay, String name) {
    final what = stay ? 'Night $day · Own stay' : 'Day $day · Own taxi';
    return name.isEmpty ? what : '$what · $name';
  }

  static const String keepOwnPlans = 'Keep';
  static const String clearOwn = 'Clear them';
  static const String leaveChangeTitle = 'Change leave time?';
  static const String leaveChangeBody = 'These cars are set for the old time. Open asks will be withdrawn.';
  static String leaveCar(int car, String driver, bool booked) =>
      'Car $car · ${driver.isEmpty ? 'Driver' : driver} · ${booked ? 'booked' : 'asked'}';
  static const String notNow = 'Not now';
  static const String keepBookings = 'Keep bookings';
  static const String cancelBookings = 'Cancel bookings';
  static const String changeTime = 'Change';
  static String checkOutMorning(String? date) => date == null ? 'Check-out morning' : 'Check-out morning · $date';
  static String dayEvening(int day, String? date) => date == null ? 'Day $day evening' : 'Day $day evening · $date';
  static String leaveButStay(int day) => 'You chose to leave on Day $day but Night $day has a stay';

  static const String openStep = 'Open step';
  static const String payAdvance = 'Pay advance';
  static const String seeOffer = 'See offer';
}
