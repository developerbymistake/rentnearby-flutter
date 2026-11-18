class TripStringsDayplan {
  static const String lockedByRequest = 'Plan is locked while your taxi request is active. Cancel the request to edit.';
  static const String lockedByBooking = 'Plan is locked while your booking is active. Cancel the booking to edit.';
  static const String lockedShort = 'Plan is locked';
  static const String tooFewDays = 'Too few days for these places';
  static const String emptyDayBlock = 'Add a place to every day';
  static const String staleBlock = 'Plan changed. Open it again';

  static String lockMessage({required bool byBooking}) => byBooking ? lockedByBooking : lockedByRequest;
}
