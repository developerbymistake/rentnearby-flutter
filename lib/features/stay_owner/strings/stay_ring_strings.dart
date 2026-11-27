import '../../../utils/money_format.dart';

abstract final class StayRingScreenStrings {
  static const String eyebrow = 'Incoming enquiry';
  static const String title = 'New stay enquiry';
  static const String decline = 'Decline';
  static const String accept = 'Accept';
  static const String swipeUp = 'Swipe up to answer';
  static const String close = 'Close';
  static const String openEnquiries = 'Open enquiries';
  static const String stillWaiting = 'The enquiry is waiting in Enquiries.';
  static const String missedTitle = 'Missed enquiry ring';
  static const String answeredTitle = 'You answered this enquiry';
  static const String closedTitle = 'This enquiry is closed';
  static const String openedElsewhereTitle = 'Opened on another phone';
  static const String ignoredElsewhereTitle = 'Ring ignored on another phone';

  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String from(String firstName) => 'From $firstName';

  static String dates(DateTime? checkIn, DateTime? checkOut) {
    if (checkIn == null) return '';
    final start = '${checkIn.day} ${_months[checkIn.month - 1]}';
    if (checkOut == null || !checkOut.isAfter(checkIn)) return start;
    final nights = DateTime.utc(checkOut.year, checkOut.month, checkOut.day).difference(DateTime.utc(checkIn.year, checkIn.month, checkIn.day)).inDays;
    final end = '${checkOut.day} ${_months[checkOut.month - 1]}';
    final range = checkIn.month == checkOut.month && checkIn.year == checkOut.year ? '${checkIn.day} to $end' : '$start to $end';
    return '$range · $nights ${nights == 1 ? 'night' : 'nights'}';
  }

  static String guests(int n) => '$n ${n == 1 ? 'guest' : 'guests'}';

  static String price(int rupees) => Money.exact(rupees);

  static String endTitle(String? reason) => switch (reason) {
        'Answered' => answeredTitle,
        'Accepted' => openedElsewhereTitle,
        'Declined' => ignoredElsewhereTitle,
        'Missed' => missedTitle,
        _ => closedTitle,
      };
}

abstract final class StayRingReadyStrings {
  static const String title = 'Ring for enquiries';
  static const String subtitle = 'Your phone rings like a call for a new enquiry';
  static const String switchTitle = 'Ring me for new enquiries';
  static const String switchOn = 'Your phone rings for every new enquiry';
  static const String switchOff = 'New enquiries only show a notification';
  static const String saveFailed = 'Could not save. Try again.';
  static const String loadFailed = 'Could not load your setting. Try again.';
  static const String ringFix = 'Un-mute the Stay enquiries sound';
  static const String notificationsFix = 'Turn them on so enquiries can reach you';
  static const String testFix = 'Did your phone ring? Run a test to see';
  static const String testNotShown = 'The ring did not show. Check the items above.';
}
