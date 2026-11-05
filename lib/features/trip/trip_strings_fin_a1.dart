class TripStringsFinA1 {
  static const String peopleChangedTitle = 'Tell your drivers';
  static String tellDriverPeople(String driver, int people) =>
      people == 1 ? 'Tell $driver: now 1 person' : 'Tell $driver: now $people people';
  static const String callDriversAsked = 'Call the drivers you asked.';
  static String askHostAddNight(String host, int night) => 'Ask $host to add Night $night';
  static const String removeFromShortlist = 'Remove from shortlist';
  static const String growBlocked = 'Later cities have bookings · cancel them first';
}
