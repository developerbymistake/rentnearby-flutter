import '../buddy/shared/buddy_format.dart';

class TripStringsArchived {
  static const String archivedTag = 'Archived';
  static const String title = 'Trip summary';
  static const String note = 'Plan removed after 3 months. Summary kept.';
  static const String routeTitle = 'Route';
  static const String taxiBooked = 'Taxi booked';
  static const String archivedRefused = 'This trip is archived. Only its summary is kept.';

  static String nights(int n) => n == 1 ? '1 night' : '$n nights';

  static String cityLine(String city, int nights) => nights > 0 ? '$city · ${TripStringsArchived.nights(nights)}' : city;

  static String moreSpots(int n) => '+$n more';

  static String citiesTitle(String first, String last, int count) => count == 2 ? '$first & $last' : '$first to $last';

  static String stays(List<String> names) => 'Stay: ${names.join(', ')}';

  static String daysPlaces(int days, int places) => [
        if (days > 0) days == 1 ? '1 day' : '$days days',
        if (places > 0) places == 1 ? '1 place' : '$places places',
      ].join(' · ');

  static String spent(int rupees) => 'Spent ${BuddyFormat.rupees(rupees)}';
}
