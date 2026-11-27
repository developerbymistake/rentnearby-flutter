abstract final class BuddiesStrings {
  static const String title = 'Buddies';
  static const String blockedTitle = 'Blocked people';
  static const String unblock = 'Unblock';
  static const String rowFallback = 'Friends you travel with';

  static const String report = 'Report';
  static const String block = 'Block';

  static String blockTitle(String name) => 'Block $name?';
  static const String blockBody = 'They will not be told. They cannot find you or invite you.';
  static const String alsoReport = 'Also report';
  static String stillOnYourTrip(String name, String trip) => '$name is still on your $trip. Remove him in Travellers.';
  static String stillOnYourTrips(String name, int n) => '$name is still on $n of your trips. Remove him in Travellers.';
  static String youAreOnTheirTrip(String name) => "You are still on $name's trip. Leave it in Travellers.";
  static const String tooManyBlocks = 'You have blocked too many people.';
  static const String pickReason = 'Pick a reason.';
  static String reportTitle(String name) => 'Report $name?';
  static const String reportBody = 'The report goes to the app team.';
  static const String alsoBlock = 'Also block';
  static const String noteHint = 'Tell us what happened';

  static String people(int n) => n == 1 ? '1 person' : '$n people';
  static String blockedLine(String username, String day) => username.isEmpty ? 'Blocked $day' : '$username · Blocked $day';
  static const String blockedNote = 'They cannot find you, send you a request or invite you.';
  static const String noOneBlocked = 'No one blocked';

  static String newRequests(int n) => n == 1 ? '1 new request' : '$n new requests';
  static String buddyCount(int n) => n == 1 ? '1 buddy' : '$n buddies';
}
