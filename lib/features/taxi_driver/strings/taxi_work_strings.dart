abstract final class TaxiWorkStrings {
  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String day(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  // o_tx_13, o_tx_36: ring screen
  static const incomingRequest = 'Incoming request';
  static const taxiRequest = 'Taxi request';
  static const newTaxiRequest = 'New taxi request';
  static const decline = 'Decline';
  static const accept = 'Accept';
  static const swipeUp = 'Swipe up to answer';
  static const opening = 'Getting the request';
  static const oneMoment = 'One moment.';
  static const couldNotOpen = 'Could not open the request';
  static String stillYours(String left) => 'Check your internet. The request is still yours for $left.';
  static const couldNotOpenNoTime = 'Check your internet and try again.';
  static const tryAgain = 'Try again';
  static const close = 'Close';
  static const missed = 'Missed';
  static const missedLine = 'Went to the next drivers.';
  static const notAMiss = 'This does not count as a miss.';
  static const pausedOnFreeSub = 'Choose which route stays, or get Plus to use all your routes.';
  static const chooseYourRoute = 'Choose your route';
  static const requestsPausedTitle = 'Taxi requests are paused for now';
  static const requestsPausedSub = 'New requests will come back soon.';
  static const answerFailed = 'Could not send your answer. Try again.';

  // Every ring-end line (o_tx_36 box)
  static const endTaken = 'Taken by another driver';
  static const endTravellerCancelled = 'The traveller cancelled the request';
  static const endClosed = 'This request is closed';
  static const endOffline = 'You are offline';
  static const endRouteRemoved = 'You removed this route';
  static const endPausedOnFree = 'This route is paused on Free.';
  static const endAccepted = 'You accepted this request';
  static const endDeclined = 'You declined this request';

  static String sightseeing(int days) => 'Sightseeing $days ${days == 1 ? 'day' : 'days'}';
  static const pickup = 'Pickup';
  static const drop = 'Drop';
  static String seats(int seats, int travellers) => '$seats seater · $travellers ${travellers == 1 ? 'traveller' : 'travellers'}';
  static String seater(int seats) => '$seats seater';

  // o_tx_14: Requests tab
  static const requests = 'Requests';
  static const today = 'Today';
  static const tripLeads = 'Trip leads';
  static const pastTrips = 'Past trips ›';
  static const groupNew = 'New';
  static const groupBooked = 'Booked';
  static const groupEarlier = 'Earlier';
  static const traveller = 'Traveller';
  static String pickupAt(String city) => '$city pickup';
  static String timeLeft(String t) => '$t left';
  static const chipMissed = 'Missed';
  static const chipNotSelected = 'Not selected';
  static const chipClosed = 'Closed';
  static const chipPriceNotAgreed = 'Price not agreed';
  static const chipBooked = 'Booked';
  static const chipAccepted = 'Accepted';
  static const missedNote = 'Went to the next drivers';
  static const notSelectedNote = 'The traveller chose another driver';
  static const closedNote = 'This request is closed';
  static const priceNote = 'Price not agreed';
  static const waitingNote = 'Waiting for traveller to choose';
  static const selectedNote = 'Selected you';
  static const rideEnded = 'This ride has ended';
  static String daysShort(int days) => '$days ${days == 1 ? 'day' : 'days'}';
  static const showMore = 'Show more';
  static const noRequests = 'No requests yet';
  static const noRequestsLine = 'New taxi requests will show up here.';
  static const couldNotLoad = 'Could not load requests';
  static const checkConnection = 'Check your connection and try again.';
  static const showingLast = 'Could not refresh. Showing your last list.';
  static const pausedTitle = 'Requests are paused right now';
  static const pausedLine = 'New requests will come back soon. Pull down to check again.';
  static const tooManyTries = 'Too many tries. Wait a minute.';
  static const noConnection = 'No connection. Please try again.';
  static const wentToNext = 'This request went to the next drivers.';
  static const pausedNow = 'Requests are paused right now.';
  static const datesTaken = 'You already have a booking on these dates.';
  static const didNotWork = 'That did not work. Please try again.';

  // o_tx_15, o_tx_37, o_tx_38: request detail
  static const titleRinging = 'Request details';
  static const titleAccepted = 'Request accepted';
  static const titleSelected = 'Booking request';
  static const titleBooked = 'Booking';
  static const titleEnded = 'Request';
  static String selectedCountdown(String left) => 'Selected you · confirm in $left';
  static String bookedChip(String range) => 'Booked · $range';
  static const confirmBooking = 'Confirm booking';
  static const callTraveller = 'Call traveller';
  static const withdraw = 'Withdraw';
  static const myBookings = 'My bookings';
  static const timeToConfirmOver = 'Time to confirm is over';
  static const loadThisFailed = 'Could not load this request.';
  static String datesBooked(String from, String to) => 'Dates already booked. You have another booking from $from to $to.';

  static String manualTrips(List<DateTime> days) {
    if (days.isEmpty) return '';
    if (days.length == 1) return 'You added a trip on ${day(days.first)}.';
    final names = [for (final d in days) day(d)];
    final head = names.sublist(0, names.length - 1).join(', ');
    return 'You added trips on $head and ${names.last}.';
  }

  // o_tx_37 B
  static const withdrawRequestTitle = 'Withdraw from request';
  static const withdrawRequestSub = 'The traveller can choose another driver.';
  static const reason = 'Reason';
  static const askedByTraveller = 'Asked by the traveller';
  static const confirmWithdraw = 'Confirm withdraw';
  static const keep = 'Keep';

  // o_tx_38 B
  static const withdrawBookingTitle = 'Withdraw from booking';
  static String withdrawBookingSub(String name, String range) => name.isEmpty ? range : '$name · $range';
  static const whyWithdrawing = 'Why are you withdrawing?';
  static const required = 'Required';
  static String reopensNote(String name) =>
      name.isEmpty
          ? 'The request opens again for other drivers. Your calendar entry stays, marked Cancelled.'
          : '$name’s request opens again for other drivers. Your calendar entry stays, marked Cancelled.';
  static const keepBooking = 'Keep booking';
  static const withdrewBooking = 'You withdrew from this booking';

  static const changedPlan = 'Changed plan';
  static const notReachable = 'Not reachable';
  static const priceNotAgreed = 'Price not agreed';
  static const vehicleIssue = 'Vehicle issue';
  static const other = 'Other';

  // o_tx_39: bookings section
  static const fromTheApp = 'From the app';
  static const last90Days = 'last 90 days';
  static const chipOnTrip = 'On trip';
  static const chipCompleted = 'Completed';
  static const chipCancelled = 'Cancelled';
  static const chipOccupied = 'Occupied';
  static const endTrip = 'End trip';
  static const endTripTitle = 'End this trip?';
  static String endTripBody(String name) => name.isEmpty ? 'The traveller will be asked to rate you.' : '$name will be asked to rate you.';
  static const notYet = 'Not yet';
  static const tripEnded = 'Trip ended';
  static const alreadyChanged = 'This booking has already changed';
  static String rated(String name, int stars) => '${name.isEmpty ? 'The traveller' : name} rated you $stars ${stars == 1 ? 'star' : 'stars'}';
  static String travellerCancelled(String name) =>
      name.isEmpty ? 'The traveller cancelled. Your dates are free again.' : '$name cancelled. Your dates are free again.';
  static const bakhliCancelled = 'Cancelled by Bakhli.';
  static const youCancelled = 'You withdrew from this booking.';
  static const noBookings = 'No bookings yet';
  static const noBookingsLine = 'Trips you confirm will show up here.';
  static const couldNotLoadBookings = 'Could not load bookings';
  static const somethingWrong = 'Something went wrong. Please try again.';
  static String rangeOf(DateTime? from, DateTime? to) {
    if (from == null) return '';
    if (to == null || (to.year == from.year && to.month == from.month && to.day == from.day)) return day(from);
    return '${day(from)} to ${day(to)}';
  }

  static String shortRange(DateTime? from, DateTime? to) {
    if (from == null) return '';
    if (to == null) return day(from);
    if (from.month == to.month && from.year == to.year) return '${from.day} to ${day(to)}';
    return '${day(from)} to ${day(to)}';
  }

  static String bookingLine(String place, String name) => [place, name].where((s) => s.isNotEmpty).join(' · ');

  // o_tx_40: trip leads
  static const newLeads = 'New';
  static String newCount(int n) => 'New ($n)';
  static const replied = 'Replied';
  static const booked = 'Booked';
  static const closed = 'Closed';
  static const chipNew = 'New';
  static const chipBookedYou = 'Booked you';
  static const chipConfirmed = 'Confirmed';
  static const payLine = 'Pay the driver directly. Bakhli does not take or hold payment.';
  static const changeAgainInfo = 'If the traveller changes the trip, you are asked to confirm again.';
  static const fareHint = 'You can change the fare 3 times.';
  static String fareHintLeft(int n) => 'You can change the fare $n ${n == 1 ? 'time' : 'times'}.';
  static const leadsEmpty = 'Travellers planning a trip send them here.';
  static const leadsAreaOff = 'New leads are paused in your area.';
  static const notAvailable = 'Not available';
  static const confirmFare = 'Confirm fare';
  static const notMe = 'Not me';
  static const yesConfirm = 'Yes, confirm';
  static const cancelBooking = 'Cancel booking';
  static const reportTraveller = 'Report traveller';
  static const block = 'Block';
  static String listedFare(int travellers, String fare) => '$travellers ${travellers == 1 ? 'traveller' : 'travellers'} · your listed fare $fare';
  static String yourFare(String fare, int travellers) => 'Your fare $fare · $travellers ${travellers == 1 ? 'traveller' : 'travellers'}';
  static String inCalendar(String fare) => 'Your fare $fare · in your calendar as From app';

  // o_tx_21, o_tx_49: notification rows built by the app
  static const tagTaxi = 'TAXI';
  static const tagPlan = 'PLAN';
  static const tagFestival = 'FESTIVAL';
  static const tagRing = 'RING';
  static const tagRequest = 'REQUEST';
  static const tagReady = 'READY';
  static const tagBooking = 'BOOKING';
  static const tagLead = 'LEAD';
  static const tagReminder = 'REMINDER';
  static String festivalTitle(String name, String date) => '$name starts $date';
  static const festivalBody = 'Go online and check your fares.';
  static const plansStartedTitle = 'Plans have started';
  static String routesHidden(int n) => '$n ${n == 1 ? 'route is' : 'routes are'} hidden on Free. Nothing is deleted.';
  static String plansStartTitle(String date) => 'Plans start on $date';
  static String freeKeeps(int routes, {int trialDays = 0}) =>
      'Free keeps $routes ${routes == 1 ? 'route' : 'routes'}.${trialDays > 0 ? ' Try Plus free for $trialDays ${trialDays == 1 ? 'day' : 'days'}.' : ''}';
  static const noLongerAvailable = 'This is no longer available.';
}
