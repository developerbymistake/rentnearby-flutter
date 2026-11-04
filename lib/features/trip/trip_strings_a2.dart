class TripStringsA2 {
  static const String taxi = 'Taxi';
  static const String stay = 'Stay';
  static const String staysOff = 'Stays are off in this area right now';
  static const String taxisOff = 'Taxis are off in this area right now';

  static const String maxPrice = 'Max price';
  static const String anyPrice = 'Any price';
  static String underPrice(String amount) => 'Under $amount';
  static const String priceSheetTitle = 'Max price per night';
  static const String homestay = 'Homestay';
  static const String hostel = 'Hostel';
  static const String clearFilters = 'Clear filters';
  static const String noMatchTitle = 'No stays match';
  static const String noMatchBody = 'Try another price or stay type.';

  static String guests(int n) => n == 1 ? '1 guest' : '$n guests';
  static String checkIn(String time) => 'Check-in $time';
  static const String perNightListed = 'per night, listed';
  static const String priceOnRequest = 'Price on request';
  static const String featured = 'Featured';
  static const String asked = 'Asked';
  static String counter(int n, {required bool withAsked}) =>
      withAsked ? '$n of 3 asked or shortlisted' : '$n of 3 shortlisted';

  static const String sendEnquiry = 'Send enquiry';

  static String nightChip(int n) => 'Night $n';
  static String dayChip(int n) => 'Day $n';

  static const String forThisNight = 'For this night';
  static const String noBaseStay = 'Pick a stay for last night first';
  static const String travellingBody = 'Travelling. No stay is needed this night.';
  static String sameStayBody(String name) => '$name. Tap Night by night to change it.';
  static const String nightPassed = 'This night has passed';
  static const String tripLocked = 'Plan changes are off for this trip.';
  static const String cancelFirstBody = 'This night is booked. Cancel the booking, then add your own stay.';
  static const String cancelBooking = 'Cancel booking';

  static const String haveTaxi = 'I already have a taxi';
  static String allNightsOwn(int n) => 'All $n nights';
  static const String allNightsOwnBody = 'Same stay until check-out';
  static const String farePerDay = 'Fare per day (optional)';
  static const String days = 'Days';
  static const String pickADay = 'Pick at least one day';
  static const String daysPassed = 'These days have passed';
  static const String booked = 'Booked';
  static const String ownTaxiFooter = 'Shown in blue as Own booking. No enquiry is sent.';
}
