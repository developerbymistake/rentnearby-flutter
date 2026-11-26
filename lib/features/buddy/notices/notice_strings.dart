abstract final class NoticeStrings {
  static const String tagBuddies = 'BUDDIES';
  static const String tagTrip = 'TRIP';
  static const String tagExpenses = 'EXPENSES';
  static const String badgeNew = 'NEW';

  static const String someone = 'Someone';
  static const String yourTrip = 'your trip';

  static const String buddyRequestTitle = 'New buddy request';
  static String buddyRequestOne(String actor) => '$actor wants to be your buddy.';
  static String buddyRequestMany(int count) => '$count people want to be your buddy.';

  static const String tripInviteTitle = 'Trip invite';
  static String tripInviteBody(String actor, String trip) => '$actor invited you to $trip.';

  static String saidPaidTitle(String actor) => '$actor says paid';
  static String saidPaidOne(String amount, String trip) => '$amount for $trip. Mark it received when it is in your account.';
  static String saidPaidNoAmount(String trip) => 'A payment is waiting on $trip.';
  static String saidPaidMany(int count, String trip) => '$count payments are waiting on $trip.';

  static const String settleTitle = 'Time to settle up';
  static String settleBody(String actor, String amount) => 'You owe $actor $amount.';

  static const String notReceivedTitle = 'Payment not received';
  static String notReceivedBody(String actor, String amount) => '$actor has not got your $amount yet. Please check.';

  static String moneyNoAmount(String trip) => 'You have money to settle on $trip.';

  static const String expensesTitle = 'Expenses updated';
  static String expensesOne(String actor, String trip) => '$actor updated the expenses of $trip.';
  static String expensesMany(int count, String trip) => '$count updates on $trip.';

  static const String removedTitle = 'Removed from a trip';
  static String removedBody(String actor, String trip) => '$actor removed you from $trip.';

  static const String deletedTitle = 'Trip deleted';
  static String deletedBody(String actor) => '$actor deleted a trip you were on.';
  static const String deletedNoActor = 'A trip you were on was deleted.';

  static const String acceptedTitle = 'Request accepted';
  static String acceptedOne(String actor) => '$actor is now your buddy.';
  static String acceptedMany(String actor, int others) => '$actor and $others others are now your buddies.';

  static const String newBuddyTitle = 'New buddy';
  static String newBuddyOne(String actor) => 'You and $actor are buddies now.';
  static String newBuddyMany(int count) => 'You and $count new buddies.';

  static String joinedTitle(String actor) => '$actor joined your trip';
  static String joinedBody(String trip, int travellers) => '$trip now has $travellers travellers.';
  static String joinedNoCount(String trip) => '$trip has new travellers.';

  static const String planTitle = 'Plan updated';
  static String planDay(String actor, int day, String trip) => '$actor changed Day $day of $trip.';
  static String planNoDay(String actor, String trip) => '$actor changed the plan of $trip.';

  static const String expenseAddedTitle = 'New expense';
  static String expenseAddedShare(String? item, String share) => '${item == null ? '' : '$item. '}Your share $share.';
  static String expenseAddedNoAmount(String trip) => 'A new expense was added to $trip.';

  static const String shareChangedTitle = 'Your share changed';
  static String shareChangedNow(String? item, String share) => '${item == null ? '' : '$item. '}Now $share.';
  static String shareChangedNoAmount(String trip) => 'Your share changed on $trip.';

  static String followRequest(String actor) => '$actor wants to follow you';
  static String newFollower(String actor) => '$actor started following you';
  static String followAccepted(String actor) => '$actor accepted your follow request';
  static String joinRequest(String actor, String? city) => city == null ? '$actor asked to join your trip' : '$actor asked to join your $city trip';
  static String joinAccepted(String actor, String? city) => city == null ? '$actor accepted your request' : '$actor accepted you on $city';
  static const String joinAcceptedPreview = 'You are in. It is in My Trips.';
  static String joinDeclined(String? city) => city == null ? 'Not this time' : 'Not this time for $city';
  static String followedPosted(String actor, String? city) => city == null ? '$actor posted a trip' : '$actor posted a trip to $city';
  static String quoted(String text) => '“$text”';
}
