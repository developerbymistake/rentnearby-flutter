import '../../models/browse_item.dart';

class TripStringsA3 {
  static const String seats4 = 'Seats 4+';
  static const String seats6 = 'Seats 6+';
  static const String suv = 'SUV';

  static const String noMatchTitle = 'No drivers match';
  static const String noMatchBody = 'Try fewer filters.';
  static const String clearFilters = 'Clear filters';

  static const String pastTripTitle = 'Past trip';
  static const String readOnlyBody = 'Taxi changes are off here. Open replies to see the drivers you asked.';

  static const String daysPassedTitle = 'These days have passed';
  static const String daysPassedBody = 'Pick a day that is still ahead.';
  static const String close = 'Close';

  static const String viewStatus = 'View status';
  static const String more = 'More';
  static const String iBookedThis = 'I booked this driver';
  static const String viewDetails = 'View details';
  static const String contactFailed = 'Could not get the number. Try again.';

  static const String rateOnRequest = 'Rate on request';

  static const String driverRateLabel = 'Rate per day (required)';
  static String errPriceRange(int max) => 'Price must be between ₹1 and ${BrowseItem.inr(max)}';
}
