import '../../../utils/money_format.dart';
import '../../owner_core/calendar/calendar_words.dart';
import '../../owner_core/strings/owner_shared_strings.dart';

abstract final class StayCalendarStrings {
  static const calendar = 'Calendar';
  static const past = OwnerSharedStrings.past;
  static const plus = OwnerSharedStrings.plus;
  static const freeSuffix = ' · Free';
  static const weekdays = OwnerSharedStrings.weekdays;

  static const legendFromApp = OwnerSharedStrings.fromApp;
  static const legendAddedByYou = OwnerSharedStrings.addedByYou;
  static const legendBlocked = 'Blocked';
  static const legendSpecial = 'Special price';

  static const bookingsYouAdded = 'Bookings you added';
  static const blockedRange = 'Blocked range';
  static const blockedRanges = 'Blocked ranges';
  static String meterCount(int used, int limit) => '$used of $limit';
  static String bookingsAddedOff(int used) => used == 1 ? '1 booking you added' : '$used bookings you added';
  static String blocksOff(int used) => used == 1 ? '1 blocked range' : '$used blocked ranges';
  static String onFree(int used, int limit) => '$used of $limit on Free';

  static const thisMonth = 'This month';
  static const summaryLockedSub = 'Booked, received, to collect';
  static String summaryOpenSub(DateTime month) => '${OwnerSharedStrings.monthTitle(month)} · only you see this';
  static const booked = 'Booked';
  static const received = 'Received';
  static const toCollect = 'To collect';
  static const toCollectOpen = 'To collect ›';
  static const hiddenAmount = '₹ ●●,●●●';
  static const summaryLockedLine = 'Plus adds up the amounts you write on each booking. Writing them stays free.';
  static String balanceDueButton(int n) => 'Balance due ($n)';
  static const summaryOpenNote = 'Added up from the money notes on each booking. Guests never see this, and the app never asks them to pay.';
  static const bookingsThisMonth = 'Bookings this month';
  static const amountsStayFree = 'Amounts stay free';
  static const freeEachBookingNote = 'Each booking keeps its own amounts and balance chip on Free. Plus adds them up for the month and lists who still owes.';
  static const plusWindowFooter = 'This month and the next 6 months. The last 3 months are under Past.';
  static const freeWindowLine = 'Free shows this month and the next 15 days. Plus shows the next 6 months.';
  static const tapHint = 'Tap a day to see its bookings. Bookings from the app appear by themselves.';
  static const addBooking = '+ Add booking';
  static const blockDays = 'Block days';
  static const edit = 'Edit';
  static const loadError = OwnerSharedStrings.couldNotLoad;

  static String festivalRowTitle(String label, DateTime from, DateTime to) => '$label · ${rangeTo(from, to)}';
  static String festivalWas(int percent, bool lower) => 'Your price was $percent% ${lower ? 'lower' : 'higher'} · removed 30 days after it ends';
  static String festivalNow(int percent, bool lower) => 'Your price $percent% ${lower ? 'lower' : 'higher'}';

  static const hiddenEntriesTitle = 'Bookings you added';
  static String shownCount(int shown, int limit) => '$shown of $limit shown';
  static String hiddenMore(int n) => n == 1 ? '1 more booking is hidden. It shows as dates pass.' : '$n more bookings are hidden. They show as dates pass.';
  static const blockedDays = 'Blocked days';
  static String stillBlocking(int n) => '$n still blocking';
  static const specialPrices = 'Special prices';
  static String liveCount(int n) => '$n live';
  static const live = 'Live';
  static const pausedOnFree = 'Paused on Free';
  static const yourDates = 'Your dates';
  static const afterPlusNote = 'Nothing is deleted. Your blocks keep working until they end. On Plus everything is back.';

  static String dayTitle(DateTime d) => '${OwnerSharedStrings.weekdays[d.weekday - 1]}, ${d.day} ${OwnerSharedStrings.monthsShort[d.month - 1]}';
  static String bookingsOnDay(int n) => n == 1 ? '1 booking on this day' : '$n bookings on this day';
  static String festivalDay(String festival, int n) => '$festival · ${bookingsOnDay(n)}';
  static const tileIn = 'IN';
  static const tileOut = 'OUT';
  static const checkIn = 'Check-in';
  static const checkOut = 'Check-out';
  static const basePriceTitle = 'Base price on this day';
  static const noSpecialPrice = 'No special price on these dates yet';
  static const setPriceForDays = 'Set a price for these days';
  static String rulePriceTitle(String name, int percent, bool lower) => '$name price, $percent% ${lower ? 'lower' : 'higher'}';
  static String rulePriceLine(String label, DateTime from, DateTime to, String room, int price) =>
      '$label · ${rangeTo(from, to)} · $room ${Money.exact(price)}';
  static const addOnDay = '+ Add on this day';
  static const blockThisDay = 'Block this day';
  static const open = OwnerSharedStrings.open;
  static const closeDaySheet = 'Close day sheet';

  static const addTitle = 'Add booking';
  static const editTitle = 'Edit booking';
  static const addSub = 'For bookings by phone or WhatsApp';
  static const editSub = OwnerSharedStrings.addedByYou;
  static const nameLabel = 'Name or label';
  static const required = 'Required';
  static const from = 'From';
  static const to = 'To';
  static const moneyNotes = OwnerSharedStrings.moneyNotes;
  static const onlyYouSee = OwnerSharedStrings.onlyYouSee;
  static const finalAmount = OwnerSharedStrings.finalAmount;
  static const wholeStay = 'Whole stay';
  static const receivedSoFar = OwnerSharedStrings.receivedSoFar;
  static const balanceToCollect = OwnerSharedStrings.balanceToCollect;
  static const balanceHint = OwnerSharedStrings.balanceHint;
  static const paidInFull = OwnerSharedStrings.paidInFull;
  static const paidInFullHint = OwnerSharedStrings.paidInFullHint;
  static const note = 'Note';
  static const optional = 'Optional';
  static const optionalAmount = 'Optional';
  static const zeroAmount = '0';
  static const blockToggle = 'Block these days';
  static const blockToggleSub = 'No booking, just days off';
  static const privacyLine = 'Only you see this booking and its amounts. They are your own notes, never sent to the guest. Do not add phone numbers.';
  static const removed90 = OwnerSharedStrings.removedAfter90;
  static const saveBooking = 'Save booking';
  static const nameNeeded = 'Add a name for this booking.';
  static const receivedAboveFinal = 'Received cannot be more than the final amount.';
  static const finalNeeded = OwnerSharedStrings.finalNeeded;
  static const moneyRange = OwnerSharedStrings.moneyRange;
  static const noPhone = OwnerSharedStrings.noPhone;
  static const outsideWindow = 'Pick a date inside your calendar.';
  static const notManual = 'A booking from the app cannot be changed here.';
  static String alreadyBookings(int n) => n == 1 ? 'You already have 1 booking on these days.' : 'You already have $n bookings on these days.';
  static const alreadyBlocked = 'These days are blocked by you.';

  static const blockTitle = 'Block days';
  static const blockSub = 'Days you are not taking guests';
  static const blockEditTitle = 'Block these days';
  static const blockEditSub = 'No booking, just days off';
  static const reason = 'Reason';
  static const reasonHintCreate = 'Only you see it';
  static const reasonHintPrivate = 'Private';
  static const travellersSeeFull = 'Travellers see your stay as full on these days.';
  static const blockSave = 'Block these days';
  static const blockSaveEdit = 'Save block';
  static const blockOverlap = 'These days are already blocked.';
  static const blockRule = '1 to 90 nights. Start today or within the next 180 days. Blocks cannot overlap each other.';
  static String confirmedInside(int n) => n == 1 ? '1 confirmed booking is inside these days' : '$n confirmed bookings are inside these days';
  static const staysConfirmed = 'It stays confirmed.';
  static String openEnquiriesFor(int n) => n == 1 ? '1 open enquiry is for these days.' : '$n open enquiries are for these days.';
  static const blockAnyway = 'Block anyway';
  static const back = 'Back';

  static const bookingTitle = 'Booking';
  static const fromTheApp = 'From the app';
  static const fromTheAppCancelled = 'From the app · cancelled';
  static const addedByYou = OwnerSharedStrings.addedByYou;
  static const fromApp = OwnerSharedStrings.fromApp;
  static const confirmed = 'Confirmed';
  static const cancelled = OwnerSharedStrings.cancelled;
  static const guests = 'Guests';
  static String guestsCount(int n) => n == 1 ? '1 guest' : '$n guests';
  static const room = 'Room';
  static const detail = 'Details';
  static const listedWhenAsked = 'Listed when asked';
  static const status = OwnerSharedStrings.status;
  static const dash = '–';
  static String cancelledBy(String who, DateTime on) => 'By $who on ${OwnerSharedStrings.dayMonth(on)}';
  static const appNote = 'Dates come from the confirmed enquiry. To change them, open the enquiry. Money notes are yours to write.';
  static String cancelledKept(String amount) => 'Kept so you remember the $amount you received. Not counted in Booked or To collect.';
  static String removedOn(DateTime d) => 'Removed automatically on ${OwnerSharedStrings.dayMonth(d)}, 90 days after this date.';
  static const openEnquiry = 'Open enquiry';
  static const editAmounts = 'Edit amounts';
  static const enquiryGone = 'This enquiry is no longer available.';
  static const travellerRemoved = 'Traveller removed';
  static String deletesOn(DateTime d) => 'Deletes on ${longDate(d)}';
  static const manualPrivacy = 'Only you see this booking and its amounts. Travellers and other owners never do.';
  static const editBooking = 'Edit booking';
  static const delete = 'Delete';
  static const deleteTitle = 'Delete this booking?';
  static const cancel = 'Cancel';
  static const save = 'Save';

  static const blockedDaysTitle = 'Blocked days';
  static const blockedDaysSub = 'Only you see the reason';
  static const guestsSee = 'Guests see';
  static const fullOnYourDates = 'Full on your dates';
  static const blocksOnFree = 'Blocks on Free';
  static const blocksMeter = 'Blocked ranges';
  static const blockDetailNote = 'Guests cannot ask for these days. Open enquiries are not closed.';
  static const blockRemoved90 = 'Removed automatically 90 days after it ends.';
  static const removeBlock = 'Remove block';
  static const removeBlockTitle = 'Remove this block?';
  static const remove = 'Remove';

  static const upcoming = 'Upcoming';
  static String nextDays(int days) => 'Next $days days';
  static const next6Months = 'Next 6 months';
  static String nextDaysUntil(int days, DateTime until) => 'Next $days days · until ${OwnerSharedStrings.dayMonth(until)}';
  static String next6MonthsUntil(DateTime until) => 'Next 6 months, until ${longDate(until)}';
  static String moreInWindow(int n, String window) => '$n more in the $window';
  static String windowWords(int? days) => days == null || days >= 180 ? 'next 6 months' : 'next $days days';
  static const seeAll = 'See all';
  static const seeAllUpcoming = 'See all upcoming bookings';
  static String beyondWindow(DateTime after, int n) =>
      'After ${OwnerSharedStrings.dayMonth(after)}: ${n == 1 ? '1 booking' : '$n bookings'} from the app (see Enquiries). Plus shows 6 months ahead.';
  static const viewCalendar = OwnerSharedStrings.viewCalendar;
  static String nights(int n) => n == 1 ? '1 night' : '$n nights';
  static String days(int n) => n == 1 ? '1 day' : '$n days';
  static String showMoreMonths(String from, String to, int n) => from == to ? 'Show $from · $n more' : 'Show $from to $to · $n more';
  static const showMore = OwnerSharedStrings.showMore;
  static String nowWas(String now, String was) => 'Now $now · was $was';
  static const datesChanged = 'Dates changed';
  static const movedNote = 'A change you accept moves the entry by itself. A cancelled one stays grey until it is removed.';

  static const past3Months = 'Past 3 months';
  static String pastSub(String name, DateTime from, DateTime to) =>
      '${name.isEmpty ? '' : '$name · '}${OwnerSharedStrings.dayMonth(from)} to ${OwnerSharedStrings.dayMonth(to)}';
  static const onlyYouSaw = 'only you saw this';
  static const olderRemoved = 'Older entries are removed automatically after 3 months.';

  static const balanceDue = 'Balance due';
  static String balanceDueSub(DateTime month, int amount) => '${OwnerSharedStrings.monthTitle(month)} · ${Money.exact(amount)} to collect';
  static const stillToCollect = 'STILL TO COLLECT';
  static const paidGroup = 'PAID IN FULL';
  static String ofAmount(int amount) => 'of ${Money.exact(amount)}';
  static const markPaid = 'Mark paid';
  static const markPaidTitle = 'Mark as paid in full?';
  static const yes = 'Mark paid';
  static const ownListNote = 'Your own list. Guests are never told about it and get no message from the app.';

  static const prevMonthOff = 'Previous month (off)';
  static const prevMonth = 'Previous month';
  static const nextMonth = 'Next month';
  static const nextMonthPlus = 'Next month, Plus only';
  static const pastBookings = 'Past bookings';
  static const today = 'today';

  static String rangeTo(DateTime from, DateTime to) {
    if (from.year == to.year && from.month == to.month) {
      return from.day == to.day ? OwnerSharedStrings.dayMonth(from) : '${from.day} to ${OwnerSharedStrings.dayMonth(to)}';
    }
    return '${OwnerSharedStrings.dayMonth(from)} to ${OwnerSharedStrings.dayMonth(to)}';
  }

  static String rangeDash(DateTime from, DateTime? to) {
    final t = to ?? from;
    if (from.year == t.year && from.month == t.month && from.day == t.day) return OwnerSharedStrings.dayMonth(from);
    if (from.year == t.year && from.month == t.month) return '${from.day} – ${OwnerSharedStrings.dayMonth(t)}';
    return '${OwnerSharedStrings.dayMonth(from)} – ${OwnerSharedStrings.dayMonth(t)}';
  }

  static String longDate(DateTime d) => '${d.day} ${OwnerSharedStrings.monthsShort[d.month - 1]} ${d.year}';
  static String weekdayDate(DateTime d) => '${OwnerSharedStrings.weekdays[d.weekday - 1]}, ${longDate(d)}';
  static String monthUpper(DateTime d) => OwnerSharedStrings.months[d.month - 1].toUpperCase();
  static String monthYearUpper(DateTime d) => OwnerSharedStrings.monthTitle(d).toUpperCase();
  static String shortUpper(DateTime d) => OwnerSharedStrings.monthsShort[d.month - 1].toUpperCase();
  static String spokenDate(DateTime d) => '${d.day} ${OwnerSharedStrings.months[d.month - 1]}';
  static String dayCellLabel(DateTime d, {required bool today, required int app, required int own, required bool blocked}) {
    final parts = <String>[spokenDate(d), if (today) StayCalendarStrings.today];
    if (app > 0) parts.add(app == 1 ? '1 booking from the app' : '$app bookings from the app');
    if (own > 0) parts.add(own == 1 ? '1 booking added by you' : '$own bookings added by you');
    if (blocked) parts.add(legendBlocked);
    return parts.join(', ');
  }
}

class StayCalendarWords extends CalendarWords {
  const StayCalendarWords();

  @override
  String get title => StayCalendarStrings.calendar;
  @override
  String get addEntry => StayCalendarStrings.addBooking;
  @override
  String get legendBlocked => StayCalendarStrings.legendBlocked;
  @override
  String get legendSpecial => StayCalendarStrings.legendSpecial;
  @override
  String get tapHint => StayCalendarStrings.tapHint;
  @override
  String get emptyDay => '';
  @override
  String get monthLockLine => StayCalendarStrings.freeWindowLine;
  @override
  String meterLabel(String key) => switch (key) {
        'CalendarEntries' => StayCalendarStrings.bookingsYouAdded,
        'BlockedRanges' => StayCalendarStrings.blockedRanges,
        _ => '',
      };
  @override
  String hiddenLine(int count) => StayCalendarStrings.hiddenMore(count);
  @override
  String get loadError => StayCalendarStrings.loadError;
}
