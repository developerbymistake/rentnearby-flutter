import 'models/trip_plan_model.dart';

class TripStringsStepsA1 {
  static String stepLabel(TripStepDisplay d) => switch (d) {
        TripStepDisplay.notStarted => 'Not started',
        TripStepDisplay.asked => 'Asked',
        TripStepDisplay.chosen => 'Chosen',
        TripStepDisplay.booked => 'Booked by you',
        TripStepDisplay.own => 'Own booking',
        TripStepDisplay.skipped => 'Skipped',
        TripStepDisplay.notNeeded => 'Not needed',
      };

  static const String planned = 'Planned';

  static String stepName(TripStepKind k) => switch (k) {
        TripStepKind.itinerary => 'Itinerary',
        TripStepKind.gettingThere => 'Getting there',
        TripStepKind.stay => 'Stay',
        TripStepKind.localTaxi => 'Local taxi',
        TripStepKind.comingBack => 'Coming back',
      };

  static String roleName(TripStepRole r) =>
      stepName(r == TripStepRole.gettingThere ? TripStepKind.gettingThere : TripStepKind.comingBack);

  static const String noTaxiThisDay = 'No taxi this day';
  static const String savedToTrip = 'Saved to your trip';
  static const String savedToJourneys = 'Saved to My journeys';
  static const String removedFromTrip = 'Removed from your trip';
  static const String pickStartFirst = 'Pick where you start first';

  static String sortedOf(int n, int total) => '$n of $total sorted';
}
