import 'utils/trip_format.dart';

class TripStringsMcdA3 {
  static String todayDayCity(int n, int total, String city) => 'Today · Day $n of $total · $city';
  static String todayTravelDay(int n, int total) => 'Today · Day $n of $total · Travel day';
  static const String travelDayCaps = 'TRAVEL DAY';
  static String carRow(String name, int i) => '$name · Car $i';
  static String toPlace(String place) => 'to $place';
  static String checkOut(String name) => 'Check out · $name';
  static const String thisMorning = 'This morning';
  static String tonightTitle(String name) => 'Tonight · $name';
  static const String todaysRoad = "Today's road";
  static String roadLine(int minutes) => 'about ${TripFormat.duration(minutes)} · $noPlacesToday';
  static const String longRoad = 'Long road · $noPlacesToday';
  static const String noPlacesToday = 'no places today';
  static String travelHead(String to, int cars) =>
      cars <= 0 ? '→ $to' : (cars == 1 ? '→ $to · 1 car' : '→ $to · $cars cars');
  static String travelHeadOwn(String to) => '→ $to · Own travel';
  static String travelLine(String date) => 'Travel · $date';
  static String carCandidate(int i, String name) => 'Car $i · $name';
  static const String ownTravel = 'Own travel';
  static const String travelHeadFallback = 'Travel';
}
