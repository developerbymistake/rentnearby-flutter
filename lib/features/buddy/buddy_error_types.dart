abstract final class BuddyErrorTypes {
  static const String selfRequest = 'SelfRequest';
  static const String personNotFound = 'PersonNotFound';
  static const String alreadyBuddies = 'AlreadyBuddies';
  static const String tryLater = 'TryLater';
  static const String waitingLimit = 'WaitingLimit';
  static const String buddyLimit = 'BuddyLimit';
  static const String cannotAddNow = 'CannotAddNow';
  static const String buddyRequestsOnHold = 'BuddyRequestsOnHold';
  static const String requestEnded = 'RequestEnded';
  static const String cannotBlockSelf = 'CannotBlockSelf';
  static const String cannotReportSelf = 'CannotReportSelf';
  static const String tooManyBlocks = 'TooManyBlocks';
  static const String invalidReason = 'InvalidReason';
  static const String tripNotFound = 'TripNotFound';
  static const String tripFull = 'TripFull';
  static const String tripCompleted = 'TripCompleted';
  static const String noPlaces = 'NoPlaces';
  static const String inviteEnded = 'InviteEnded';
  static const String notOnTrip = 'NotOnTrip';
  static const String tripHasOpenBalances = 'TripHasOpenBalances';
  static const String notTripOwner = 'NotTripOwner';
  static const String expenseNotFound = 'ExpenseNotFound';
  static const String invalidAmount = 'InvalidAmount';
  static const String titleRequired = 'TitleRequired';
  static const String invalidCategory = 'InvalidCategory';
  static const String invalidDay = 'InvalidDay';
  static const String noSharers = 'NoSharers';
  static const String noteTooLong = 'NoteTooLong';
  static const String expenseVersionConflict = 'ExpenseVersionConflict';
  static const String expenseIdTaken = 'ExpenseIdTaken';
  static const String expenseLimitReached = 'ExpenseLimitReached';
  static const String tripExpensesFrozen = 'TripExpensesFrozen';
  static const String paymentsNotAcknowledged = 'PaymentsNotAcknowledged';
  static const String sharesDoNotAddUp = 'SharesDoNotAddUp';
  static const String sharerNotTraveller = 'SharerNotTraveller';
  static const String payerNotTraveller = 'PayerNotTraveller';
  static const String linkNotInTrip = 'LinkNotInTrip';
  static const String tooManySharers = 'TooManySharers';
  static const String notEqualSplit = 'NotEqualSplit';
  static const String alreadySharing = 'AlreadySharing';
  static const String notTraveller = 'NotTraveller';
  static const String balancesChanged = 'BalancesChanged';
  static const String nothingToPay = 'NothingToPay';
  static const String paymentNotFound = 'PaymentNotFound';
  static const String paymentStateChanged = 'PaymentStateChanged';
  static const String notYourDebt = 'NotYourDebt';
  static const String reminderAlreadySent = 'ReminderAlreadySent';
  static const String sharedTripOpenBalance = 'SharedTripOpenBalance';
  static const String tooManyRequests = 'TooManyRequests';
  static const String badRequest = 'BadRequest';
  static const String tripPlannerDisabled = 'TripPlannerDisabled';
  static const String accountHasActiveItems = 'AccountHasActiveItems';
  static const String tripLimitReached = 'TripLimitReached';

  static const List<String> all = [
    selfRequest, personNotFound, alreadyBuddies, tryLater, waitingLimit, buddyLimit, cannotAddNow, buddyRequestsOnHold,
    requestEnded, cannotBlockSelf, cannotReportSelf, tooManyBlocks, invalidReason, tripNotFound, tripFull, tripCompleted,
    noPlaces, inviteEnded, notOnTrip, tripHasOpenBalances, notTripOwner, expenseNotFound, invalidAmount, titleRequired,
    invalidCategory, invalidDay, noSharers, noteTooLong, expenseVersionConflict, expenseIdTaken, expenseLimitReached,
    tripExpensesFrozen, paymentsNotAcknowledged, sharesDoNotAddUp, sharerNotTraveller, payerNotTraveller, linkNotInTrip,
    tooManySharers, notEqualSplit, alreadySharing, notTraveller, balancesChanged, nothingToPay, paymentNotFound,
    paymentStateChanged, notYourDebt, reminderAlreadySent, sharedTripOpenBalance, tooManyRequests, badRequest,
    tripPlannerDisabled, accountHasActiveItems, tripLimitReached,
  ];
}
