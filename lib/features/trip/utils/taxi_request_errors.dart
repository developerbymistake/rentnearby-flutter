import '../trip_strings_taxi_request.dart';

class TaxiRequestErrors {
  static const String dayInPast = 'DayInPast';
  static const String sightseeingDaysInvalid = 'SightseeingDaysInvalid';

  static bool isDayInPast(String? type) => type == dayInPast || type == sightseeingDaysInvalid;

  static String dayInPastMessage(String? type) =>
      type == dayInPast ? TripStringsTaxiRequest.dayInPast : TripStringsTaxiRequest.pastDaysPicked;
}
