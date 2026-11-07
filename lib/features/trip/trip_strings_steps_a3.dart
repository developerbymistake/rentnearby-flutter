import 'trip_state_labels.dart';
import 'utils/trip_format.dart';

class TripStringsStepsA3 {
  static const String gettingThere = 'Getting there';
  static const String gettingThereCaps = 'GETTING THERE';
  static const String comingBackCaps = 'COMING BACK';
  static const String useForMyTrip = 'Use for my trip';
  static const String arrangeMyself = TripStateLabels.arrangeMyself;
  static const String inYourTrip = 'In your trip';
  static const String alsoRemovedFromTrip = 'It is also removed from your trip.';

  static const String seeWays = 'See ways to go';
  static const String noWaysYet = 'No ways yet';
  static const String waysFailed = "Couldn't load";
  static const String waysOffline = 'No signal. Try again when you are online.';
  static const String retry = 'Retry';

  static String fromTo(String from, String to) => 'From $from to $to';
  static String localTaxisIn(String city) => 'Local taxis in $city';
  static String waysSummary({required int direct, required int directFrom, required int cars, required int carsFrom}) {
    final all = direct == 1 ? '1 way: all the way' : '$direct ways: all the way';
    return '$all from ${_inr(directFrom)}, or in $cars cars from about ${_inr(carsFrom)}';
  }

  static String directOnly(int direct, int from) =>
      direct == 1 ? '1 way: all the way from ${_inr(from)}' : '$direct ways: all the way from ${_inr(from)}';
  static String noDirect(int cars) => 'No driver goes all the way. The best way is $cars cars.';

  static String _inr(int v) {
    final s = v.toString();
    if (s.length <= 3) return '₹$s';
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '₹${parts.join(',')},${s.substring(s.length - 3)}';
  }

  static const String todayGettingThere = 'GETTING THERE · TODAY';
  static const String todayComingBack = 'COMING BACK · TODAY';
  static String travelDay(DateTime d) => 'Travel day · ${TripFormat.dayMonth(d)}';
  static String changeCarAt(String place) => 'Change car at $place';
  static String nextDriver(String name) => 'Your next driver is $name';
  static String takesYou(String name, String to) => '$name takes you to $to';
  static String pausedBackup(String name, String? backup) =>
      backup == null || backup.isEmpty ? '$name paused his taxi.' : '$name paused his taxi. Backup: $backup';
  static const String call = 'Call';
  static const String whatsApp = 'WhatsApp';

  static String routeLine(List<String> places) => places.join(' → ');
  static String carsLine(int cars) => cars == 1 ? '1 car' : '$cars cars';
  static String aboutTotal(String price) => 'about $price';
  static String carRow(int n, String driver) => 'Car $n $driver';
  static String changeCarShort(String place) => 'change car at $place';
}
