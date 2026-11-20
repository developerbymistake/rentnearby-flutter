import '../shared/buddy_format.dart';

abstract final class ViewerStrings {
  static const String inviteTitle = 'Trip invite';
  static const String sharedWithMe = 'SHARED WITH ME';
  static const String sharedWithMeTitle = 'Shared with me';
  static const String myTripsTitle = 'My trips';
  static const String leaveTrip = 'Leave trip';
  static const String travellersTitle = 'Travellers';
  static const String myShareTitle = 'My share';
  static const String overviewTitle = 'Trip overview';

  static String fromOwner(String name, String? username) => username == null || username.isEmpty ? 'From $name' : 'From $name · $username';
  static String fromOwnerShort(String name) => 'From $name';
  static const String youAreInvited = 'YOU ARE INVITED';
  static String joinAsViewer(String owner, String title) => 'Join $owner’s $title as a viewer';
  static const String arrow = '→';
  static const String dates = 'Dates';
  static const String days = 'Days';
  static const String travellers = 'Travellers';
  static const String notSet = 'Not set';
  static String dayCount(int n) => BuddyFormat.plural(n, 'day', 'days');
  static String travellerCount(int n) => BuddyFormat.plural(n, 'traveller', 'travellers');
  static const String youWillSee = 'You will see';
  static const String youWillNotSee = 'You will not see';
  static const String tick = '✓';
  static const String cross = '✕';
  static const List<String> willSee = ['Day plan and dates', 'Stay and taxi summary', 'Expenses and your share'];
  static const List<String> willNotSee = ['Chats and offers', 'Phone numbers', 'Payment ids'];
  static const String notNow = 'Not now';
  static const String joinTrip = 'Join trip';
  static const String decline = 'Decline';
  static const String moreOptions = 'More options';
  static const String inviteDeclined = 'Invite declined';
  static const String joinedAsViewer = 'You joined as a viewer';
  static const String open = 'Open';

  static const String inviteEnded = 'This invite has ended';
  static String askForNew(String? owner) => owner == null || owner.isEmpty ? 'Ask the owner for a new one.' : 'Ask $owner for a new one.';
  static const String tripFull = 'This trip is full';
  static String askToMakeRoom(String? owner) => owner == null || owner.isEmpty ? 'Ask the owner to make room.' : 'Ask $owner to make room.';
  static const String reasonCancelled = 'Invite cancelled by the owner';
  static const String reasonExpired = 'Invite expired';
  static const String reasonDeclined = 'You declined this invite';
  static const String goToMyTrips = 'Go to my trips';

  static const String inviteWaiting = 'Invite waiting';
  static String fromLine(String owner, String dates) => dates.isEmpty ? 'from $owner' : 'from $owner · $dates';
  static String invitedYou(String owner, String title) => '$owner invited you to $title';
  static String daysCities(int days, int cities) => '${dayCount(days)} · ${BuddyFormat.plural(cities, 'city', 'cities')}';
  static const String view = 'View';

  static const String viewer = 'Viewer';
  static String byLine(String owner, String dates) => dates.isEmpty ? 'by $owner' : 'by $owner · $dates';
  static String places(int n) => BuddyFormat.plural(n, 'place', 'places');
  static String travellersWord(int n) => n == 1 ? 'traveller' : 'travellers';
  static String percent(int n) => '$n%';
  static const String ready = 'ready';
  static const String stay = 'Stay';
  static const String taxi = 'Taxi';
  static const String plan = 'Plan';
  static const String notAdded = 'not added';
  static const String arranging = 'arranging';
  static const String booked = 'booked';
  static const String saved = 'saved';
  static String startsOn(String d) => 'Starts $d';
  static String dayOf(int n, int total) => 'Day $n of $total';
  static const String datesNotSet = 'Dates not set';
  static String endedOn(String d) => 'Ended $d';
  static const String openThePlan = 'Open the plan';
  static String pastShared(int n) => 'Past shared trips ($n)';

  static const String left = 'Left';
  static const String removed = 'Removed';
  static String youOwe(String name, int amount) => 'You owe $name ${BuddyFormat.rupees(amount)}';
  static String youGetBack(int amount) => 'You get back ${BuddyFormat.rupees(amount)}';
  static String expensesYouShare(int n) => n == 1 ? '1 expense you share' : '$n expenses you share';
  static const String seeMyShare = 'See my share';

  static String sharedBy(String owner) => 'Shared by $owner';
  static String tripLine(int cities, int days, int travellers) =>
      '${BuddyFormat.plural(cities, 'city', 'cities')} · ${dayCount(days)} · ${travellerCount(travellers)}';
  static const String itinerary = 'Itinerary';
  static const String savedChip = 'Saved';
  static String itineraryLine(int days, int spots, {required bool hasDates}) =>
      '${dayCount(days)}, ${places(spots)}${hasDates ? '' : ' · Dates not set'}';
  static const String bookedChip = 'Booked';
  static const String arrangingChip = 'Arranging';
  static const String completedChip = 'Completed';
  static const String notBookedYet = 'Not booked yet';
  static const String viewBooking = 'View booking';
  static const String viewStays = 'View stays';
  static String taxiLine(String? vehicle, String? driver, String? when) => [vehicle, driver, when].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
  static String stayLine(String name, int nights, int more) => '$name, ${BuddyFormat.plural(nights, 'night', 'nights')}${more > 0 ? ' +$more more' : ''}';
  static String joined(int n) => '$n joined';
  static const String seeAll = 'See all';
  static const String expenses = 'Expenses';
  static String dayChip(int n) => 'Day $n';
  static String spentLine(int spent, int share) => 'Spent ${BuddyFormat.rupees(spent)} · Your share ${BuddyFormat.rupees(share)}';
  static String noExpenses(String owner) => '$owner has not added any expense yet';
  static const String offlineCopy = 'Offline. Showing the saved copy.';

  static const String vehicle = 'Vehicle';
  static const String driver = 'Driver';
  static const String pickup = 'Pickup';
  static const String checkIn = 'Check-in';
  static const String checkOut = 'Check-out';
  static String nights(int n) => BuddyFormat.plural(n, 'night', 'nights');
  static const String nightsLabel = 'Nights';
  static const String allDays = 'All days';
  static const String back = '‹';

  static const String noLongerOnTrip = 'You are no longer on this trip.';
  static const String shareStillOpen = 'Your share is still open.';
  static const String tripDeleted = 'This trip was deleted.';
  static const String tripDeletedLine = 'The plan and the expenses are gone.';
  static String ghostLine(String dates, String? owner) {
    final by = owner == null || owner.isEmpty ? '' : 'by $owner';
    if (dates.isEmpty) return by;
    return by.isEmpty ? dates : '$dates · $by';
  }

  static String dayPlanLine(int days, String dates, String owner) => dates.isEmpty ? '${dayCount(days)} · by $owner' : '${dayCount(days)} · $dates · by $owner';
  static const String map = 'Map';
  static String legRange(int first, int last, String dates) {
    final d = first == last ? 'Day $first' : 'Day $first-$last';
    return dates.isEmpty ? d : '$d · $dates';
  }

  static String legDetail(int spots, int nights) => '${BuddyFormat.plural(spots, 'spot', 'spots')} · ${BuddyFormat.plural(nights, 'night', 'nights')}';
  static String dayTitle(int day, String? date) => date == null ? 'Day $day' : 'Day $day · $date';
  static const String restDay = 'Rest day';
  static String spentOnDay(int amount) => 'Spent ${BuddyFormat.rupees(amount)} on this day';
  static const String noPlacesYet = 'No places on this day yet';
  static const String noRouteYet = 'No places to show on the map yet.';

  static const String joinedSection = 'JOINED';
  static String you(String name) => '$name (You)';
  static String dot(String? a, String b) => a == null || a.isEmpty ? b : '$a · $b';
  static const String createdTheTrip = 'Created the trip';
  static String joinedOn(String d) => 'Joined $d';
  static const String owner = 'Owner';
  static String onlyOwnerCan(String owner) => 'Only $owner can invite or remove people.';
  static const String leaveTitle = 'Leave this trip?';
  static const String leaveBody = 'You will lose the plan. Your share stays until it is settled.';
  static const String leave = 'Leave';
  static const String youLeft = 'You left the trip';

  static String myShareSub(String title, String owner) => '$title · by $owner';
  static String youOweName(String name) => 'You owe $name';
  static const String nothingToPay = 'Nothing to pay';
  static const String owedToYou = 'Owed to you';
  static String paidTo(String name) => 'Paid to $name';
  static const String yourShare = 'Your share';
  static const String youPaid = 'You paid';
  static const String yourPayment = 'YOUR PAYMENT';
  static String youPay(String name) => 'You pay $name';
  static String paysYou(String name) => '$name pays you';
  static const String notPaidYet = 'Not paid yet';
  static String waitingFor(String name) => 'You said paid. Waiting for $name to confirm.';
  static const String receivedLine = 'Received';
  static const String openBadge = 'Open';
  static const String saysPaidBadge = 'Says paid';
  static const String receivedBadge = '✔ Received';
  static const String iHavePaid = 'I have paid';
  static const String notPaid = 'Not paid';
  static String sharedExpenses(int n) => 'EXPENSES YOU SHARE · $n';
  static String dayPaidBy(int day, String name) => 'Day $day · Paid by $name';
  static String yourShareAmount(int amount) => 'Your share ${BuddyFormat.rupees(amount)}';

  static String havePaidTitle(int amount) => 'Have you paid ${BuddyFormat.rupees(amount)}?';
  static String havePaidBody(String name) => 'Tap Yes only after you have sent the money to $name. $name is told and confirms. You can take it back until $name confirms.';
  static const String notYet = 'Not yet';
  static const String yesPaid = 'Yes, I paid';
  static const String notPaidTitle = 'Mark as not paid?';
  static String notPaidBody(String name) => 'Use this if the money did not go. $name is told and the payment opens again.';
  static const String keepIt = 'Keep it';
}
