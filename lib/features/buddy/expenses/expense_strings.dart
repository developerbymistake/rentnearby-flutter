import '../../../utils/money_format.dart';
import '../shared/buddy_format.dart';

abstract final class ExpenseStrings {
  static const String title = 'Expenses';
  static const String tabByDay = 'By day';
  static const String tabBalances = 'Balances';
  static const String addExpense = '+ Add expense';
  static const String spentSoFar = 'Spent so far';
  static const String settleUp = 'Settle up';
  static const String tripSummary = 'Trip summary';
  static const String moreOptions = 'More options';
  static const String yourShareCell = 'Your share';
  static const String travellersCell = 'Travellers';
  static const String expensesCell = 'Expenses';

  static String headerOwner(String trip, int day) => '$trip · Day $day';
  static String headerEnded(String trip, DateTime end) => '$trip · ended ${BuddyFormat.dayMonth(end)}';
  static String headerViewer(String trip, String owner) => '$trip · by $owner';

  static String suggestionTitle(String name, int amount) => '$name is booked for ${BuddyFormat.rupees(amount)}';
  static const String suggestionLine = 'Add it to expenses?';
  static const String skip = 'Skip';
  static const String add = 'Add';

  static const String emptyTitle = 'No expenses yet';
  static const String emptyLine = 'Add what the group spends, day by day.';
  static String emptyViewer(String owner) => '$owner has not added any expense yet';

  static String paidBy(String name) => 'Paid by $name';
  static const String paidByYou = 'Paid by you';
  static String paidShared(String payer, int n) => '$payer · Shared by $n';
  static String yourShare(int amount) => 'Your share ${BuddyFormat.rupees(amount)}';
  static const String tagEdited = 'Edited';
  static const String tagBookingCancelled = 'Booking cancelled';
  static String showTwoDays(int a, int b, int sum) => 'Show Day $a and Day $b · ${BuddyFormat.rupees(sum)}';
  static String showDayRange(int a, int b, int sum) => 'Show Day $a to Day $b · ${BuddyFormat.rupees(sum)}';
  static String showOneDay(int a, int sum) => 'Show Day $a · ${BuddyFormat.rupees(sum)}';
  static const String limitLine = 'This trip has 500 expenses. Delete one to add more.';
  static const String frozenToast = 'This trip is closed for changes.';
  static const String tripGone = 'This trip is gone.';
  static const String tripGoneLine = 'It was deleted or you are no longer on it.';
  static const String tryAgainLater = 'Please try again in a few minutes';

  static const String addTitle = 'Add expense';
  static const String editTitle = 'Edit expense';
  static const String fromBookedTaxi = 'From your booked taxi';
  static const String fromBookedStay = 'From your booked stay';
  static String dayDate(int day, DateTime? date) => date == null ? 'Day $day' : 'Day $day · ${BuddyFormat.dayMonth(date)}';
  static const String amount = 'Amount';
  static const String wholeRupees = 'Whole rupees';
  static String amountBox(int? amount) => '${Money.symbol} ${Money.group(amount ?? 0)}';
  static const String whatFor = 'What was it for?';
  static const String titleHint = 'For example, lunch at Mall Road';
  static const String category = 'Category';
  static const String linkedTo = 'Linked to';
  static const String bookedTaxi = 'Booked taxi';
  static const String bookedStay = 'Booked stay';
  static String bookedStayNamed(String name) => 'Booked stay · $name';
  static String dayChip(int day) => 'Day $day';
  static String dayChipToday(int day) => 'Day $day · today';
  static const String paidByLabel = 'Paid by';
  static String you(String name) => '$name (you)';
  static const String splitAmong = 'Split among';
  static const String splitAll = 'All travellers';
  static const String splitChosen = 'Choose people';
  static const String splitCustom = 'Custom';
  static const String notInThis = 'Not in this one';
  static String leftover(int r, String name) => '${BuddyFormat.rupees(r)} left over is added to $name\'s share';
  static String each(int each, int n) => '${BuddyFormat.rupees(each)} each, shared by $n';
  static String sharedBy(int n) => 'Shared by $n';
  static String leftToAssign(int n) => '${BuddyFormat.rupees(n)} left to assign';
  static String moreThanAmount(int n) => '${BuddyFormat.rupees(n)} more than the amount';
  static const String allAssigned = '✔ All assigned';
  static String leftTrip(int share) => 'Left the trip · ${BuddyFormat.rupees(share)}';
  static const String leftCannotAdd = 'Left the trip. Cannot be added back.';
  static const String note = 'Note (optional)';
  static const String saveExpense = 'Save expense';
  static const String saveChanges = 'Save changes';
  static const String close = 'Close';
  static const String backspace = 'Delete digit';
  static const String choosePayer = 'Who paid?';

  static const String errAmount = 'Enter the amount';
  static const String errAmountMax = 'Up to ₹5,00,000 for one expense';
  static const String errTitle = 'Add a short title';
  static const String errCategory = 'Choose a category';
  static const String errSharers = 'Choose at least one person';
  static const String errDay = 'Choose a day';
  static String notOnTrip(String name) => '$name is no longer on this trip.';
  static const String linkNotInTrip = 'This booking is not part of this trip.';
  static const String conflict = 'Updated on another device, refresh';
  static const String refresh = 'Refresh';
  static const String youTyped = 'You typed';
  static String typedLine(int? amount, String title) => '${amount == null ? '₹0' : BuddyFormat.rupees(amount)} · $title';

  static const String discardTitle = 'Discard this expense?';
  static const String discardKeep = 'Keep editing';
  static const String discard = 'Discard';

  static const String added = 'Expense added';
  static const String saved = 'Changes saved';
  static const String deleted = 'Expense deleted';

  static const String paymentsTitle = 'Payments are already made';
  static String paymentsBody(List<String> names) {
    final told = names.isEmpty
        ? 'Travellers are told.'
        : names.length == 1
            ? '${names.first} is told.'
            : '${joinNames(names)} are told.';
    return 'This edit changes who owes whom. Balances are worked out again and payments reopen. $told';
  }

  static const String save = 'Save';
  static const String cancel = 'Cancel';

  static String lateTitle(String name) => '$name joined';
  static String lateBody(String name) => 'Share earlier expenses with $name?';
  static String lateLine(int count, int total) => '${BuddyFormat.plural(count, 'expense', 'expenses')}, ${BuddyFormat.rupees(total)} so far';
  static const String keepThem = 'Keep them as they are';
  static const String chooseExpenses = 'Choose expenses';

  static String shareWithTitle(String name) => 'Share with $name';
  static String shareWithSub(String name) => 'Pick what $name should share';
  static String candidateLine(int day, int amount, String payer) => 'Day $day · ${BuddyFormat.rupees(amount)} · Paid by $payer';
  static String newShares(String title) => '$title, new shares';
  static String willGetNotice(List<String> names) => '${joinNames(names)} will get a notice';
  static String shareCount(int n) => n == 1 ? 'Share 1 expense' : 'Share $n expenses';
  static String sharedWithSnack(String name) => 'Shared with $name';

  static const String expense = 'Expense';
  static const String edit = 'Edit';
  static const String delete = 'Delete';
  static String editedTimes(int n) => n == 1 ? 'Edited 1 time' : 'Edited $n times';
  static String linkDay(String link, int day) => '$link · Day $day';
  static String noteLine(String note) => 'Note: $note';
  static const String history = 'Edit history';
  static const String historyLine = 'All travellers can read it';
  static const String deletedLine = 'This expense was deleted.';
  static const String gone = 'This expense is gone.';
  static const String back = 'Back';

  static const String deleteTitle = 'Delete this expense?';
  static String deleteBody(int amount, String shortTitle) =>
      '${BuddyFormat.rupees(amount)} · $shortTitle. Shares go down for everyone. History keeps a line.';
  static const String deletePayments = 'Payments are already made. Balances are worked out again and payments reopen.';

  static String hAdded(String actor) => '$actor added this expense';
  static String hAddedDetail(int amount, int n) => '${BuddyFormat.rupees(amount)} · shared by $n';
  static String hAmount(String actor) => '$actor changed the amount';
  static String hTitle(String actor) => '$actor changed the title';
  static String hCategory(String actor) => '$actor changed the category';
  static String hDay(String actor, Object? day) => '$actor moved it to Day $day';
  static String hLink(String actor) => '$actor changed the booking link';
  static String hPaidBy(String actor) => '$actor changed who paid';
  static String hShares(String actor) => '$actor changed the split';
  static String hSharesDetail(int n) => 'shared by $n';
  static String hNote(String actor) => '$actor changed the note';
  static String hSharedWith(String actor, String name) => '$actor shared it with $name';
  static String hDeleted(String actor) => '$actor deleted this expense';
  static String arrow(String a, String b) => '$a → $b';

  static String joinNames(List<String> names) {
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }
}
