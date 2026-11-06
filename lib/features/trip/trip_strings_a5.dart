import 'trip_state_labels.dart';
class TripStringsA5 {
  static const String itinerary = 'Itinerary';
  static const String staysSection = 'Stays';
  static const String taxisSection = 'Taxis';
  static const String datesNotSet = 'Dates not set';
  static const String noDatesYet = 'No dates yet';
  static const String nothingHere = 'Nothing here yet';
  static const String nothingHereSub = 'Add places to your trip to see them here.';
  static const String share = 'Share';
  static const String shareTrip = 'Share trip';
  static const String shareFailed = 'Could not share. Try again.';
  static const String noStayTonight = TripStateLabels.noStayTonight;
  static const String noStayTravelling = 'No stay (travelling)';
  static const String ownFooter = 'Own bookings were arranged by you.';
  static const String planOnlyFooter = 'Made with Bakhli Trip Planner.';
  static const String ownBooking = 'Own booking';
  static const String tripNotFoundShare = 'Trip not found';

  static String dayHeading(int day, String? date) => date == null || date.isEmpty ? 'Day $day' : 'Day $day · $date';

  static String aboutDuration(String d) => 'about $d';

  static String offlineCopy(String time) => 'Offline copy · saved $time';

  static String nightHeading(int night, String? date, String? checkOut) {
    final parts = <String>['Night $night'];
    if (date != null && date.isNotEmpty) parts.add(date);
    if (checkOut != null && checkOut.isNotEmpty) parts.add('check-out $checkOut');
    return parts.join(' · ');
  }


  static String nightOf(int k, int n, String? total) =>
      total == null ? 'Night $k of $n' : 'Night $k of $n · $total total';

  static const String checkOutTomorrow = 'Check-out tomorrow morning';

  static String checkOutOn(String d) => 'Check-out $d';

  static const String perRoomPerNight = 'Per room per night';
  static const String perRoomNightShort = 'per room per night';

  static String roomsNights(int rooms, int nights) =>
      '$rooms ${rooms == 1 ? 'room' : 'rooms'} x $nights ${nights == 1 ? 'night' : 'nights'}';

  static String roomsNightsTotal(int rooms, int nights, String total) => '${roomsNights(rooms, nights)} = $total';

  static String priceRoomNight(String p) => '$p per room per night';

  static String roomsNightsTotalLine(int units, int nights, String total) =>
      '${roomsNights(units, nights)} · Total $total';

  static String listedAmount(String p) => 'Listed $p';

  static String unitsAtPrice(int units, String p) => '$units x $p per room per night';

  static const String proposesPriceOwner = 'proposes a price';
  static const String priceProposedTitle = 'Price proposed';
  static const String yourPriceTitle = 'Your price';

  static String errPriceRange(String min, String max) => 'Price must be between $min and $max';

  static String failsNightAndLater(int day, {required bool taxi}) {
    final unit = taxi ? 'day' : 'night';
    final cap = taxi ? 'Day' : 'Night';
    final kept = day - 1;
    final tail = kept == 1 ? '$cap 1 stays as it was.' : '${cap}s 1 to $kept stay as they were.';
    return 'This fails $unit $day and later. $tail';
  }

  static const String completeNowQ = 'Complete the trip now?';
  static const String completeNowBody = 'Open enquiries stay open. You can still see bookings in Summary.';

  static const String askAnotherStay = 'Ask another stay';
  static const String sendEnquiry = 'Send enquiry';
  static const String removeShortlist = 'Remove';
  static const String couldNotSend = 'Could not send';
  static const String couldNotSendSub = 'Pick another stay or try later.';
  static const String alreadyBookedOther = 'Already booked for other days. Edit the booking to add days.';
}
