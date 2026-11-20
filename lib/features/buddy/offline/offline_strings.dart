import '../buddy_limits.dart';

abstract final class OfflineStrings {
  static const String waitingToSync = 'Waiting to sync';
  static const String notSaved = 'Not saved';
  static const String syncNow = 'Sync now';
  static const String offline = 'You are offline.';

  static String offlineWaiting(int n) =>
      n == 1 ? 'You are offline. 1 expense will sync when you are back online.' : 'You are offline. $n expenses will sync when you are back online.';

  static String notSavedBanner(int n) => n == 1 ? '1 expense could not be saved.' : '$n expenses could not be saved.';

  static String frozenBanner(int n) =>
      n == 1 ? '1 change could not be saved. This trip is closed for changes.' : '$n changes could not be saved. This trip is closed for changes.';

  static String goneBanner(int n) =>
      n == 1 ? '1 change could not be saved. The trip is no longer yours.' : '$n changes could not be saved. The trip is no longer yours.';

  static const String lineConflict = 'Updated on another device';
  static String lineNotTraveller(String name) => '$name is no longer on this trip. Edit and save again.';
  static String get lineLimit => 'This trip has ${BuddyLimits.maxExpenses} expenses. Delete one to add more.';
  static const String lineFrozen = 'This trip is closed for changes.';
  static const String linePayments = 'Payments are already made. Edit and save again.';
  static const String linePaymentsDelete = 'Payments are already made.';
  static const String lineDeleted = 'This expense was deleted.';
  static const String lineOther = 'This change could not be saved.';
  static const String someone = 'Someone';

  static const String refresh = 'Refresh';
  static const String edit = 'Edit';
  static const String remove = 'Remove';

  static String notSavedTitle(int n) => n == 1 ? '1 expense is not saved yet' : '$n expenses are not saved yet';
  static const String notSavedBody = 'They are only on this phone. Sync them before you log out.';
  static const String logOutAnyway = 'Log out anyway';
  static const String couldNotSync = 'Could not sync. Check your network.';
  static const String expensesSaved = 'Expenses saved';

  static const String logOutAnywayTitle = 'Log out anyway?';
  static String willBeLost(int n) => n == 1 ? '1 expense will be lost. It never reached the trip.' : '$n expenses will be lost. They never reached the trip.';
  static const String syncFirst = 'Sync them first if you can.';
  static const String cancel = 'Cancel';
  static const String logOut = 'Log out';

  static const String logInAgain = 'Please log in again';
  static String savedOnPhone(int n) =>
      n == 1 ? '1 expense is saved on this phone. It syncs after you log in.' : '$n expenses are saved on this phone. They sync after you log in.';
  static const String logIn = 'Log in';
}
