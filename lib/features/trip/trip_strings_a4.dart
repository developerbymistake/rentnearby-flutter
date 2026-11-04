class TripStringsA4 {
  static const String taxi = 'Taxi';
  static const String removeTaxi = 'Remove taxi?';
  static const String addPlaces = 'Add places';
  static const String addPlaceToSave = 'Add a place to save';
  static const String notBooked = 'Not booked';
  static const String findADriver = 'Find a driver';
  static String nightFindStay(int n) => 'Night $n · Find a stay';
  static String perDay(String price) => '$price/day';
  static const String rateOnRequest = 'Rate on request';
  static const String ownBooking = 'Own booking';

  static const String hintTitle = 'Add your stay and taxi';
  static const String hintBody = "Tap a day's tiles. Owners reply in chat.";
  static String noSupplyTitle(String city) =>
      city.isEmpty ? 'No Bakhli stays or drivers here yet' : 'No Bakhli stays or drivers in $city yet';
  static const String noSupplyBody = 'Add your own bookings so the plan is complete.';
  static String overLimitHint(int day) => 'Over the day limit. Day $day is long.';
  static const String dismiss = 'Dismiss';

  static const String days = 'Days';
  static const String auto = 'Auto';
  static const String daysHelp = 'Auto splits by driving time. Pick a number to force it.';
  static const String notSet = 'Not set';
  static const String peopleHelp = 'Owners see this in every enquiry.';

  static const String datesTitle = 'Bookings keep their dates';
  static String datesBody(int n) => n == 1
      ? '1 booking or enquiry will sit outside the new dates. Hosts and drivers are not moved. Tell them in chat or by call, or cancel.'
      : '$n bookings and enquiries will sit outside the new dates. Hosts and drivers are not moved. Tell them in chat or by call, or cancel.';

  static String hostsStillHave(String people, String rooms) =>
      rooms.isEmpty ? 'Hosts still have $people' : 'Hosts still have $people, $rooms';
  static const String sendChangeQ = 'Send a change request so the booking matches?';
  static const String later = 'Later';
  static const String sendChangeRequest = 'Send change request';
  static const String whichBooking = 'Which booking?';
  static const String openSentOld = 'Open enquiries were sent with the old numbers. Mention the change in chat.';

  static String removesDays(List<int> days) => days.length == 1
      ? 'This removes Day ${days.first} with a booking'
      : 'This removes Days ${days.join(', ')} with bookings';
  static const String removesDaysBody = 'Its bookings and enquiries keep their dates. Tell the owner in chat or cancel.';
  static const String keepAsIs = 'Keep as is';
  static const String keepRestDay = 'Keep day as rest day';
  static const String remove = 'Remove';

  static String runningTitle(int n, int total, String city) =>
      city.isEmpty ? 'Today · Day $n of $total' : 'Today · Day $n of $total · $city';
  static String tomorrowTitle(String city) => city.isEmpty ? 'Trip starts tomorrow' : 'Tomorrow · $city';
  static const String runningBody = "Tap for tonight's stay, taxi and Problem";
  static const String open = 'Open';

  static const String ready = 'Ready';
  static String supplyLine(int stays, int drivers) => 'Stays $stays · Drivers $drivers';
  static const String noSupplyLine = 'No Bakhli stays or drivers yet';
  static const String supplyChecking = 'Checking stays and drivers...';
  static const String supplyFailed = "Couldn't check stays and drivers";
  static const String planHere = 'Plan a trip here';

  static const String callHost = 'Call host';
  static const String callDriver = 'Call driver';

  static const String openPlayStore = 'Open Play Store';
  static const String readOnlyNote = 'Plan changes are off for this trip.';
}
