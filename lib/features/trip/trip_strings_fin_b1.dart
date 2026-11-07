
class TripStringsFinB1 {

  static String roomLine(String room, String? guests) => guests == null ? room : '$room, $guests';
  static const String groundFloor = 'Ground floor';
  static String askedWaiting(String ago) => ago.isEmpty ? 'Asked · waiting for the host' : 'Asked $ago · waiting for the host';
  static String offeredTotal(String total) => 'Offered $total';
  static String agreedFare(String fare) => 'Fare $fare · agreed';
  static const String checkOutDay = 'Check-out day';
}
