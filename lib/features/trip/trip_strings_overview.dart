class TripStringsOverview {
  static const String title = 'Trip overview';
  static const String subtitle = 'Your plan is saved';
  static const String itinerary = 'Itinerary';
  static const String saved = 'Saved';
  static const String view = 'View';
  static const String taxi = 'Taxi';
  static const String findTaxi = 'Find taxi';
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
  static const String viewPlan = 'View plan';
  static const String moreOptions = 'More options';
  static const String back = 'Back';
  static const String stay = 'Stay';
  static const String bookYourStay = 'Book your stay';
  static const String stayLine = 'Homestays and resorts';
  static const String addStay = 'Find a stay';
  static const String viewStays = 'View stays';
  static const String added = 'Added';
  static const String stayCityTitle = 'Stay in which city?';
  static const String exitTitle = 'Exit trip?';
  static const String exitBody = 'Your trip is saved. Continue any time from Trips.';
  static const String exit = 'Exit';
  static const String keepPlanning = 'Keep planning';
  static const String progressBothOpen = 'Itinerary saved. Taxi and stay are optional.';
  static const String progressStayOpen = 'Stay not added yet.';
  static const String progressTaxiOpen = 'Taxi not added yet.';
  static const String progressAllSet = 'All set.';
  static const String progressNoPlan = 'Add places to your plan.';
  static String progressLabel(int percent, String status) => 'Plan progress, $percent percent. $status';
  static String nextLabel(String title) => '$title, next';
  static String cardLabel(String title, String action) => '$title, $action';

  static String _n(int n, String one, String many) => '$n ${n == 1 ? one : many}';

  static String tripLine(int cities, int days, int travellers) => [
        _n(cities, 'city', 'cities'),
        _n(days, 'day', 'days'),
        if (travellers > 0) _n(travellers, 'traveller', 'travellers'),
      ].join(' · ');

  static String staysAsked(int n, String? city) => '${_n(n, 'stay', 'stays')} asked${city == null ? '' : ' in $city'}';

  static String planLine(int days, int places) => '${_n(days, 'day', 'days')}, ${_n(places, 'place', 'places')}';
}
