class TripStringsV2Find {
  static const skip = 'Skip';
  static const call = 'Call';
  static const ask = 'Ask';
  static const asked = 'Asked';
  static const backToPlan = 'Back to plan';
  static const arrangeMyself = "I'll arrange myself";
  static const retry = 'Retry';

  static const datesTitle = 'When are you going?';
  static const datesSub = 'Asked once. Used for stay, taxi and ways.';
  static const pickNewDates = 'Pick new dates';
  static const datesPassedSub = 'Your start date has passed.';
  static const datesNote = 'You can change dates later from the plan.';
  static const startDate = 'Start date';
  static const adults = 'Adults';
  static const children = 'Children';
  static const showDrivers = 'Show drivers';
  static const showWays = 'Show ways';
  static const saveDates = 'Save';
  static String showStaysIn(String city) => 'Show stays in $city';
  static String daysBack(int days, String end) => '$days ${days == 1 ? 'day' : 'days'} · back $end';

  static const updateAskTitle = 'Update your ask?';
  static const updateAsk = 'Update ask';
  static const askNote = 'Ask sends one message to the host. Nothing is booked.';
  static const updateNote = 'Hosts and drivers are told the new dates.';
  static const updatePeopleNote = 'Hosts and drivers are told the new group size.';
  static const yourGroup = 'your group';
  static String updatePeopleBody(String kind, String old, String now) => 'Your $kind ask was for $old. You are now $now.';
  static String peopleChange(String old, String now) => 'Asked $old → $now';
  static const keepAsIs = 'Keep as is';
  static String updateAskBody(String kind, String old, String city, String nights, String now) =>
      'Your $kind ask was for $old. $city is now $nights, $now.';
  static String updateTaxiBody(String old, int days, String now) =>
      'Your taxi ask was for $old. Your trip is now ${days == 1 ? '1 day' : '$days days'}, $now.';
  static String askedChange(String old, String now) => 'Asked $old → $now';
  static String stayChange(String old, String now, int nights) => 'Asked $old → $now (${nightsText(nights)})';
  static String taxiLine(String name) => name.isEmpty ? 'Local taxi' : 'Local taxi · $name';
  static String dayRange(List<int> days) {
    final d = [...days]..sort();
    if (d.isEmpty) return '';
    if (d.length == 1) return 'Day ${d.first}';
    final run = d.last - d.first + 1 == d.length;
    return run ? 'Day ${d.first} to ${d.last}' : 'Day ${d.join(', ')}';
  }
  static const kindStay = 'stay';
  static const kindTaxi = 'taxi';
  static const nightsLabel = 'Nights';
  static String nightsText(int n) => '$n ${n == 1 ? 'night' : 'nights'}';
  static const pastNight = 'That night has passed';
  static const updateFailed = 'Could not update. Try again.';
  static const updated = 'Ask updated';
  static String confirmedRow(String name) => '$name is confirmed. You can ask for a change.';

  static String stayIn(String city) => 'Stay in $city';
  static String staySubtitle(int nights, String? range, String? people) =>
      [nightsText(nights), ?range, ?people].join(' · ');
  static const splitNote = 'Each night is asked on its own. Nothing is booked.';
  static const nightByNight = 'Night by night';
  static const alreadyBookedByPhone = 'Already booked by phone?';
  static const whichStay = 'Which stay?';
  static const pickBookedStay = 'Pick the stay you booked.';
  static String nightsLeft(int n) => '$n ${n == 1 ? 'night' : 'nights'} left to ask';
  static String sameStayFor(int nights) => nights == 2 ? 'Same stay for both nights' : 'Same stay for all nights';
  static String nightLabel(int n, String? date) => date == null ? 'Night $n' : 'Night $n · $date';
  static const noStaysTitle = 'No stays here yet';
  static String noStaysBody(String city) => 'No stays listed in $city yet. Use your own stay, or come back later.';
  static const staysPaused = 'Stays are paused right now';
  static const staysFailed = 'Could not load stays';
  static const checkConnection = 'Check your connection and try again.';
  static const noMatch = 'No stays match';
  static const clearFilters = 'Clear filters';

  static const taxiTitle = 'Local taxi';
  static String taxiSubtitle(String cities) => '$cities · one driver';
  static const taxiDays = 'DAYS YOU NEED A CAR';
  static const taxiDayNote = 'Untick a day to skip it.';
  static const noTaxiTitle = 'Taxi not available here';
  static const noTaxiBody = 'No local taxis listed here yet. Use your own taxi, or come back later.';
  static const taxisFailed = 'Could not load drivers';
  static const taxisPaused = 'Taxis are paused right now';
  static const perDayShort = 'per day';
  static String forDays(String total, int n) => '$total for $n ${n == 1 ? 'day' : 'days'}';
  static const pickDay = 'Choose at least one day';
  static const driverOneCity = 'Asked for one city only';
  static const veryShortNoticeDriver = 'Very short notice. Call the driver too.';

  static const offlineAsk = 'Connect to ask hosts and drivers';
  static const showLess = 'Show less';
  static String showAll(int n) => 'Show all $n';
  static const cancelFirstStay = 'Cancel the confirmed stay first.';
  static const cancelFirstTravel = 'Cancel the confirmed ride first.';
  static const cancelFirstTaxi = 'Cancel the confirmed taxi first.';
}
