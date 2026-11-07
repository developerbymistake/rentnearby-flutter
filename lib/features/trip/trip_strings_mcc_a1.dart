class TripStringsMccA1 {

  static String cancelFailed(int n) => n == 1 ? 'Could not cancel 1 booking · try again' : 'Could not cancel $n bookings · try again';

  static String bookingsCancelled(int n) => n == 1 ? '1 booking cancelled · owner told' : '$n bookings cancelled · owners told';

  static String enquiriesWithdrawn(int n) => n == 1 ? '1 enquiry withdrawn' : '$n enquiries withdrawn';

}
