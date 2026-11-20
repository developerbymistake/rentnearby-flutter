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
  static const String menuLabel = 'More';
  static const String dots = '⋮';
  static const String alertMark = '!';

  static String myBuddiesCount(int n) => n > 0 ? '$tabBuddies $n' : tabBuddies;

  static const String yourUsername = 'Your username';
  static const String copy = 'Copy';
  static const String myQr = 'My QR';

  static const String emptyTitle = 'No buddies yet';
  static const String emptyLine = 'Find a friend by their username';
  static String buddiesLabel(int n) => n == 1 ? '1 BUDDY' : '$n BUDDIES';

  static const String typeUsername = 'Type a username';
  static const String searchLabel = 'Search';
  static const String scanLabel = 'Scan a QR';
  static const String findHint = 'Ask your friend for their username, or scan their QR';
  static const String orShowYours = 'OR SHOW YOURS';
  static const String ownUsername = 'This is your own username.';
  static const String onePersonFound = '1 PERSON FOUND';
  static const String yourBuddy = '✔ Your buddy';
  static const String yourBuddyText = 'Your buddy';
  static const String requestSent = 'Request sent';
  static const String requested = 'Requested';
  static const String cancelRequest = 'Cancel request';
  static const String notFoundTitle = 'No one found';
  static const String notFoundLine = 'Check the username and try again';
  static const String failedTitle = 'Could not search';
  static const String failedLine = 'Check your network and try again.';
  static const String tryAgain = 'Try again';
  static const String limitedTitle = 'Too many tries';
  static const String limitedLine = 'Please try again in a few minutes';

  static String requestSentTo(String name) => 'Request sent to $name';
  static String nowYourBuddy(String name) => '$name is now your buddy';
  static const String dayLimit = 'You have sent 10 requests today. Try again tomorrow.';
  static const String waitingLimit = 'You have 20 requests waiting. Cancel one to send more.';
  static const String buddyLimit = 'You have 500 buddies. Remove one to add more.';
  static const String cannotAddNow = 'Could not add this buddy right now.';
  static const String onHold = 'You cannot send requests right now.';
  static const String selfRequest = 'You cannot add yourself.';
  static const String requestGone = 'This request is no longer open.';

  static const String noRequestsTitle = 'No requests yet';
  static const String noRequestsLine = 'Requests you get and send show here';

  static String blockName(String name) => 'Block $name';
  static const String notTold = 'They will not be told';
  static const String report = 'Report';
  static const String reportLine = 'Spam, harassment or a fake account';
  static const String inviteToTrip = 'Invite to a trip';
  static const String pickTrip = 'Pick one of your trips';
  static const String removeBuddy = 'Remove buddy';
  static const String tripsStay = 'Trips you share stay as they are';
  static const String block = 'Block';
  static String removeTitle(String name) => 'Remove $name?';
  static const String removeBody = 'Trips you share stay as they are.';
  static const String remove = 'Remove';
  static String removed(String name) => '$name removed';

  static String inviteTitle(String name) => 'Invite $name to a trip';
  static const String inviteSubtitle = 'They join as a viewer after they accept.';
  static const String sendInvite = 'Send invite';
  static String travellers(int n) => '$n of 12';
  static String draftDays(int days) => days == 1 ? 'Draft · 1 day' : 'Draft · $days days';
  static const String onThisTrip = 'On this trip';
  static const String inviteSentBadge = 'Invite sent';
  static const String tripFull = 'Trip is full';
  static const String noPlaces = 'No places yet';
  static const String noTripsTitle = 'No trips yet';
  static const String noTripsLine = 'Plan a trip first.';
  static const String planATrip = 'Plan a trip';
  static String alreadyOnTrip(String name) => '$name is already on this trip';
  static String couldNotInvite(String name) => 'Could not invite $name.';
  static const String addPlacesFirst = 'Add places to the plan first.';
  static String inviteSentTo(String name) => 'Invite sent to $name';

  static String blockTitle(String name) => 'Block $name?';
  static const String blockBody = 'They will not be told. They cannot find you or invite you.';
  static const String alsoReport = 'Also report';
  static String stillOnYourTrip(String name, String trip) => '$name is still on your $trip. Remove him in Travellers.';
  static String stillOnYourTrips(String name, int n) => '$name is still on $n of your trips. Remove him in Travellers.';
  static String youAreOnTheirTrip(String name) => "You are still on $name's trip. Leave it in Travellers.";
  static const String tooManyBlocks = 'You have blocked too many people.';
  static const String pickReason = 'Pick a reason.';
  static String blocked(String name) => '$name blocked';
  static String reportTitle(String name) => 'Report $name?';
  static const String reportBody = 'The report goes to the app team.';
  static const String alsoBlock = 'Also block';
  static const String reportSent = 'Report sent';
  static const String noteHint = 'Tell us what happened';

  static String people(int n) => n == 1 ? '1 person' : '$n people';
  static String blockedLine(String username, String day) => username.isEmpty ? 'Blocked $day' : '$username · Blocked $day';
  static const String blockedNote = 'They cannot find you, send you a request or invite you.';
  static const String noOneBlocked = 'No one blocked';

  static String newRequests(int n) => n == 1 ? '1 new request' : '$n new requests';
  static String buddyCount(int n) => n == 1 ? '1 buddy' : '$n buddies';
}
