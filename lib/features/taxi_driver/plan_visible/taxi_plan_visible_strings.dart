abstract final class TaxiPlanVisibleStrings {
  static const title = 'Choose your route';
  static String sub(int n) => n == 1 ? 'Free rings on 1 route' : 'Free rings on $n routes';
  static String route(String from, String to) => '$from to $to';
  static String line(bool roundTrip, String fare) => '${roundTrip ? 'Round trip' : 'One way'} · $fare';
  static const keptNote = 'Hidden routes are kept. They ring again as soon as you are on Plus.';
  static const threeADay = 'You can change this 3 times a day.';
  static const save = 'Save';
  static String a11yRow(String route, bool roundTrip, int fare, bool on) =>
      '$route, ${roundTrip ? 'round trip' : 'one way'}, $fare rupees${on ? ', selected' : ''}';
  static String a11yGroup(int n) => 'Choose your route, pick $n';
}
