import '../../owner_core/strings/owner_shared_strings.dart';

abstract final class TaxiAvailabilityStrings {
  static const legendOff = 'Day off';
  static const hiddenRule = 'Booked and day-off days are hidden from travellers.';
  static const choiceSub = 'What is on this day?';
  static const booked = 'Booked';
  static const bookedSub = 'A trip you got by phone or WhatsApp';
  static const dayOff = 'Day off';
  static const dayOffSub = 'You are not driving this day';
  static String sheetTitle(DateTime d) => '$dayOff · ${OwnerSharedStrings.dayMonth(d)}';
  static const sheetSub = 'Travellers won\'t see your taxi this day.';
  static const reason = 'Reason';
  static const reasonHint = 'For example: family function';
  static String counter(int n) => '$n / 200';
  static const counterLimit = '200 / 200 · limit reached';
  static const save = 'Save';
  static const removeDayOff = 'Remove day off';
  static const changeToBooked = 'Change to Booked';
  static const toastBooked = 'This day has a booking';
  static const toastSaved = 'Day off saved';
  static const toastRemoved = 'Day off removed';
  static const toastFailed = 'Could not save. Try again.';
  static const outsideWindow = 'Days off can be set inside your calendar.';
  static String rateLimited(int minutes) => 'You can change this 3 times an hour. Try again in $minutes min.';
}
