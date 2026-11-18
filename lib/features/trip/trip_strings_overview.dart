class TripStringsOverview {
  static const String title = 'Trip overview';
  static const String subtitle = 'Your plan is saved';
  static const String itinerary = 'Itinerary';
  static const String saved = 'Saved';
  static const String view = 'View';
  static const String taxi = 'Taxi';
  static const String taxiLine = 'Pickup, sightseeing, drop';
  static const String optional = 'Optional';
  static const String requested = 'Requested';
  static const String booked = 'Booked';
  static const String completed = 'Completed';
  static const String requestTaxi = 'Request taxi';
  static const String viewRequest = 'View request';
  static const String viewBooking = 'View booking';
  static const String skip = 'Skip, just keep my plan';
  static const String backToTrips = 'Back to my trips';
  static const String paused = 'Requests are paused right now';

  static String _n(int n, String one, String many) => '$n ${n == 1 ? one : many}';

  static String tripLine(int cities, int days, int travellers) => [
        _n(cities, 'city', 'cities'),
        _n(days, 'day', 'days'),
        if (travellers > 0) _n(travellers, 'traveller', 'travellers'),
      ].join(' · ');

  static String planLine(int days, int places) => '${_n(days, 'day', 'days')}, ${_n(places, 'place', 'places')}';
}
