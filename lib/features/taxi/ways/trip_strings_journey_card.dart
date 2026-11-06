class TripStringsJourneyCard {
  static String reachCity(String city) => 'How will you reach $city?';
  static String getBackTo(String start) => start.isEmpty ? 'How will you get back?' : 'How will you get back to $start?';
  static String goTo(String city) => 'How will you go to $city?';

  static const String addDatesToAsk = 'Add dates to ask';
  static const String addDatesBody = 'Drivers need a date. You can still choose your own way.';
  static const String addDates = 'Add dates';

  static const String startsFrom = 'START';
  static String fromPlace(String name) => 'From $name';
  static const String startNotSet = 'Starting city not set';
  static const String pickStart = 'Pick your starting city';
  static const String change = 'Change';

  static const String findTaxi = 'Find a taxi';
  static const String otherWays = 'Other ways';
  static const String changeWay = 'Change way';
  static const String seeReplies = 'See replies';
  static const String openJourney = 'Open journey';
  static const String arrangeMyself = 'I will arrange it myself';
  static const String undo = 'Undo';
  static const String edit = 'Edit';
  static const String removeTravel = 'Remove travel';
  static const String searchAgain = 'Search again';
  static String askDrivers(int cars) => cars <= 1 ? 'Ask the driver' : (cars == 2 ? 'Ask both drivers' : 'Ask $cars drivers');
  static String ownLine(String? how) => how == null || how.isEmpty ? arrangeMyself : '$arrangeMyself · $how';

  static const String noTaxiHere = 'No taxi listed on this road yet';
  static const String noTaxiBody = 'Arrange it yourself, or search again later.';

  static String carTitle(int car, String to) => 'Car $car · to $to';
  static const String carNotAsked = 'Not asked';
  static const String carAsked = 'Waiting for driver';
  static const String carFree = 'Free · book it';
  static const String carBookedByYou = 'Booked by you · driver not confirmed';
  static const String carConfirmed = 'Confirmed';
  static const String carOwn = 'Your own';
  static const String carNotAvailable = 'No driver';
  static const String carNoReply = 'No reply';
  static const String carPaused = 'Driver paused';
  static const String call = 'Call';
  static String useBackup(String name) => 'Use backup $name';
  static const String findAnotherCar = 'Find another car';
  static String arrangeCar(int car) => 'I will arrange car $car myself';
  static String cancelBookingQ(String driver) => "Cancel $driver's booking?";
  static const String cancelBookingBody = 'The driver is told at once.';
  static const String cancelBooking = 'Cancel booking';
  static String cancelDriverBooking(String driver) => "Cancel $driver's booking";
  static const String keepBooking = 'Keep booking';
  static const String carClosedFailed = "Couldn't update this car. Try again.";

  static const String arrangeTitle = 'Arrange it yourself?';
  static const String arrangeBody = 'Drivers you asked are told you no longer need them.';
  static const String bookedCars = 'Booked cars';
  static const String keep = 'Keep';
  static const String cancel = 'Cancel';
  static String carDriver(int car, String driver) => 'Car $car · $driver';
  static const String continueLabel = 'Continue';
  static const String keptCarsNote = 'Kept cars stay booked. The other cars are yours to arrange.';

  static const String startChanged = 'Start changed';
  static String searchFromAgain(String city) => city.isEmpty ? 'Search the way again?' : 'Search the way again from $city?';
  static const String later = 'Later';

  static const String yourOwnTravel = 'I will arrange it myself';
  static const String noteOptional = 'How you will travel (optional)';
  static const String save = 'Save';
}
