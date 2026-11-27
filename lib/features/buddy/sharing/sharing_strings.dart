abstract final class SharingStrings {
  static const String travellersTitle = 'Travellers';
  static const String buddyInviteTitle = 'Invite travellers';
  static const String expensesTitle = 'Trip expenses';
  static const String deleteTrip = 'Delete trip';
  static const String inviteBuddies = 'Invite buddies';

  static const String inviteFriendsLine = 'Invite your friends on this trip';
  static const String invite = 'Invite';
  static const String manage = 'Manage';
  static const String noExpensesYet = 'No expenses yet';
  static const String addExpense = 'Add expense';
  static const String view = 'View';
  static const String settled = 'Settled';
  static const String allSetInvite = 'All set. Invite your friends.';
  static const String addPlacesFirst = 'Add places to the plan first.';

  static String sharedWith(int n) => 'Shared with $n ${n == 1 ? 'person' : 'people'}';
  static String day(int d) => 'Day $d';
  static String joinedLine(int joined, int waiting) =>
      waiting > 0 ? '$joined joined · ${invitesWaiting(waiting)}' : '$joined joined';
  static String invitesWaiting(int n) => '$n ${n == 1 ? 'invite' : 'invites'} waiting';
  static String spentShare(String spent, String share) => 'Spent $spent · Your share $share';
  static String spentOpen(String spent, int n) => 'Spent $spent · $n ${n == 1 ? 'payment' : 'payments'} open';
  static String spentSettled(String spent) => 'Spent $spent · All settled';

  static const String inviteTitle = 'Invite to this trip';
  static const String inviteSubtitle = 'They join as viewers after they accept.';
  static const String inviteFootnote = 'Only your buddies are listed here. To invite someone else, add them as a buddy first.';
  static const String inviteSentBadge = 'Invite sent';
  static const String onThisTripBadge = 'On this trip';
  static const String sendInvite = 'Send invite';
  static String sendInviteN(int n) => n > 0 ? 'Send invite ($n)' : sendInvite;
  static String seatsLeft(int n) => '$n ${n == 1 ? 'seat' : 'seats'} left';
  static String onlySeatsLeft(int n) => 'Only $n ${n == 1 ? 'seat' : 'seats'} left. A trip can have up to 12 travellers.';
  static const String tripIsFull = 'This trip is full';
  static String couldNotInvite(String name) => 'Could not invite $name.';
  static String inviteSentTo(String name) => 'Invite sent to $name';
  static String invitesSentTo(int n) => 'Invites sent to $n buddies';
  static const String tripCompleted = 'This trip is complete. Plan changes are off.';
  static const String noBuddiesYet = 'No buddies yet';
  static const String noBuddiesLine = 'Add a buddy first, then invite them to your trip.';
  static const String findABuddy = 'Find a buddy';
  static const String followFootnote = 'People you follow are listed here. Buddies have a star.';
  static const String myBuddies = 'My buddies';
  static const String myBuddiesLine = 'Select all your buddies';
  static const String peopleYouFollow = 'People you follow';
  static const String sendInvites = 'Send invites';
  static String sendInvitesN(int n) => n > 0 ? 'Send invites ($n)' : sendInvites;
  static const String backToPlan = 'Back to plan';
  static const String noFollowsYet = 'No one to invite yet';
  static const String noFollowsLine = 'Follow people first, then invite them to your trip.';
  static const String findPeople = 'Find people';
  static String invitesSent(int n) => 'Invites sent to $n people';

  static String countTitle(int n, int max) => '$n of $max travellers';
  static const String joinedSection = 'JOINED';
  static const String invitedSection = 'INVITED';
  static String you(String name) => '$name (You)';
  static const String createdTheTrip = 'Created the trip';
  static String joinedOn(String date) => 'Joined $date';
  static const String inviteWaitingRow = 'Invite sent, waiting';
  static const String owner = 'Owner';
  static const String viewer = 'Viewer';
  static const String cancelInvite = 'Cancel invite';
  static const String inviteCancelled = 'Invite cancelled';
  static const String openExpenses = 'Open expenses';
  static const String moreOptions = 'More options';
  static String dotLine(String? username, String tail) => username == null || username.isEmpty ? tail : '$username · $tail';

  static const String removeFromTrip = 'Remove from trip';
  static String removeTitle(String name) => 'Remove $name from this trip?';
  static String removeShares(String name, int n) => n == 1
      ? '$name shares 1 expense. It stays as it is. You can still settle with $name.'
      : '$name shares $n expenses. They stay as they are. You can still settle with $name.';
  static String removeLoses(String name, {required bool hasShare}) =>
      hasShare ? '$name will lose the plan. He keeps a page with his share until it is settled.' : '$name will lose the plan.';
  static const String remove = 'Remove';
  static String removed(String name) => '$name removed';
  static String noLongerOnTrip(String name) => '$name is no longer on this trip.';

  static const String settleFirstTitle = 'Settle up first';
  static const String settleFirstBody = 'Open payments stay with your travellers.';
  static String paysLine(String from, String to, String amount) => '$from pays $to · $amount';
  static const String close = 'Close';
  static const String deleteTitle = 'Delete this trip?';
  static String deleteBody(List<String> names) {
    final who = switch (names.length) {
      0 => 'Your travellers',
      1 => names[0],
      2 => '${names[0]} and ${names[1]}',
      _ => '${names[0]}, ${names[1]} and ${names.length - 2} ${names.length == 3 ? 'other' : 'others'}',
    };
    return '$who will lose the plan and the expenses. This cannot be undone.';
  }

  static const String delete = 'Delete';
  static const String tripDeleted = 'Trip deleted';
}
