import 'utils/trip_travel_rules.dart';

class TripStringsMcbA1 {
  static const String travelRemoved = 'Travel removed';
  static const String bookFailed = "Couldn't save the booking. Try again.";
  static const String pickDateWithinYear = 'Pick a date within the next 365 days';
  static const String connectToFindWay = 'Connect to find a way';
  static const String addDatesFirst = 'Add your trip dates first';
  static const String taxiOffHere = 'Taxi not available here · add your own travel';

  static String stateLabel(TripTravelState s) => switch (s) {
        TripTravelState.notPlanned => 'Not planned yet',
        TripTravelState.gap => 'No driver found',
        TripTravelState.own => 'Own travel',
        TripTravelState.saved => 'Not asked yet',
        TripTravelState.asked => 'Asked',
        TripTravelState.free => 'Free',
        TripTravelState.partlyBooked => 'Partly booked',
        TripTravelState.booked => 'Booked by you',
        TripTravelState.confirmed => 'Confirmed by both',
        TripTravelState.dateChanged => 'Travel date changed',
        TripTravelState.carMissing => 'Car has no driver',
        TripTravelState.driverUnavailable => 'Driver unavailable',
      };
}
