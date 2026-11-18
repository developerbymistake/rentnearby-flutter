class TripStringsDayplan {
  static const String lockedByRequest = 'Plan is locked while your taxi request is active. Cancel the request to edit.';
  static const String lockedByBooking = 'Plan is locked while your booking is active. Cancel the booking to edit.';
  static const String lockedShort = 'Plan is locked';
  static const String tooFewDays = 'Too few days for these places';
  static const String emptyDayBlock = 'Add a place to every day';
  static const String staleBlock = 'Plan changed. Open it again';

  static const String customize = 'Customize';
  static const String hide = 'Hide';
  static const String show = 'Show';
  static const String more = 'More';
  static const String yourPlan = 'Your plan';
  static const String viewRequest = 'View request';
  static const String viewBooking = 'View booking';

  static const String saveTrip = 'Save trip';
  static const String saveTripFailed = 'Could not save your trip. Please try again.';
  static const String requestTaxi = 'Request taxi';
  static const String taxiFinding = 'Finding a driver';
  static const String taxiChoose = 'Choose your driver';
  static const String taxiWaitingConfirm = 'Waiting for the driver to confirm';
  static const String pillWaiting = 'Waiting';
  static const String taxiBooked = 'Taxi booked';
  static const String taxiInProgress = 'Trip in progress';
  static const String taxiRate = 'Rate your driver';
  static const String taxiDone = 'Trip completed';

  static String pace({required bool relaxed}) => relaxed ? 'Pace: Relaxed' : 'Pace: Normal';

  static String foldedSummary(int days, int places) => '${days == 1 ? '1 day' : '$days days'} · ${places == 1 ? '1 place' : '$places places'} · Tap to open';

  static String lockMessage({required bool byBooking}) => byBooking ? lockedByBooking : lockedByRequest;
}
