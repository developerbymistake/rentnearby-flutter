import '../../../models/browse_item.dart';

class JourneyStrings {
  static const String cancel = 'Cancel';
  static const String deleteBody = 'This removes the journey from your phone and account.';
  static const String noNumber = 'No number saved';
  static const String unavailableTag = 'Unavailable';
  static const String backupTag = 'Backup';
  static const String notFoundTitle = 'Journey not found';
  static const String notFoundBody = 'It may have been deleted';
  static const String loadFailed = "Couldn't load journeys";
  static const String driverReplaced = 'Driver replaced';
  static const String markedDone = 'Marked done';
  static const String deleted = 'Journey deleted';
  static String driverQuote(int fare) => 'Driver says ${BrowseItem.inr(fare)}';
  static String seatsLabel(int n) => '$n seats';
}
