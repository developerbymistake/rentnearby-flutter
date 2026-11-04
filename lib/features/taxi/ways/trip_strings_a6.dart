import '../../trip/utils/trip_format.dart';
import '../taxi_option_sets.dart';
import 'models/taxi_ways_models.dart';

class TripStringsA6 {
  static const String askLimitTitle = 'Ask limit reached';
  static String askLimitBody(int minutes) =>
      'Up to 20 asks an hour and 60 a day. Try again in ${minutes < 1 ? 1 : minutes} min.';
  static String asksLeft(int n) => '$n asks left this hour';

  static String carsPerLeg(int n) => '$n cars per leg';
  static String? legSeats(WayLeg leg) => leg.carsNeeded <= 1 ? null : (leg.seatsNote ?? carsPerLeg(leg.carsNeeded));
  static String seatsNote(int? seats, int cars, int people) {
    final s = seats == null ? '' : 'Seats ${TaxiOptionSets.seatsLabel(seats)} · ';
    return '$s$cars cars for $people';
  }

  static const String journeyGoneTitle = 'Journey not available';
  static const String journeyGoneBody = 'Go back and pick a way again.';
  static const String goBack = 'Go back';
  static const String planEmptyTitle = 'No plan to show';
  static const String planEmptyBody = 'This plan has no cars yet. Try again.';
  static const String refreshFailedTitle = "Couldn't refresh the plan";
  static const String noLocation = 'Turn on location to see every way to go';

  static String waysLinkTitle(String city) => 'Every way to go to $city';
  static const String waysLinkBody = 'Cars, changes and local taxis';

  static String feedSubtitle(DateTime date, int people) =>
      '${TripFormat.dayMonth(date)} · ${people == 1 ? '1 person' : '$people people'}';
}
