class StayEnquiryStrings {
  // Stay nights keep their own cap (I-41 lowered only trip days to 5).
  static const int maxNights = 14;
  static const String rowSubtitle = 'Trip enquiries for this stay';
  static const String guestFallback = 'Guest';
  static const String cancelAction = 'Cancel';
  static String offerTo(String guest) => 'To $guest';
  static const String notAvailableTitle = 'Mark as not available?';
  static const String notAvailableBody = 'The guest is told and this enquiry closes.';
  static const String roomName = 'Room name';
  static const String removeRoom = 'Remove room';
  static const String enterPrice = 'Enter a price for every room';
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
