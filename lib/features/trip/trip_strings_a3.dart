import '../../models/browse_item.dart';

class TripStringsA3 {
  static const String seats4 = 'Seats 4+';
  static const String seats6 = 'Seats 6+';
  static const String suv = 'SUV';
  static const String wholeTrip = 'Whole trip';

  static const String iHaveTaxi = 'I already have a taxi';
  static const String shortlistNone = 'Shortlist up to 3 drivers';
  static const String sendIdle = 'Send enquiry';
  static String sendForDays(int n) => 'Send enquiry for $n ${n == 1 ? 'day' : 'days'}';

  static const String noDriversTitle = 'No drivers with a day rate here yet';
  static const String noDriversBody = 'Use your own taxi, or come back later.';
  static String noTaxiHasEnquiry(int d) => 'Day $d has a driver enquiry · withdraw it first';
  static String replaceOwnTaxi(String name) => name.isEmpty ? 'Replace your own taxi?' : 'Replace your own taxi $name?';
  static const String noMatchTitle = 'No drivers match';
  static const String noMatchBody = 'Try fewer filters.';
  static const String clearFilters = 'Clear filters';

  static const String pastTripTitle = 'Past trip';
  static const String pastDayTitle = 'This day has passed';
  static const String readOnlyBody = 'Taxi changes are off here. Open replies to see the drivers you asked.';

  static const String daysPassedTitle = 'These days have passed';
  static const String daysPassedBody = 'Pick a day that is still ahead.';
  static const String close = 'Close';

  static const String viewStatus = 'View status';
  static const String more = 'More';
  static String useForDay(int d) => 'Use for Day $d';
  static const String iBookedThis = 'I booked this driver';
  static const String viewDetails = 'View details';
  static const String contactFailed = 'Could not get the number. Try again.';

  static String bookedBanner(String name) => '$name is booked';
  static String ownTaxiBanner(String name) => 'Your own taxi: $name';
  static const String edit = 'Edit';
  static String selectedForDay(String name, int d) => '$name selected for Day $d';
  static const String cancelFirstTitle = 'Cancel the booking first';
  static String cancelFirstBody(String driver, int day) => '$driver is booked for Day $day. Cancel it, then pick another driver.';
  static const String keep = 'Keep';

  static const String perDayLocal = 'per day, local';
  static const String rateOnRequest = 'Rate on request';

  static String daysAdded(String driver) => 'Days added to your enquiry with $driver';
  static String sentToDrivers(int n) => n == 1 ? 'Enquiry sent to 1 driver' : 'Enquiry sent to $n drivers';
  static const String alreadyBookedOther = 'Already booked for other days. Edit the booking to add days.';
  static const String couldNotSend = 'Could not send';
  static String driversTitle(int n) => '$n drivers';

  static const String driverRateLabel = 'Rate per day (required)';
  static String errPriceRange(int max) => 'Price must be between ₹1 and ${BrowseItem.inr(max)}';
}
