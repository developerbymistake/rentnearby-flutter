import '../taxi/requests/models/driver_request_models.dart';

class TripStringsTaxiDriver {
  static const String stateBooked = 'Booked';
  static const String stateMissed = 'Missed';
  static const String stateNotSelected = 'Not selected';
  static const String stateClosed = 'Closed';
  static const String stateOccupied = 'Occupied';
  static const String stateCompleted = 'Completed';
  static const String missedNote = 'Went to the next drivers';
  static const String notSelectedNote = 'Traveller chose another driver';

  static const String traveller = 'Traveller';
  static const String sectionPickup = 'Pickup';
  static const String sectionDrop = 'Drop';

  static const String decline = 'Decline';
  static const String accept = 'Accept';
  static const String confirmBooking = 'Confirm booking';
  static const String callTraveller = 'Call traveller';

  static const Map<ReasonChip, String> reasonChips = {
    ReasonChip.changedPlan: 'Changed plan',
    ReasonChip.notReachable: 'Not reachable',
    ReasonChip.priceNotAgreed: 'Price not agreed',
    ReasonChip.vehicleIssue: 'Vehicle issue',
    ReasonChip.other: 'Other',
  };

  static const List<ReasonChip> reasonOrder = [
    ReasonChip.changedPlan,
    ReasonChip.notReachable,
    ReasonChip.priceNotAgreed,
    ReasonChip.vehicleIssue,
    ReasonChip.other,
  ];

  static String reasonLabel(ReasonChip chip) => reasonChips[chip] ?? reasonChips[ReasonChip.other]!;

  static String pickupCity(String city) => '$city pickup';

  static String sectionSightseeing(int days) => 'Sightseeing $days ${days == 1 ? 'day' : 'days'}';

  static String lengthLine(int days, int nights, String from, String to) =>
      '$days ${days == 1 ? 'day' : 'days'} · $nights ${nights == 1 ? 'night' : 'nights'} · $from to $to';

  static String fromToCities(String from, List<String> cities, {int more = 0}) {
    final list = cities.join(', ');
    return '$from to $list${more > 0 ? ' +$more' : ''}';
  }

  static String seatsLine(int seats, int travellers) =>
      '$seats seater · $travellers ${travellers == 1 ? 'traveller' : 'travellers'}';
}
