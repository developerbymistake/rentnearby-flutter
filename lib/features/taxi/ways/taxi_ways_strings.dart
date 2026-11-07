import '../../../models/browse_item.dart';
import '../../trip/utils/trip_format.dart';
import '../taxi_option_sets.dart';

class TaxiWaysStrings {
  static const String title = 'Ways to go';
  static String subtitle(String from, String to) => '$from → $to';
  static String dateChip(DateTime d) => TripFormat.shortDate(d);
  static String peopleChip(int n) => '$n people';
  static String people(int n) => n == 1 ? '1 person' : '$n people';
  static const String today = 'Today';
  static const String tomorrow = 'Tomorrow';
  static const String fromMyLocation = 'my location';
  static const String fromLabel = 'FROM';
  static const String toLabel = 'TO';
  static const String fromMyLocationLabel = 'FROM · MY LOCATION';

  static const String sortLabel = 'Sort';
  static const String fewestCars = 'Fewest cars';
  static const String lowestPrice = 'Lowest price';

  static const String bestWay = 'BEST WAY';
  static const String bestDriverReason = '1 car, all the way';
  static const String bestBasedHereReason = '1 car, based here';
  static String orPlaces(List<String> places) => places.join(' or ');
  static String bestPlanReason(int changes, int total) =>
      '$changes ${changes == 1 ? 'change' : 'changes'}, about ${BrowseItem.inr(total)}';
  static const String noDirect2 = 'No driver goes all the way. The best way is 2 cars.';
  static const String noDirect3 = 'No driver goes all the way, and no 2-car plan exists. This needs 3 cars.';
  static String orInCars(int n) => 'Or in $n cars';
  static String cheaperOneChange(String place) => 'cheaper, one change at $place';
  static String planName(int index) => 'Plan ${String.fromCharCode(65 + index.clamp(0, 25))}';
  static String carsAbout(int n, int total) => '$n cars · about ${BrowseItem.inr(total)}';
  static const String oneCar = '1 car';
  static String carsCount(int n) => n <= 1 ? oneCar : '$n cars';
  static String oneCarTotal(int total) => '$oneCar · ${BrowseItem.inr(total)}';
  static const String changeCar = 'change car';
  static const String openJourney = 'Open journey';
  static String moreDrivers(int n) => '+$n more';
  static String otherDrivers(int n) => '$n other drivers';
  static const String basedHere = 'based here';
  static const String repliesInApp = 'replies in app';

  static const String yourJourney = 'Your journey';
  static const String youStart = 'You start';
  static const String youArrive = 'You arrive';
  static const String changeCarHere = 'Change car here';
  static const String meetNext = 'Meet the next driver here';
  static const String viewOnRoad = 'View on road';
  static const String onTheRoad = 'On the road';
  static String passes(List<String> places) => 'Passes ${places.join(' · ')}';
  static String aboutKm(num km) => 'about ${km.round()} km';
  static const String noRoadLine = 'Road line not available here';
  static const String listedFares = 'Listed fares. Each driver confirms his own.';
  static String carOf(int i, int n) => 'Car $i of $n';
  static String comesFrom(String place) => 'Comes from $place with another driver';

  static const String askBoth = 'Ask both drivers if they are free';
  static String askAll(int n) => 'Ask all $n drivers if they are free';
  static String askThese(int n) => 'Ask these $n drivers if they are free';
  static const String askOne = 'Ask this driver if he is free';
  static const String payLine = 'Pay each driver directly. Bakhli does not take or hold payment.';
  static const String call = 'Call';
  static const String whatsApp = 'WhatsApp';
  static const String saveJourney = 'Save journey';
  static const String saved = 'Journey saved';

  static const String changeDriver = 'Change driver';
  static String driversOn(String from, String to, int n) => '$from → $to · $n drivers';
  static const String seats6 = '6+ seats';
  static const String suv = 'SUV';
  static String bestFitFirst(int people, int shown, int total) =>
      'Best fit for $people people first. Showing $shown of $total';
  static const String current = 'current';
  static const String lowestTag = 'lowest price';
  static String showMore(int n) => 'Show $n more';
  static String showingCount(int shown, int total) => 'Showing $shown of $total';
  static String seatsCount(int n) => '${TaxiOptionSets.seatsLabel(n)} seats';
  static const String noDriversMatch = 'No driver matches';
  static const String noDriversMatchBody = 'Try removing a filter';

  static const String savedJourney = 'Saved journey';
  static const String savedOnPhone = 'Contacts saved on this phone';
  static const String refresh = 'Refresh';
  static String backup(List<String> names) => 'Backup: ${names.join(', ')}';
  static String checkedAgo(String ago) => 'Checked $ago';
  static const String worksOffline = 'Works without internet: names, numbers and the plan are on your phone.';
  static const String offlineSaved = 'Offline · showing saved details';

  static const String myJourneys = 'My journeys';
  static const String myJourneysTile = 'My journeys';
  static const String noJourneys = 'No journeys yet';
  static const String noJourneysBody = 'Save a journey from Ways to go';
  static String journeyLine(DateTime date, int cars, int people) =>
      '${TripFormat.shortDate(date)} · $cars ${cars == 1 ? 'car' : 'cars'} · ${TaxiWaysStrings.people(people)}';
  static const String statusReady = 'Ready';
  static String statusUnavailable(int n) => '$n ${n == 1 ? 'driver' : 'drivers'} unavailable';
  static const String statusNotAsked = 'Not asked yet';
  static const String statusCompleted = 'Completed';
  static String pausedBody(String name, String backup) => '$name paused his taxi. Backup ready: $backup.';
  static String pausedNoBackup(String name) => '$name paused his taxi. Pick another driver.';
  static String replaceWith(String name) => 'Replace with $name';
  static const String open = 'Open';
  static const String askDrivers = 'Ask drivers';
  static const String markDone = 'Mark done';
  static const String deleteJourney = 'Delete journey';
  static String legFree(String ago) => 'Free · asked $ago';
  static const String legNotFree = 'Not available';
  static String legNoAnswer(String ago) => 'No answer yet · asked $ago';
  static const String legNotAsked = 'Not asked yet';
  static String fareChanged(int old, int now) => 'Fare changed: ${BrowseItem.inr(old)} → ${BrowseItem.inr(now)}';

  static String atPlace(String city) => 'At $city';
  static String localTaxis(int n) => 'Local taxis · $n';
  static const String localTag = 'Local';
  static String perDay(int x) => '${BrowseItem.inr(x)} / day';
  static const String viewAndCall = 'View & call';
  static String stayIn(String city) => 'Stay in $city';
  static String staysCount(int n, DateTime date) => '$n stays · ${TripFormat.shortDate(date)}';
  static String perNight(int x) => '${BrowseItem.inr(x)} / night';
  static const String askRoom = 'Ask for a room';
  static String roomAskMessage(String city, DateTime date, int people) =>
      'Hi, I reach $city on ${TripFormat.shortDate(date)}, ${TaxiWaysStrings.people(people)}. Is a room free?';
  static String reachBy(String place) => 'Reach $place by train or bus';
  static const String reachBody = 'Drivers start from there';
  static const String waysAbove = '↑ the ways to go are above';

  static const String entryTitle = 'Every way to go';
  static String entryBody(String to) => 'In 1, 2 or 3 cars, local taxis and stays at $to';
  static const String entryEmptyTitle = 'No driver goes all the way';
  static const String entryEmptyBody = 'See 2 or 3-car plans';

  static const String offlineTitle = "You're offline";
  static const String offlineBody = 'Check your connection and try again';
  static const String loadFailed = "Couldn't load ways to go";
  static const String retry = 'Retry';
  static const String noWays = 'No way found yet';
  static String noWaysBody(String to) => 'No driver reaches $to from here yet';

  static String asked(int n) => n == 1 ? 'Asked 1 driver' : 'Asked $n drivers';
  static String askBackups(int n) => n == 1 ? '+1 backup' : '+$n backups';
  static const String saveFailed = "Couldn't save this journey. Try again.";
  static const String askFailed = "Couldn't ask drivers. Try again.";
  static const String askPaused = 'Asking is paused right now';
  static const String taxisOff = 'Taxis are not available right now';
  static const String journeyLimit = 'Up to 20 saved journeys';

  static const String nudgeTitle = 'Get more calls';
  static const String nudgeBody = 'Add popular routes like Haridwar to Badrinath';

  static String ago(DateTime at, {DateTime? now}) {
    final d = (now ?? DateTime.now()).difference(at);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}
