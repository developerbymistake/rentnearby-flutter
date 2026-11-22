import '../../owner_core/strings/owner_shared_strings.dart';

abstract final class TaxiHubStrings {
  static const title = 'My Taxi';
  static const noTaxiYet = 'No taxi yet';
  static const noTaxiBody = 'Set up your taxi to get requests from travellers.';
  static const setUpTaxi = 'Set up your taxi';
  static const couldNotLoad = 'Couldn’t load your taxi';
  static const checkConnection = 'Check your connection and try again.';
  static const tryAgain = OwnerSharedStrings.tryAgain;
  static const noConnection = OwnerSharedStrings.noConnection;
  static const tooManyTries = OwnerSharedStrings.tooManyTries;
  static const somethingWrong = 'Something went wrong. Please try again.';
  static const underReview = 'Your taxi is under review';
  static const showingLast = OwnerSharedStrings.showingLast;
  static const taxiFallback = 'Taxi';

  static const live = 'LIVE';
  static const featured = 'Featured';
  static const statusReview = 'UNDER REVIEW';
  static const statusRejected = 'REJECTED';
  static const statusDraft = 'DRAFT';
  static const statusOffline = 'OFFLINE';
  static const from = 'FROM';
  static const view = 'View';
  static const share = 'Share';
  static const shareNotLive = 'Your taxi is not live yet.';
  static String vehicleLine(String name, int? seats) => seats == null ? name : '$name · $seats seats';
  static String routeChip(int n) => n == 1 ? '1 route' : '$n routes';
  static String localChip(String amount) => '$amount local day';

  static String routesHeader(int used, int limit) => 'ROUTES AND FARES · $used OF $limit';
  static String routesHeaderOff(int used) => 'ROUTES AND FARES · $used';
  static String routeTitleOf(String from, String to) => '$from to $to';
  static String routeSub(bool roundTrip, String fare) => '${roundTrip ? 'Round trip' : 'One way'} · $fare';
  static const editFare = 'Edit fare';
  static const edit = 'Edit';
  static const hiddenOnFree = 'Hidden on Free';
  static const hiddenRoute = 'Hidden';
  static const addRoute = 'Add route';
  static const add = 'Add';
  static String allUsed(int n) => 'All $n used';
  static const full = 'Full';
  static String usedOf(int used, int limit) => '$used of $limit used';
  static const seePlus = OwnerSharedStrings.seePlus;
  static const menuEditRoute = 'Edit route';
  static const menuDeleteRoute = 'Delete route';
  static const moreOptions = 'More options';
  static const lastRoute = 'Add at least one route.';

  static const localHeader = 'LOCAL SIGHTSEEING';
  static String dayRateLine(String amount) => '$amount a day';
  static String kmLine(int km) => '$km km included';
  static const localNotSet = 'Not set';
  static const localNotSetSub = 'Not in trip planning yet';

  static const vehicleHeader = 'VEHICLE AND CONTACT';
  static const vehicleHint = 'Licence, date of birth or photo changes go for review';
  static String reports(int n) => n == 1 ? '1 report on this taxi' : '$n reports on this taxi';

  static const deleteTaxi = 'Delete taxi';
  static const deleteTitle = 'Delete taxi?';
  static const deleteBody = 'Your taxi, routes, plate photo, calendar and money notes will be deleted.';
  static String deleteBookings(int n) => n == 1 ? ' 1 booking will be cancelled and the traveller told.' : ' $n bookings will be cancelled and the travellers told.';
  static const delete = 'Delete';
  static const keep = 'Keep';
  static const taxiDeleted = 'Taxi deleted.';

  static const editFareTitle = 'Edit fare';
  static String editFareSub(String route, bool roundTrip) => '$route · ${roundTrip ? 'Round trip' : 'One way'}';
  static const fareHint = '₹100 to ₹99,00,000';
  static const rupee = '₹ ';
  static const save = 'Save';
  static const fareEmpty = 'Enter the fare';
  static const fareRange = 'Fare must be between ₹100 and ₹99,00,000';
  static const fareUpdated = 'Fare updated';

  static const editRouteTitle = 'Edit route';
  static String routeNumber(int n) => 'Route $n';
  static const fromLabel = 'From';
  static const toLabel = 'To';
  static const fareLabel = 'Fare';
  static const oneWay = 'One way';
  static const roundTrip = 'Round trip';
  static const closeOldRoute = 'Open requests on the old route will close.';
  static const saveRoute = 'Save route';
  static const routeSaved = 'Route saved';
  static const sameCity = 'From and To must be different.';
  static const duplicateRoute = 'You already have this route.';
  static const deleteRouteTitle = 'Delete this route?';
  static const deleteRouteBody = 'Open requests on this route will close.';
  static const deleteRouteConfirm = 'Delete route';
  static const routeDeleted = 'Route deleted';

  static const localTitle = 'Local sightseeing';
  static const localSub = 'Your day rate inside your own city';
  static const dayRate = 'Day rate';
  static const kmIncluded = 'Km included';
  static const localNote = 'Shown in trip plans as a local day. Leave empty to stay out of local days.';
  static const localSaved = 'Local rate saved';
  static const localNeedBoth = 'Add both the day rate and the km.';
  static const kmRange = 'Km must be between 1 and 1000';

  static const profileTitle = 'Profile';
  static const planATrip = 'Plan a trip';
  static const travelAsGuest = 'Travel as a guest';
  static const myRating = 'My rating';
  static const noRatingsYet = 'No ratings yet';
  static String ratingSub(double avg, int n) => '${avg.toStringAsFixed(1)} from $n ratings';
  static const deletionLine = 'Your taxi, calendar and money notes will be deleted.';
  static const roleBlocked = 'A taxi that was approved or is under review blocks this role change.';

  static const reviewTitle = 'Send for review?';
  static const reviewBody = 'You stop getting requests until Bakhli approves the change. Your bookings stay.';
  static const reviewSend = 'Send for review';
  static const reviewCancel = 'Cancel';
}
