import '../../../utils/money_format.dart';
import '../../owner_core/strings/owner_shared_strings.dart';

abstract final class TaxiCalendarStrings {
  // Bookings tab (o_tx_24, o_tx_29, o_tx_31, o_tx_47 A)
  static const bookings = 'Bookings';
  static const previousMonth = 'Previous month';
  static const nextMonth = 'Next month';
  static const nextMonthPlus = 'Next month, needs Plus';
  static const legendFromApp = 'From app';
  static const legendAddedByYou = 'Added by you';
  static const legendFestival = 'Festival';
  static String festivalTitle(String name, String range) => '$name · $range';
  static String festivalState(String state) => 'Festival in $state · fares unchanged';
  static const tripsYouAdded = 'Trips you added';
  static const fromAppThisMonth = 'From the app this month';
  static String monthsAhead(int n) => n == 1 ? '1 month' : '$n months';
  static const aheadYouCanSee = 'Ahead you can see';
  static const tripsThisMonth = 'Trips this month';
  static const amountsStayFree = 'Amounts stay free';
  static const addTrip = '+ Add trip';
  static const add = '+ Add';
  static const fromTheApp = 'From the app';
  static const allConfirmedTrips = 'All confirmed trips';
  static const couldNotLoadBookings = 'Could not load bookings';
  static String shownOf(int shown) => '$shown of $shown shown';
  static String hiddenTrips(int n) => n == 1 ? '1 more trip is hidden. They show as dates pass.' : '$n more trips are hidden. They show as dates pass.';
  static const nothingDeleted = 'Nothing is deleted. App bookings are never hidden.';
  static String freeWindow(int days) => 'Free · next $days days';

  // Money card (o_tx_24, o_tx_29, o_tx_30, o_tx_31, o_tx_32)
  static const thisMonth = 'This month';
  static const bookedReceivedToCollect = 'Booked, received, to collect';
  static String monthOnlyYou(DateTime m) => '${OwnerSharedStrings.monthTitle(m)} · only you see this';
  static const booked = 'Booked';
  static const received = 'Received';
  static const toCollect = 'To collect';
  static const toCollectOpen = 'To collect ›';
  static const hiddenAmount = '₹ ●●,●●●';
  static const lockedLine = 'Plus adds up the amounts you write on each booking. Writing them stays free.';
  static String balanceDueCount(int n) => 'Balance due ($n)';
  static const addedUpLine = 'Added up from the money notes on each trip. Travellers never see this.';
  static const nothingToCollect = 'Nothing to collect';

  // Morning reminder (o_tx_24, o_tx_29)
  static const morningReminder = 'Morning reminder';
  static const reminderOn = 'Today’s trips at 7:00 am';
  static const reminderLocked = 'Today’s trips at 7:00 am · Plus';

  // Day sheet (o_tx_25)
  static String tripsOnDay(int n) => n == 1 ? '1 trip on this day' : '$n trips on this day';
  static const nothingOnDay = 'Nothing on this day.';
  static const addTripOnDay = '+ Add trip on this day';
  static const tileAll = 'All';
  static const tileDay = 'DAY';

  // Add / edit trip (o_tx_26, o_tx_47 C)
  static const addTripTitle = 'Add trip';
  // Not drawn by any frame: the edit title is the frame's add title (OPEN for the owner).
  static const editTripTitle = 'Add trip';
  static const addTripSub = 'For trips booked by phone or WhatsApp';
  static const nameOrLabel = 'Name or label';
  static const required = 'Required';
  static const date = 'Date';
  static const time = 'Time';
  static const optional = 'Optional';
  static const from = 'From';
  static const to = 'To';
  static const finalHint = 'This trip';
  static const note = 'Note';
  static const privacy = 'Only you see this trip and its amounts. They are your own notes, never sent to the guest. Do not add phone numbers.';
  static String meterOnFree(int used, int limit) => '$used of $limit on Free';
  static String meter(int used, int limit) => '$used of $limit';
  static const saveTrip = 'Save trip';
  static const labelEmpty = 'Add a name for this trip.';
  static const outsideWindow = 'Pick a date inside your calendar.';
  static const keepVisible = 'Still take bookings this day';
  static const keepVisibleSub = 'Turn on for a short trip, like an airport drop';
  static const entryEndedType = 'EntryEnded';
  static const entryEnded = 'This trip has ended. You can still change the amounts.';
  static String overlap(int n) => n == 1 ? 'You already have 1 booking on this day.' : 'You already have $n bookings on this day.';

  // Entry detail (o_tx_27, o_tx_46 B, C, D)
  static const booking = 'Booking';
  static const trip = 'Trip';
  static const fromTheAppCancelled = 'From the app · cancelled';
  static const confirmed = 'Confirmed';
  static const traveller = 'Traveller';
  static const travellerRemoved = 'Traveller removed';
  static const pickup = 'Pickup';
  static const drop = 'Drop';
  static const travellers = 'Travellers';
  static String travellersCount(int n) => n == 1 ? '1 traveller' : '$n travellers';
  static const car = 'Car';
  static String seater(int n) => '$n seater';
  static const places = 'Places';
  static const cancelledRow = 'Cancelled';
  static String cancelledBy(String name, DateTime d) => 'By $name on ${OwnerSharedStrings.dayMonth(d)}';
  static const label = 'Label';
  static const dash = '–';
  static const allDay = 'all day';
  static const allDayCap = 'All day';
  static String dayAllDay(DateTime d) => '${OwnerSharedStrings.dayMonth(d)} · all day';
  static String daysAllDay(int n) => '$n days · all day';
  static String allDayOf(String title) => 'All day · $title';
  static const confirmedNote = 'Date and places come from the confirmed request. Changes happen there. Money notes are yours to write.';
  static const emptyMoneyNote = 'Dates come from the booking. Add amounts if you want your own record.';
  static String cancelledNote(DateTime until) => 'Your dates are free again. Notes stay until ${OwnerSharedStrings.dayMonth(until)}.';
  static String removedAfter(DateTime d) => 'Removed automatically 90 days after ${OwnerSharedStrings.dayMonth(d)}.';
  static const openBooking = 'Open booking';
  static const editAmounts = 'Edit amounts';
  static const addAmounts = 'Add amounts';
  static const edit = 'Edit';
  static const delete = 'Delete';
  static const deleteTitle = 'Delete this trip?';
  static const deleteBody = 'Its money notes go with it.';
  static const keep = 'Keep';
  static const bookingGone = 'This booking is no longer available.';

  // Upcoming (o_tx_23, o_tx_48)
  static const upcoming = 'Upcoming';
  static const upcomingBookings = 'Upcoming bookings';
  static String nextDays(int n) => 'Next $n days';
  static String nextMonths(int n) => 'Next ${monthsAhead(n)}';
  static String until(String window, DateTime d) => '$window, until ${d.day} ${OwnerSharedStrings.months[d.month - 1]} ${d.year}';
  static const seeAll = 'See all';
  static String afterWindow(DateTime d, int count, int plusMonths) =>
      'After ${OwnerSharedStrings.dayMonth(d)}: ${count == 1 ? '1 booking' : '$count bookings'} from the app (see Bookings). Plus shows ${monthsAhead(plusMonths)} ahead.';
  static const viewCalendar = OwnerSharedStrings.viewCalendar;
  static const past = OwnerSharedStrings.past;

  // Past (o_tx_34)
  static const past3Months = 'Past 3 months';
  static String pastSub(String? plate, DateTime from, DateTime to) {
    final range = '${OwnerSharedStrings.dayMonth(from)} to ${OwnerSharedStrings.dayMonth(to)}';
    return plate == null || plate.isEmpty ? range : '$plate · $range';
  }

  static const olderRemoved = 'Older entries are removed automatically after 3 months.';

  // Balance due (o_tx_32)
  static const balanceDue = 'Balance due';
  static String balanceDueSub(DateTime m, int toCollect) => '${OwnerSharedStrings.monthTitle(m)} · ${Money.exact(toCollect)} to collect';
  static const stillToCollect = 'STILL TO COLLECT';
  static const paidInFullHead = 'PAID IN FULL';
  static String ofFinal(String route, int finalAmount) => route.isEmpty ? 'of ${Money.exact(finalAmount)}' : '$route · of ${Money.exact(finalAmount)}';
  static const markPaid = 'Mark paid';
  static String showMorePaid(int n) => n == 1 ? 'Show 1 more paid trip' : 'Show $n more paid trips';
  // Mark paid "asks first" (o_tx_32 caption); no frame or doc gives the words (OPEN for the owner).
  static const markPaidAskTitle = 'Mark paid?';
  static String markPaidAskBody(String label) => label;
  static const markPaidAskCancel = keep;

  // Row text
  static String timeAm(int hour, int minute) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m ${hour < 12 ? 'am' : 'pm'}';
  }

  static String tileTime(int hour, int minute) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${minute.toString().padLeft(2, '0')}';
  }

  static String tileAmPm(int hour) => hour < 12 ? 'AM' : 'PM';
  static String routeTo(String from, String to) => '$from to $to';
  static String pickupOf(String from) => '$from pickup';
  static String toPlace(String to) => 'To $to';
  static String toPlaceLower(String to) => 'to $to';
  static String days(int n) => n == 1 ? '1 day' : '$n days';
  static String dateRange(DateTime a, DateTime b) => a.month == b.month && a.year == b.year
      ? '${a.day} to ${OwnerSharedStrings.dayMonth(b)}'
      : '${OwnerSharedStrings.dayMonth(a)} to ${OwnerSharedStrings.dayMonth(b)}';
  static String sectionMonth(DateTime m) => '${OwnerSharedStrings.months[m.month - 1].toUpperCase()} ${m.year}';
  static String sectionMonthOnly(DateTime m) => OwnerSharedStrings.months[m.month - 1].toUpperCase();
  static String tileMonth(DateTime d) => OwnerSharedStrings.monthsShort[d.month - 1].toUpperCase();
  static String daySheetTitle(DateTime d) => '${_weekdays[d.weekday - 1]}, ${OwnerSharedStrings.dayMonth(d)}';
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static String dateField(DateTime d) => '${OwnerSharedStrings.dayMonth(d)} ${d.year}';
  static String joinDot(Iterable<String> parts) => parts.where((p) => p.isNotEmpty).join(' · ');
}
