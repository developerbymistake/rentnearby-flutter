import 'trip_state_labels.dart';
class TripStringsMccA2 {
  static const String wrongCityNow = 'Wrong city now';
  static String nightInCity(int n, String city) => 'Night $n is in $city';
  static String dayInCity(int n, String city) => 'Day $n is in $city';
  static String nightsInCity(int w, int t, String city) => '$w of $t nights are now in $city';
  static String daysInCity(int w, int t, String city) => '$w of $t days are now in $city';
  static const String cancel = 'Cancel';
  static const String changeDays = 'Change days';
  static const String noStayTonight = TripStateLabels.noStayTonight;
  static const String noStayHint = 'On a night bus or train';
  static const String undo = 'Undo';
  static const String undoHint = 'Find a stay for this night';

  static String removeQ(String city) => 'Remove $city?';
  static String changeDaysQ(String city) => 'Change days in $city?';

  static String _bookings(int n) => n == 1 ? '1 booking' : '$n bookings';
  static String _enquiries(int n) => n == 1 ? '1 enquiry' : '$n enquiries';

  static String impactBody(int booked, int open) {
    if (booked == 0) return open == 1 ? '1 enquiry will be withdrawn.' : '$open enquiries will be withdrawn.';
    if (open == 0) {
      return booked == 1 ? '1 booking is on these days. Cancel it now?' : '$booked bookings are on these days. Cancel them now?';
    }
    return '${_bookings(booked)} and ${_enquiries(open)} are on these days. Cancel them now?';
  }

  static String ownersTold(int hosts, int drivers) {
    final h = hosts == 1 ? '1 host' : '$hosts hosts';
    final d = drivers == 1 ? '1 driver' : '$drivers drivers';
    if (hosts > 0 && drivers > 0) return '$h and $d are told.';
    if (hosts > 0) return hosts == 1 ? '1 host is told.' : '$h are told.';
    if (drivers > 0) return drivers == 1 ? '1 driver is told.' : '$d are told.';
    return '';
  }

  static String laterKept(String cities) => 'Bookings in $cities are cancelled too, the days move.';
  static String moreRows(int n) => '+ $n more';

  static const String cancelAndRemove = 'Cancel and remove';
  static const String cancelAndChange = 'Cancel and change';
  static const String removeKeepBookings = 'Remove, keep bookings';
  static const String changeKeepBookings = 'Change, keep bookings';
  static const String keepCity = 'Keep city';
  static const String keepDays = 'Keep days';
  static const String connectToCancel = 'Connect to cancel bookings';
  static const String bookingsKept = 'Bookings kept · they show as Old dates';
  static String nightHasStay(int n) => 'Night $n has a stay · cancel it first';
  static const String cancelling = 'Cancelling...';
}
