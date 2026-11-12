class TripStringsTab {
  static const String title = 'Trips';
  static const String searchHint = 'Search a city';
  static const String myTrips = 'My trips';
  static const String continueHeading = 'Continue your trip';
  static const String sectionTitle = 'Where to next?';
  static const String sectionSub = 'Pick a city to start planning';
  static const String all = 'All';
  static const String emptyTitle = 'No city found';
  static const String emptySub = 'Try another name';
  static const String errorTitle = 'Could not load cities';
  static const String errorSub = 'Check your connection and try again';
  static const String retry = 'Try again';
  static const String noCitiesTitle = 'No cities yet';
  static const String noCitiesSub = 'Trips are coming soon';
  static const String showAllStates = 'Show all states';
  static const String comingSoon = 'Coming soon';
  static const String clearSearch = 'Clear search';
  static String myTripsCount(int n) => n > 0 ? '$myTrips · $n' : myTrips;
  static String cityMeta(int spots) => '$spots ${spots == 1 ? 'place' : 'places'}';
}
