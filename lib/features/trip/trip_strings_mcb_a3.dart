class TripStringsMcbA3 {
  static String journeyCarOf(int i, int n) => n > 1 ? 'Journey car $i of $n' : 'Journey car';
  static String journeyLine(String carLabel, String from, String to, String date) =>
      [carLabel, '$from → $to', if (date.isNotEmpty) date].join(' · ');
  static String partOf(String title, int day) => 'Part of $title · Day $day';
  static const String partOfTrip = 'Part of your trip';
  static const String open = 'Open';
  static const String openTrip = 'Open trip';
  static String inYourTrip(int day) => 'In your trip · Day $day';
  static String alsoRemovedFromTravel(String city) => "It is also removed from your trip's travel to $city.";
  static String travelDay(String date) => 'Travel day · $date';
  static const String fareForCar = 'Fare for this car';
  static String pickupAt(String place) => 'Pickup at $place';
  static const String booked = 'Booked';
  static const String iBooked = 'I booked';
  static String carHeader(int i, String driver, String vehicle) =>
      ['Car $i', driver, if (vehicle.isNotEmpty) vehicle].join(' · ');
}
