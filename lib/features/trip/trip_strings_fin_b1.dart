import 'utils/trip_format.dart';

class TripStringsFinB1 {
  static String onTheRoad(int minutes) => 'about ${TripFormat.duration(minutes)} on the road';

  static String roomLine(String room, String? guests) => guests == null ? room : '$room, $guests';
  static const String groundFloor = 'Ground floor';
  static String askedWaiting(String ago) => ago.isEmpty ? 'Asked · waiting for the host' : 'Asked $ago · waiting for the host';
  static String offeredTotal(String total) => 'Offered $total';
  static const String nothingShortlisted = 'Nothing shortlisted';
  static const String morning = 'morning';
  static const String keepIt = 'Keep it';
  static const String newStay = 'New stay';
  static String baseStayLine(int first, int last, String out) => first == last
      ? 'Base stay for Night $first · out $out'
      : 'Base stay for Nights $first–$last · out $out';
  static String ownTaxiCityHint(String city) => 'Days in $city only';
  static String agreedFare(String fare) => 'Fare $fare · agreed';
  static const String checkOutDay = 'Check-out day';
}
