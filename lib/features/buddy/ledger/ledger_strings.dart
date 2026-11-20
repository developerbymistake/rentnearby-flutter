import '../shared/buddy_format.dart';

abstract final class LedgerStrings {
  static const String settleUpTitle = 'Settle up';
  static const String summaryTitle = 'Trip summary';
  static const String expensesTitle = 'Expenses';
  static const String closedForChanges = 'This trip is closed for changes.';

  static const String whoPaysWhom = 'WHO PAYS WHOM';
  static const String notPaidYet = 'Not paid yet';
  static const String saysPaid = 'Says paid';
  static const String open = 'Open';
  static const String received = '✔ Received';
  static const String receivedWord = 'Received';
  static const String notReceived = 'Not received';
  static const String markAsReceived = 'Mark as received';
  static const String sendReminder = 'Send a reminder';
  static const String reminderSent = 'Reminder sent';
  static const String iHavePaid = 'I have paid';
  static const String notPaid = 'Not paid';
  static const String allSquare = 'All square';
  static const String allSettled = 'All settled';
  static const String nothingToSettle = 'Nothing to settle yet';
  static const String nothingToSettleLine = 'Add an expense and the balances show here.';
  static const String paymentChanged = 'This payment changed. Check it again.';
  static const String tripGone = 'This trip is no longer available';
  static const String tripGoneLine = 'It was deleted or you are no longer on it.';

  static String paidShare(int paid, int share) => 'Paid ${BuddyFormat.rupees(paid)} · Share ${BuddyFormat.rupees(share)}';
  static String getsBack(int amount) => 'Gets back ${BuddyFormat.rupees(amount)}';
  static String owes(int amount) => 'Owes ${BuddyFormat.rupees(amount)}';
  static const String pays = 'pays';
  static String paysYou(String payer, int amount) => '$payer pays you ${BuddyFormat.rupees(amount)}';
  static String paidOn(DateTime d) => 'Paid ${BuddyFormat.dayMonth(d.toLocal())}';
  static String changedOn(String title, DateTime d) => '$title changed, ${BuddyFormat.dayMonth(d.toLocal())}';
  static String markedByYou(DateTime d) => 'Marked by you, ${BuddyFormat.dayMonth(d.toLocal())}';
  static String markedBy(String name, DateTime d) => 'Marked by $name, ${BuddyFormat.dayMonth(d.toLocal())}';
  static String saysPaidWait(String payer, String owner) => '$payer says paid. $owner will mark it as received.';

  static const String notYet = 'Not yet';
  static const String yesReceived = 'Yes, received';
  static const String yesIPaid = 'Yes, I paid';
  static const String keepIt = 'Keep it';
  static const String cancel = 'Cancel';
  static String receivedTitle(int amount) => 'Mark ${BuddyFormat.rupees(amount)} as received?';
  static String receivedBody(String payer) => 'Tap Yes only when the money is in your account. $payer is told. This cannot be switched back.';
  static String receivedByTitle(int amount, String receiver) => 'Mark ${BuddyFormat.rupees(amount)} as received by $receiver?';
  static String receivedByBody(String receiver, String payer) =>
      'Tap Yes only when $receiver has the money. $payer is told. This cannot be switched back.';
  static const String notReceivedTitle = 'Not received yet?';
  static String notReceivedBody(String payerFull, int amount, String payer) =>
      '$payerFull said he paid ${BuddyFormat.rupees(amount)}. The payment opens again and $payer is asked to check.';
  static String paidTitle(int amount) => 'Have you paid ${BuddyFormat.rupees(amount)}?';
  static String paidBody(String receiver, String owner) =>
      'Tap Yes only after you have sent the money to $receiver. $owner is told and confirms. You can take it back until $owner confirms.';
  static String paidBodyOwner(String receiver) =>
      'Tap Yes only after you have sent the money to $receiver. You can take it back until it is marked as received.';
  static const String notPaidTitle = 'Mark as not paid?';
  static String notPaidBody(String owner) => 'Use this if the money did not go. $owner is told and the payment opens again.';

  static String receivedSnack(String payer) => 'Marked as received from $payer';
  static String reminderSnack(String name) => 'Reminder sent to $name';
  static String alreadyReceived(String owner) => '$owner already marked it as received.';

  static String youOwe(String receiver) => 'You owe $receiver';
  static const String youOweTotal = 'You owe';
  static String paidTo(String receiver) => 'Paid to $receiver';
  static const String nothingToPay = 'Nothing to pay';
  static const String owedToYou = 'Owed to you';
  static const String yourShare = 'Your share';
  static const String youPaid = 'You paid';
  static String amountChanged(int amount) => 'The amount changed to ${BuddyFormat.rupees(amount)}. Check and confirm again.';
  static const String nothingLeft = 'Nothing left to pay. You are all square.';
  static String waitingConfirm(String owner) => 'You said paid. Waiting for $owner to confirm.';
  static String notGotIt(String owner) => '$owner has not got it yet. Check and try again.';
  static String gotIt(String receiver) => '$receiver got it. You are all square.';

  static String endedLine(String title, DateTime? end) => end == null ? title : '$title · ended ${BuddyFormat.dayMonth(end)}';
  static String toSettle(int n) => n == 1 ? 'Trip finished. 1 payment to settle.' : 'Trip finished. $n payments to settle.';
  static String openAgain(int n) => n == 1 ? 'Expenses changed. 1 payment open again.' : 'Expenses changed. $n payments open again.';
  static const String youGetBack = 'You get back';
  static const String youOweHero = 'You owe';
  static const String receivedCell = 'Received';
  static const String stillOpen = 'Still open';
  static String paymentsDone(int done, int total) => 'PAYMENTS · $done OF $total DONE';

  static String summaryLine(String range, int days, int travellers) =>
      '$range · ${BuddyFormat.plural(days, 'day', 'days')} · ${BuddyFormat.plural(travellers, 'traveller', 'travellers')}';
  static const String noPaymentsLeft = 'No payments left';
  static String paymentsOpen(int n) => n == 1 ? '1 payment open' : '$n payments open';
  static const String totalSpent = 'Total spent';
  static const String byCategory = 'By category';
  static const String planNext = 'Plan the next trip with the same travellers';

  static String spent(int amount) => 'Spent ${BuddyFormat.rupees(amount)} →';
  static const String inExpenses = 'In expenses';
  static const String menuLabel = 'More options';
}
