import '../trip_strings_taxi_request.dart';
import 'taxi_result.dart';

class TaxiRequestErrors {
  static const String dayInPast = 'DayInPast';
  static const String sightseeingDaysInvalid = 'SightseeingDaysInvalid';

  static bool isSeatsError(String? type) => type == TaxiErrorTypes.seatsTooFew || type == TaxiErrorTypes.tooManyTravellers;

  static String seatsMessage(String? type) =>
      type == TaxiErrorTypes.tooManyTravellers ? TripStringsTaxiRequest.groupTooBig : TripStringsTaxiRequest.seatsTooFew;

  static String overlapMessage(String? tripName) =>
      TripStringsTaxiRequest.overlapIn(tripName == null || tripName.trim().isEmpty ? TripStringsTaxiRequest.anotherTrip : tripName.trim());

  static bool isDayInPast(String? type) => type == dayInPast || type == sightseeingDaysInvalid;

  static String dayInPastMessage(String? type) =>
      type == dayInPast ? TripStringsTaxiRequest.dayInPast : TripStringsTaxiRequest.pastDaysPicked;
}
