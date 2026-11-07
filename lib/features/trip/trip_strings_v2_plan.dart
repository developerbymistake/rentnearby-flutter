import 'trip_constants.dart';
import 'utils/trip_days_rules.dart';

class TripStringsV2Plan {
  static const String trip = 'Trip';
  static const String map = 'Map';
  static const String done = 'Done';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String retry = 'Retry';
  static const String undo = 'Undo';

  static String headerSub(int days, int spots, int cities) {
    final d = days == 1 ? '1 day' : '$days days';
    final s = spots == 1 ? '1 spot' : '$spots spots';
    final c = cities == 1 ? '1 city' : '$cities cities';
    return '$d · $s · $c';
  }

  static String headerDated(int days, String dates, String? people) {
    final d = days == 1 ? '1 day' : '$days days';
    return people == null ? '$d · $dates' : '$d · $dates · $people';
  }

  static const String allCities = 'All';

  static String legChip(String city, int days) => '$city · ${days == 1 ? '1 day' : '$days days'}';

  static String headerRunning(int day, int days, String date) => 'Day $day of $days · $date';

  static const String paceRelaxed = 'Relaxed';
  static const String paceNormal = 'Normal';
  static const String paceRelaxedHint = 'About 5 h a day';
  static const String paceNormalHint = 'About 7.5 h a day';
  static const String paceTitle = 'Pace';
  static const String paceSub = 'How much to fit in a day. Your order stays as it is.';
  static const String paceFooter = 'Days are recalculated. Nothing is reordered.';

  static String arranged(int done, int total) => '$done of $total arranged';
  static const String nothingToArrange = 'Nothing to arrange';
  static const String hintStayWaiting = 'Stay is waiting for a reply';
  static const String hintTaxiWaiting = 'Taxi is waiting for a reply';
  static const String hintWaiting = 'Waiting for a reply';
  static const String hintOffer = 'You have an offer to review';
  static const String hintAttention = 'Something needs your attention';
  static const String hintDatesChanged = 'Dates changed';
  static const String hintSavedOnPhone = 'Saved on this phone';
  static const String hintAllSet = 'All set';
  static const String hintMakeItEasy = 'Make it easy below';

  static const String offlineBanner = 'Offline. Your plan is saved on this phone.';

  static String dayHeader(int day, String? date, String hours) =>
      date == null ? 'Day $day · $hours' : 'Day $day · $date · $hours';
  static String dayHeaderEmpty(int day, String? date) => date == null ? 'Day $day' : 'Day $day · $date';
  static const String noPlacesThisDay = 'No places this day';
  static const String restDay = 'Rest day';
  static String travelRow(String from, String to, String duration) => '$from to $to · $duration';

  static const String renameTitle = 'Rename trip';
  static const String tripName = 'Trip name';
  static const String menuSaveExit = 'Save & exit';
  static const String menuEditDays = 'Edit days';
  static const String menuEditDates = 'Edit dates and people';
  static const String menuRename = 'Rename trip';
  static const String menuSummary = 'Trip summary';
  static const String menuMap = 'Map of trip';
  static const String menuMute = 'Mute reminders';
  static const String menuMuteSub = 'Event alerts still come';
  static const String menuComplete = 'Mark trip complete';
  static const String menuDelete = 'Delete trip';

  static const String savedTitle = 'Your plan is saved';
  static const String savedBody = 'Continue anytime from My Trips.';
  static const String keepPlanning = 'Keep planning';
  static const String goToMyTrips = 'Go to My Trips';
  static const String saveFailed = 'Could not save. Try again.';

  static const String deleteTitle = 'Delete this trip?';
  static const String deleteBody = 'This cannot be undone.';
  static String openEnquiries(int n) => n == 1 ? '1 open enquiry will be withdrawn.' : '$n open enquiries will be withdrawn.';
  static String confirmedStays(int n) =>
      n == 1 ? '1 confirmed stay is cancelled and the host is told.' : '$n confirmed stays are cancelled and the host is told.';
  static String confirmedTaxis(int n) =>
      n == 1 ? '1 confirmed taxi is cancelled and the driver is told.' : '$n confirmed taxis are cancelled and the driver is told.';
  static const String keepTrip = 'Keep trip';
  static const String delete = 'Delete';

  static const String addPlace = 'Add a place';
  static const String addDay = 'Add a day';
  static const String removeDay = 'Remove day';
  static const String makeRestDay = 'Make it a rest day';
  static const String undoRestDay = 'Add places again';
  static const String placeRemoved = 'Place removed';
  static const String removePlace = 'Remove place';
  static const String dayFull = 'This day has 6 places. Move one to another day or add a day.';
  static const String removePlacesFirst = 'Remove places first';
  static const String lastDay = 'A trip needs at least one day';
  static const String readOnlyDay = 'This day cannot be changed';
  static const String maxDays = 'This is the longest trip we can plan';
  static String moveTitle(String name) => 'Move $name';
  static const String removeFromTrip = 'Remove from trip';
  static const String dayIsFull = 'Full';
  static String placesCount(int n) => n == 1 ? '1 place' : '$n places';

  static const String daysTitle = 'How many days?';
  static const String daysSub = 'Places are shared across your cities.';
  static String daysHint(int days) => 'Up to ${TripDaysRules.total(days)} places for $days days (${TripConstants.maxSpotsPerDay} a day)';
  static String daysMinHint(int min) => min == 1 ? 'At least 1 day' : 'At least $min days for your places';
  static String days(int n) => n == 1 ? '1 day' : '$n days';
  static const String apply = 'Apply';
  static const String daysLocked = 'Days that are running or past stay as they are.';
  static const String daysBookings = 'Cancel the bookings of a city first to shorten it.';

  static const String noPlanTitle = 'No places yet';
  static const String noPlanSub = 'Add a place to start your plan.';
  static const String editBanner = 'Drag to reorder. Tap × to remove.';

  static const String myTripsContinue = 'Continue planning';
  static const String myTripsSummary = 'View summary';
  static String myTripsArranged(int done, int total) => '$done of $total arranged';
  static String myTripsDaysNoDates(int days) => '${days == 1 ? '1 day' : '$days days'} · dates not set';
  static String waitingForReply(int n) => '$n waiting for a reply';
  static String needsYou(int n) => n == 1 ? '1 needs you' : '$n need you';

  static const String rowGettingThere = 'Getting there';
  static const String rowComingBack = 'Coming back';
  static String rowStay(String city) => 'Stay in $city';
  static const String rowTaxi = 'Local taxi';
  static const String rowCityChange = 'City change';

  static const String confirmedShort = 'Confirmed';
  static const String bookedByYouHost = 'Booked by you · host not confirmed';
  static const String bookedByYouDriver = 'Booked by you · driver not confirmed';
  static const String todayYourTravel = 'You will arrange your travel';
  static const String longDay = 'Long day';
}
