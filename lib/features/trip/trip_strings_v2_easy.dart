import '../../models/browse_item.dart';

class TripStringsV2Easy {
  const TripStringsV2Easy._();

  static const String title = 'Make it easy';
  static const String peekLine = 'Stay, taxi and more. All optional.';
  static const String optional = 'All optional';
  static const String cardLine = 'All optional. Your plan is ready as it is.';
  static const String peekGettingThere = 'Getting there';
  static const String peekBack = 'Back';

  static String taxiDays(int days) => days <= 1 ? 'Day 1 · one driver' : 'Day 1 to Day $days · one driver';
  static const String helpMeFind = 'Help me find';
  static const String arrangeMyself = "I'll arrange myself";
  static const String skip = 'Skip';
  static const String undo = 'Undo';
  static const String change = 'Change';
  static const String replies = 'Replies';
  static const String retry = 'Retry';
  static const String done = 'Done';
  static const String viewSummary = 'View summary and share';
  static String dayInCity(int day, String city) => 'Day $day · $city';
  static const String view = 'View';
  static const String couldNotLoad = 'Could not load.';
  static const String wholeTrip = 'Whole trip';

  static const String gettingThere = 'Getting there';
  static const String comingBack = 'Coming back';
  static const String localTaxi = 'Local taxi';

  static String stayIn(String city) => 'Stay in $city';

  static String between(String from, String to) => '$from to $to';

  static const String betweenTitle = 'Between cities';
  static const String groupedLine = 'Grouped by city. Every row is optional.';

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String dateSpan(DateTime a, DateTime b) {
    final from = a.month == b.month && a.year == b.year ? '${a.day}' : '${a.day} ${_months[a.month - 1]}';
    return '$from to ${b.day} ${_months[b.month - 1]}';
  }

  static String stayDates(DateTime checkIn, DateTime checkOut) {
    final nights = DateTime.utc(checkOut.year, checkOut.month, checkOut.day)
        .difference(DateTime.utc(checkIn.year, checkIn.month, checkIn.day))
        .inDays;
    return nights <= 1 ? '${checkIn.day} ${_months[checkIn.month - 1]}' : dateSpan(checkIn, checkOut);
  }

  static const String pillTodo = 'To do';
  static const String pillAsked = 'Asked';
  static const String pillOffer = 'Offer received';
  static const String pillConfirmed = 'Confirmed';
  static const String pillBooked = 'Booked by you';
  static const String bookedLine = 'Booked by you';
  static const String more = 'More';
  static const String askLastNight = 'Ask last night';

  static String askMoreNights(int n) => 'Ask $n more nights';

  static String coverLine(String pill, int n, int total) => '$pill · $n of $total nights';
  static const String pillOwn = 'Arranged by you';
  static const String pillSaved = 'Saved';
  static const String pillSkipped = 'Skipped';
  static const String pillAttention = 'Needs you';
  static const String noTaxiHere = 'Taxi not available here';
  static const String noStayHere = 'Stay not available here';
  static const String ownTravelHint = 'Add your own travel';
  static const String ownStayHint = 'Add your own stay';
  static const String pillOffline = 'Offline';
  static const String connectDrivers = 'Connect to ask drivers';
  static const String connectHosts = 'Connect to ask hosts';

  static String asked(int n) => 'Asked $n · waiting';

  static String offerFrom(String name) => 'Offer from $name';

  static String offers(int n) => n == 1 ? '1 offer received' : '$n offers received';

  static const String confirmedLine = 'Confirmed';
  static const String savedLine = 'Saved on your plan';

  static String? savedDetail(int cars, int? total) {
    if (cars < 1 || total == null || total <= 0) return null;
    return '${cars == 1 ? '1 car' : '$cars cars'} · about ${BrowseItem.inr(total)}';
  }

  static const String youArrangeStay = "You'll arrange your stay";
  static const String youArrangeTaxi = "You'll arrange your taxi";
  static const String youArrangeTravel = "You'll arrange your travel";
  static const String youArrangeIt = "You'll arrange it";

  static const String stayHint = 'Homestays and hotels in this city';
  static const String taxiHint = 'One driver for the days you choose';
  static const String travelHint = 'Cars and drivers for this ride';
  static const String betweenHint = 'The ride from one city to the next';

  static const String confirmTitle = 'Mark as arranged?';
  static const String cancel = 'Cancel';
  static const String yes = 'Yes';

  static String confirmBody(String what) => 'You will arrange your $what yourself. We do not ask for any details.';

  static const String whatStay = 'stay';
  static const String whatTaxi = 'taxi';
  static const String whatTravel = 'travel';

  static String withdrawLine(int n) => n == 1 ? 'Withdraw 1 open ask too?' : 'Withdraw $n open asks too?';

  static const String withdraw = 'Withdraw';
  static const String keepAsks = 'Keep asks';
  static const String cancelConfirmedStay = 'Cancel the confirmed stay first.';
  static const String cancelConfirmedTaxi = 'Cancel the confirmed taxi first.';
  static const String cancelConfirmedTravel = 'Cancel the confirmed booking first.';

  static String miniBar(String what, String state) => '$what: $state';

  static const String waitingForReply = 'waiting for reply';
  static const String offerWaiting = 'offer waiting';

  static const String stayShort = 'Stay';
  static const String taxiShort = 'Taxi';
  static const String waysShort = 'Travel';

  static const String arrangementsHeading = 'YOUR ARRANGEMENTS';
  static const String shareDone = 'Done';
  static const String shareWaiting = 'Waiting';

  static const String sentBack = 'Back to plan';
  static const String askMoreStays = 'Ask more stays';
  static const String askMoreDrivers = 'Ask more drivers';
  static const String hostNotify = 'Hosts usually reply within a few hours. You get a notification.';
  static const String driverNotify = 'You get a notification when a driver replies.';
  static const String balanceAtCheckIn = 'Balance at check-in';
  static const String replyWillShow = 'Reply will show on your plan.';

  static String sentTo(int n) => n == 1 ? 'Sent to 1 host' : 'Sent to $n hosts';

  static String sentToDrivers(int n) => n == 1 ? 'Sent to 1 driver' : 'Sent to $n drivers';

  static String nightsOf(int nights) => '$nights ${nights == 1 ? 'night' : 'nights'}';

  static const String dateChanged = 'Dates changed';
  static const String carMissing = 'A car needs a new driver';
  static const String driverUnavailable = 'A driver is not available';

  static String stayProblem(String status) => switch (status) {
        'NotAvailable' => 'Host is full',
        'Expired' => 'No reply from host',
        'CancelledByOwner' => 'Host cancelled',
        _ => 'Host could not confirm',
      };

  static String taxiProblem(String status) => switch (status) {
        'NotAvailable' => 'Driver is busy',
        'Expired' => 'No reply from driver',
        'CancelledByOwner' => 'Driver cancelled',
        _ => 'Driver could not confirm',
      };
}
