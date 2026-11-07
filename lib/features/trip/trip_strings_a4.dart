class TripStringsA4 {

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

  static const String callHost = 'Call host';
  static const String callDriver = 'Call driver';

  static const String openPlayStore = 'Open Play Store';
}
