abstract final class SocialStringsC {
  static const String people = 'People';
  static const String trips = 'Trips';
  static const String requests = 'Requests';
  static const String traveller = 'TRAVELLER';
  static const String newToYou = 'New to you';
  static const String sayHi = 'Say hi';
  static const String noChats = 'No chats yet';
  static const String noChatsLine = "Say hi from a traveller's profile or a trip you joined.";
  static const String findBuddies = 'Find buddies';
  static const String noTripChats = 'No trip chats yet';
  static const String noTripChatsLine = 'A trip chat starts when the first person joins your trip.';
  static const String noRequests = 'No message requests';
  static const String repliesFree = 'Replying is always free.';
  static const String reply = 'Reply';
  static const String delete = 'Delete';
  static const String reportBlock = 'Report · Block';
  static String requestCount(int n) => n == 1 ? '1 message request' : '$n message requests';
  static String members(int n) => n == 1 ? '1 member' : '$n members';

  static const String disappear = 'Messages disappear after 24 hours';
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';
  static const String writeMessage = 'Write a message';
  static const String replyFree = 'Reply for free';
  static const String send = 'Send';
  static const String masked = 'Numbers are hidden for your safety';
  static const String maskToken = '•••• hidden';
  static const String notSent = 'Not sent. Tap to retry';
  static const String safety = 'Never send money to someone you have not met.';
  static const String firstMessageTitle = 'Make your first message count';
  static const String chatMorePlus = 'Chat more with Plus';
  static const String groupChatPlusTitle = 'Chat with your trip group with Plus';
  static const String groupChatPlusLine = 'You can read the chat. Plus lets you send messages.';
  static String freeCountLine(LimitLine l, String peer) =>
      'Free: first message to ${l.limit} new people a month (${l.left} left). $peer can reply for free.';
  static String firstFreeLine(LimitLine l) => 'Your first message to a new person is free · ${l.left} of ${l.limit} left this month';
  static const String limitTitle = 'You have used your new chats';
  static String limitLine(LimitLine l) => 'Free: first message to ${l.limit} new people a month. Chats already going on are not limited.';
  static String receiverInfo(String peer) => '$peer is new to you. Reply for free, or delete.';
  static const String movedToPeople = 'Moved to People. Replies are free for you.';
  static const String cannotMessage = 'You cannot message this person.';
  static const String leftTrip = 'You left this trip chat.';
  static const String notAvailable = 'This person is not available';
  static const String noTripChat = 'This trip chat is not open yet.';
  static String joined(String name) => '$name joined the trip';
  static String left(String name) => '$name left the trip';

  static const String viewProfile = 'View profile';
  static String reportName(String name) => 'Report $name';
  static String blockName(String name) => 'Block $name';
  static const String membersItem = 'Members';
  static const String reportChat = 'Report';
  static const String leaveTrip = 'Leave trip';
  static const String reportMessage = 'Report message';
  static const String reportMessageTitle = 'Report this message?';
  static const String reportMessageBody = 'The sender is not told who reported. A copy of this chat goes to our team.';
  static const String reported = 'Thanks. We will look into it.';
  static const String deleteRequestTitle = 'Delete this message?';
  static const String deleteRequestBody = 'The chat is removed from your list. The sender is not told.';
  static const String deleted = 'Chat deleted';
  static const String sendFailed = 'Could not send. Try again.';

  static const String plusTitle = 'Bakhli Plus';
  static const String autoRenew = 'Auto-renews. Cancel anytime in Google Play.';
  static const String months12 = '12 months';
  static const String months3 = '3 months';
  static const String month1 = '1 month';
  static const String bestValue = 'Best value';
  static String priceYear(String p) => '$p a year';
  static String priceFor3(String p) => '$p for 3 months';
  static String priceMonth(String p) => '$p a month';
  static String perMonthAbout(String p) => 'about $p a month';
  static const String whatYouGet = 'What you get';
  static String chatPeople(int n) => 'Chat with $n new people a month';
  static String chatPeopleSub(int free) => 'Free: first message to $free. Chats already going on are not limited';
  static String publicTrips(int n) => n == 1 ? '1 public trip' : '$n public trips';
  static String activeTrips(int n) => n == 1 ? '1 active trip' : '$n active trips';
  static String joinRequests(int n) => n == 1 ? '1 join request a month' : '$n join requests a month';
  static String freeHas(int n) => 'Free has $n';
  static const String genderOnly = 'Women-only trips';
  static const String genderOnlySub = 'Men-only and Anyone are free';
  static const String nearMe = 'Near me filter';
  static const String nearMeSub = 'See trips starting close to you';
  static const String groupChatPerk = 'Trip group chat';
  static const String groupChatPerkSub = 'Send messages to everyone on your trip';
  static const String alwaysFree = 'Always free: replying to people who wrote to you, follow, privacy, report and block.';
  static String footerTitle(String cycle) => 'Bakhli Plus · $cycle';
  static String footerToday(String price) => '$price today';
  static String renewYear(String price) => 'Then $price a year. Renews until you cancel in Google Play.';
  static String renew3(String price) => 'Then $price every 3 months. Renews until you cancel in Google Play.';
  static String renewMonth(String price) => 'Then $price a month. Renews until you cancel in Google Play.';
  static const String subscribe = 'Subscribe';
  static const String youArePlus = 'You have Bakhli Plus';
  static String plusUntil(String date) => 'Renews or ends on $date';
  static const String manage = 'Manage in Google Play';
  static const String restore = 'Restore purchase';
  static const String plusUnavailable = 'Bakhli Plus is not available right now.';
  static const String plansLoadFailed = 'Could not load Bakhli Plus.';

  static const String bannerKicker = 'BAKHLI PLUS';
  static const String bannerTitle = 'Join more trips';
  static const String seePlus = 'See Plus';
  static String bannerChats(int n) => 'Chat with $n new people a month';
  static String bannerTrips(int pub, int act) => '$pub public trips · $act active trips';

  static const String limitReachedTitle = 'You reached your limit';
  static const String plusFeatureTitle = 'This is a Bakhli Plus feature';
  static String publicLimitLine(int n) => n == 1 ? 'You can have 1 public trip at a time.' : 'You can have $n public trips at a time.';
  static String joinLimitLine(int n) => n == 1 ? 'You can send 1 join request a month.' : 'You can send $n join requests a month.';
  static String chatLimitLine(int n) => 'You can message $n new people a month.';
  static String tripLimitLine(int n) => n == 1 ? 'You can have 1 active trip.' : 'You can have $n active trips.';
  static const String plusFeatureLine = 'Women-only trips and the Near me filter come with Bakhli Plus.';
  static String resetsOn(String date) => 'Resets on $date.';
  static const String notNow = 'Not now';
  static const String ok = 'OK';

  static String inactiveTrip(int n) => n == 1 ? 'Inactive: the Free plan allows 1 active trip' : 'Inactive: the Free plan allows $n active trips';
  static const String inactiveTripPlain = 'Inactive on the Free plan';
  static String inactiveTripOf(int? n) => n == null || n <= 0 ? inactiveTripPlain : inactiveTrip(n);
  static String pausedLine(int n) => n == 1 ? '1 trip is paused. Buy Plus to restore it.' : '$n trips are paused. Buy Plus to restore them.';
  static String tripLimitPlus(int n) => 'Plan up to $n trips with Bakhli Plus.';
}

class LimitLine {
  const LimitLine({required this.limit, required this.left});

  final int limit;
  final int left;
}
