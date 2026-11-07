class TripStringsA2 {
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
  static const String noMatchBody = 'Try another price or stay type.';

  static String guests(int n) => n == 1 ? '1 guest' : '$n guests';
  static String checkIn(String time) => 'Check-in $time';
  static const String perNightListed = 'per night, listed';
  static const String priceOnRequest = 'Price on request';
  static const String featured = 'Featured';
  static const String asked = 'Asked';

  static String nightChip(int n) => 'Night $n';
  static String dayChip(int n) => 'Day $n';

  static const String addDatesToSend = 'Add your trip dates to send an enquiry';
  static const String addDates = 'Add dates';
  static const String refresh = 'Refresh';

}
