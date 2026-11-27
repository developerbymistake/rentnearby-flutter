import '../../buddy/shared/buddy_format.dart';
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
  static const String followLimit = 'You have followed many people today. Try again tomorrow.';

  // 72-hour post lock and the delete-alone rule (CONTRACT_SOCIAL 11.9)
  static String postUnlockMoment(DateTime at) {
    final l = at.toLocal();
    return '${BuddyFormat.weekdayDate(l)}, ${BuddyFormat.time12('${l.hour}:${l.minute}')}';
  }

  static String postLockedLine(DateTime? unlocksAt) =>
      unlocksAt == null ? 'You can remove this post 3 days after posting' : 'You can remove this post on ${postUnlockMoment(unlocksAt)}';
  static const String postLockedTitle = 'Your post stays up for 3 days';
  static const String postLockedEditNote = 'You can still edit it at any time.';
  static String removeMembersFirstLine(int n) => n > 0 ? 'Remove the other travellers first ($n)' : 'Remove the other travellers first';
  static const String removeMembersFirstTitle = 'Other travellers are on this trip';
  static const String removeMembersFirstNote = 'Removing someone takes them out of the trip and the chat. They are told.';
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

  static String buddyLine(int tripsTogether) => tripsTogether <= 0 ? buddy : '$buddy · $tripsTogether ${tripsTogether == 1 ? 'trip' : 'trips'} together';
}
