import 'social_models.dart';

abstract final class SocialStrings {
  static const String follow = 'Follow';
  static const String following = 'Following';
  static const String requested = 'Requested';
  static const String followBack = 'Follow back';
  static const String message = 'Message';
  static const String addToBuddies = 'Add to My Buddies';
  static const String buddy = 'Buddy';
  static const String report = 'Report';
  static const String block = 'Block';
  static const String followsYou = 'Follows you';
  static const String followEachOther = 'You follow each other';
  static const String safetyMeet = 'Meet in a public place first. Never send money before you meet.';
  static const String retry = 'Retry';
  static const String offline = 'You are offline. Check your connection.';
  static const String gone = 'This is no longer available.';
  static const String failed = 'Something went wrong. Try again.';
  static const String reportSub = 'Tell us what is wrong';
  static const String blockSub = 'They are not told';
  static const String menOnly = 'Men only';
  static const String womenOnly = 'Women only';
  // Follow limit or block (D3): one generic message, never a counter or a date.
  static const String tryLaterTitle = 'Try again later';
  static const String tryLaterLine = 'We limit some actions to keep Bakhli safe.';
  static const String ok = 'OK';

  // Delete waits until the other travellers are removed or have left.
  static String removeMembersFirstLine(int n) => n > 0 ? 'Remove the other travellers first ($n)' : 'Remove the other travellers first';
  static const String removeMembersFirstTitle = 'Other travellers are on this trip';
  static const String removeMembersFirstNote = 'Remove the travellers or wait until they leave, then delete.';
  static const String seeTravellers = 'See travellers';

  static String mutualsLine(Mutuals m) {
    if (m.isEmpty) return '';
    final first = m.names.isEmpty ? null : m.names.first;
    if (first == null) return mutualCount(m.count);
    final others = m.count - 1;
    if (others <= 0) return 'Followed by $first';
    return 'Followed by $first and $others ${others == 1 ? 'other' : 'others'} you know';
  }

  static String mutualCount(int n) => '$n mutual';

  static const String levelNewTraveller = 'New Traveller';
  static const String levelTrailStarter = 'Trail Starter';
  static const String levelWanderer = 'Wanderer';
  static const String levelTrekker = 'Trekker';
  static const String levelPathfinder = 'Pathfinder';
  static const String levelSummitSeeker = 'Summit Seeker';
  static const String levelTravelKing = 'Travel King';

  static const String travelLevelsTitle = 'Travel levels';
  static const String travelLevelsSub = 'Trips done with a Bakhli booking';
  static const String allLevels = 'All levels';
  static const String youAreHere = 'You are here';
  static const String levelsFooter = 'Others see only your level and trip count.';
  static const String highestLevel = 'You have reached the highest level';
  static const String keepExploring = 'Keep exploring';
  static const String openLevels = 'Open travel levels';
  static const String to = 'to';

  static String levelEyebrow(int index) => 'LEVEL $index';
  static String tripsWord(int n) => n == 1 ? 'trip' : 'trips';
  static String tripsCount(int n) => '$n ${tripsWord(n)}';
  static String tripsDone(int n) => '${tripsCount(n)} done';
  static String moreTrips(int n) => n == 1 ? '1 more trip' : '$n more trips';
  static String moreTripsTo(int n, String name) => '${moreTrips(n)} to $name';
  static String atTrips(int n) => 'at $n trips';
  static String levelRange(int index, int min, int? max) =>
      'Level $index · ${max == null ? '$min+ trips' : min == max ? tripsCount(min) : '$min to $max trips'}';
  static String newLevel(String name) => 'New level: $name';
  static String levelUpLine(int n) => 'Your trip is counted. ${tripsDone(n)}.';
  static String levelLabel(String name, int n) => '$name, ${tripsCount(n)}';
  static String openLevelsLabel(String name, int n) => '$openLevels. ${levelLabel(name, n)}';
  static String levelRowLabel(String name, String range, {bool current = false}) => '$name, $range${current ? ', $youAreHere' : ''}';
  static String toNext(String? name) => ' $to${name == null ? '' : ' $name'}';

  static String buddyLine(int tripsTogether) => tripsTogether <= 0 ? buddy : '$buddy · $tripsTogether ${tripsTogether == 1 ? 'trip' : 'trips'} together';
}
