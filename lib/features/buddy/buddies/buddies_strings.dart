abstract final class BuddiesStrings {
  static const String title = 'Buddies';
  static const String subtitle = 'Friends you travel with';
  static const String tabBuddies = 'My buddies';
  static const String tabRequests = 'Requests';
  static const String tabFind = 'Find';
  static const String blockedTitle = 'Blocked people';
  static const String findABuddy = 'Find a buddy';
  static const String addBuddy = 'Add buddy';
  static const String accept = 'Accept';
  static const String decline = 'Decline';
  static const String cancel = 'Cancel';
  static const String unblock = 'Unblock';
  static const String received = 'RECEIVED';
  static const String sentWaiting = 'SENT, WAITING';
  static const String ended = 'Ended';
  static const String sendAgainLater = 'You can send again later';
  static const String badgeNew = 'New';
  static const String rowFallback = 'Friends you travel with';

  static String myBuddiesCount(int n) => n > 0 ? '$tabBuddies $n' : tabBuddies;
}
