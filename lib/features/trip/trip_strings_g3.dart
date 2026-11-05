class TripStringsG3 {
  static const String asksCloseTitle = 'Open asks will close';
  static String bookedKeep(int n) => n == 1
      ? '1 booking keeps its dates. Tell the owner in chat or by call, or cancel.'
      : '$n bookings keep their dates. Tell the owners in chat or by call, or cancel.';
  static String asksClose(int n) => n == 1
      ? '1 open ask will be closed. The owner is told.'
      : '$n open asks will be closed. The owners are told.';

  static String insideTrip(String range) => "Inside the guest's trip: $range";
}
