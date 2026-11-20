class TaxiRouteStrings {
  static const String fromCity = 'From city';
  static const String toCity = 'To city';
  static const String sheetSub = 'Travellers ask for taxis by city';
  static const String otherPlace = 'Other place';
  static const String searchCity = 'Search city';
  static const String chooseCity = 'Choose a city';
  static const String activeInRequests = 'Active in requests';
  static const String notActive = 'Not active: choose the city';
  static const String otherPlaceNote = 'Not active in requests: choose a city';
  static const String citiesFailed = 'Could not load cities. Please try again.';
  static const String noCities = 'No cities yet';
  static const String chooseFromAgain = 'Choose the From city from the list';
  static const String chooseToAgain = 'Choose the To city from the list';

  static String noCityMatch(String q) => 'No city matches "$q"';
}
