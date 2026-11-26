import '../../owner_core/strings/owner_shared_strings.dart';

abstract final class TaxiAvailabilityStrings {
  static const labelCaps = 'AVAILABILITY';
  static const title = 'Availability';
  static const manage = 'Manage';
  static const bookings = 'Bookings';
  static const daysOff = 'Days off';
  static const pageSub = 'Tap the days you are not available';
  static const legendOff = 'Not available';
  static const legendBooked = 'Booked from app (locked)';
  static const yourDaysOff = 'Your days off';
  static const noReason = 'No reason added';
  static const noDaysOff = 'No days off.';
  static const save = 'Save';
  static const sheetSubFree = 'Not available this day';
  static const sheetSubOff = 'Marked not available';
  static const reason = 'Reason';
  static const reasonHint = 'For example: family function';
  static String counter(int n) => '$n / 200';
  static const counterLimit = '200 / 200 · limit reached';
  static const markOff = 'Mark not available';
  static const saveReason = 'Save reason';
  static const makeAvailable = 'Make available';
  static const toastBooked = 'This day has a booking';
  static const toastSaved = 'Availability saved';
  static const toastFailed = 'Could not save. Try again.';
  static const offlineNote = 'You are offline. Taxi is hidden on every day. Switch on Available now on Home.';
  static String rateLimited(int minutes) => 'You can change this 3 times an hour. Try again in $minutes min.';
  static const dayIsOff = 'This day is off. Change it on Home.';
  static const offTag = 'OFF';

  static String dayLabel(DateTime d) => '${d.day} ${OwnerSharedStrings.months[d.month - 1]}';

  static String cardSemantics(String month, String bookingsValue, String daysOffValue) =>
      '$title, $month, $bookingsValue $bookings, $daysOffValue $daysOff';
}
