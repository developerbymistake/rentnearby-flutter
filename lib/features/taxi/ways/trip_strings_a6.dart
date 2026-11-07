import '../../trip/utils/trip_format.dart';
import '../taxi_option_sets.dart';
import 'models/taxi_ways_models.dart';

class TripStringsA6 {
  static const String askLimitTitle = 'Ask limit reached';
  static String askLimitBody(int minutes) =>
      'Up to 20 asks an hour and 60 a day. Try again in ${minutes < 1 ? 1 : minutes} min.';
  static String asksLeft(int n) => '$n asks left this hour';

  static String carsPerLeg(int n) => '$n cars for each drive';
  static String? legSeats(WayLeg leg) => leg.carsNeeded <= 1 ? null : (leg.seatsNote ?? carsPerLeg(leg.carsNeeded));
  static String seatsNote(int? seats, int cars, int people) {
    final s = seats == null ? '' : 'Seats ${TaxiOptionSets.seatsLabel(seats)} · ';
    return '$s$cars cars for $people';
  }

  static const String journeyGoneTitle = "Couldn't open this journey";
  static const String journeyGoneBody = 'The ways list changed. Your picks are safe.';
  static const String backToWays = 'Back to ways to go';
  static const String goBack = 'Go back';
  static const String waysGoneBody = 'Go back and search again.';
  static const String planGoneTitle = 'This plan has changed';
  static const String planGoneBody = 'Go back to ways to go and pick it again.';
  static const String planEmptyTitle = 'No plan to show';
  static const String planEmptyBody = 'This plan has no cars yet. Try again.';
  static const String refreshFailedTitle = "Couldn't refresh the plan";
  static const String noLocation = 'Turn on location to see every way to go';

  static String feedSubtitle(DateTime date, int people) =>
      '${TripFormat.dayMonth(date)} · ${people == 1 ? '1 person' : '$people people'}';
}
