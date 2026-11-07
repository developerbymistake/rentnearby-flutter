class StayEnquiryStrings {
  static const String rowSubtitle = 'Trip enquiries for this stay';
  static const String guestFallback = 'Guest';
  static const String answeredByLink = 'Answered by link';
  static const String changeAnswer = 'Change your answer';
  static const String confirmBookingTitle = 'Confirm this booking?';
  static const String notYourBookingTitle = 'Not your booking?';
  static const String cancelAction = 'Cancel';
  static String confirmBookingBody(String guest, String price, String dates) =>
      price.isEmpty ? '$guest says you booked $dates.' : '$guest says you agreed $price for $dates.';
  static String notYourBookingBody(String guest) => '$guest is told and the night turns red for them.';
  static String offerTo(String guest) => 'To $guest';
  static const String notAvailableTitle = 'Mark as not available?';
  static const String notAvailableBody = 'The guest is told and this enquiry closes.';
  static const String roomName = 'Room name';
  static const String removeRoom = 'Remove room';
  static const String enterPrice = 'Enter a price for every room';
  static const String advanceTooHigh = 'Advance cannot be more than the total';
  static const String datesInvalid = 'Check-out must be after check-in';
  static const String inclusions = 'Inclusions';
  static const String optional = 'Optional';
  static const String retryMore = 'Could not load more';
  static const String phoneInvalid = 'Enter a 10 digit mobile number';
  static String offerValid(bool urgent) => urgent ? '2 h' : '24 h';
  static String moreChips(int n) => '+$n';
  static const String reasonRequired = 'Add a reason';
  static const String changeBodyFallback = 'The room price stays the same.';
  static String offerPrice(String p) => 'Offer $p';
}
