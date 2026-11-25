import '../../owner_core/strings/owner_shared_strings.dart';

abstract final class TaxiHomeStrings {
  static String hi(String name) => 'Hi, $name';
  static const hiFallback = 'there';

  static const subOnline = 'You are online';
  static const subOffline = 'You are offline';
  static String subOnTrip(String date) => 'On trip until $date';
  static const subReview = 'Your taxi is under review';
  static const subChangesReview = 'Changes under review';
  static const subRejected = 'Your taxi needs a fix';
  static const subNotLive = 'Your taxi is not live';

  static const pillReview = 'UNDER REVIEW';
  static const pillRejected = 'REJECTED';
  static const pillTakenDown = 'TAKEN DOWN';
  static const lineLive = 'LIVE · ready for requests';
  static const lineFeatured = 'LIVE · Featured';
  static const lineOffline = 'Offline · not taking requests';
  static const lineReview = 'We will notify you when your taxi is live.';
  static const lineChangesReview = 'UNDER REVIEW · not getting requests';
  static String rejectedLine(String? reason) => reason == null ? 'Rejected' : 'Rejected: $reason';
  static String takenDownLine(String? reason) => reason == null ? 'Taken down by Bakhli' : 'Taken down by Bakhli: $reason';
  static const fixAndResubmit = 'Fix and resubmit';
  static const takenDownStrip = 'Your confirmed bookings still stand.';
  static const changesInfo = 'Bakhli is checking your new licence details. Your bookings stay.';
  static const reviewTip = 'Requests start after approval. Get your phone ready now.';

  static const availableNow = 'Available now';
  static const ringOnTitle = 'Requests will ring';
  static const ringOnBody = 'Notifications are on.';
  static const ringOffTitle = 'You are offline';
  static const ringOffBody = 'New requests will not ring.';
  static const ringMutedTitle = 'Notifications are off';
  static const ringMutedBody = 'Requests will not ring.';
  static String seats(int n) => n >= 12 ? '12+ seats' : '$n seats';
  static const toastAvailable = 'Available now';
  static const toastHidden = 'Hidden from search';
  static const notLiveYet = 'Your taxi is not live yet.';
  static const underReview = 'Your taxi is under review';
  static const couldNotUpdate = 'Could not update your taxi.';
  static const tooManyTries = OwnerSharedStrings.tooManyTries;

  static const whileYouWait = 'WHILE YOU WAIT';
  static const getReady = 'Get ready for requests';
  static const getReadySub = 'Four quick checks so your phone rings';
  static const check = 'Check';
  static const vehicleRoutes = 'Vehicle and routes';
  static const lockedWhileReview = 'Locked while under review';
  static const view = 'View';
  static const needHelp = 'NEED HELP?';
  static const contactSupport = 'Contact Support';
  static const supportSub = 'We reply within a day';
  static const supportMail = 'supportbakhli@gmail.com';
  static const supportSubject = 'Bakhli Support Request';
  static const supportFailed = 'Could not open email app. Please email supportbakhli@gmail.com';
  static const chevron = '›';

  static const needsAttention = 'NEEDS ATTENTION';
  static String seeAll(int n) => 'See all ($n)';
  static const attentionPageTitle = 'Needs attention';
  static String attentionPageSub(int n) => n == 1 ? '1 thing, most urgent first' : '$n things, most urgent first';

  static const newRequests = 'New requests';
  static const missedRequests = 'Missed';
  static const rating = 'Rating';
  static String routeCount(int n) => n == 1 ? 'Route' : 'Routes';
  static const localDay = 'Local day rate';
  static const none = '-';
  static const dash = '–';

  static const quickActions = 'Quick actions';
  static const editFares = 'Edit fares';
  static const editFaresSub = 'Routes and prices';
  static const shareMyTaxi = 'Share my taxi';
  static const readyCheck = 'Ready check';
  static const readyCheckSub = 'Make sure it rings';
  static const myRating = 'My rating';
  static const myRatingSub = 'Your driver record';

  static const areaPaused = 'New requests are paused in your area.';
  static const plannerPaused = 'Requests are paused right now. New requests will come back soon.';

  static const couldNotLoad = 'Couldn’t load your taxi';
  static const checkConnection = 'Check your connection and try again.';
  static const tryAgain = OwnerSharedStrings.tryAgain;
  static const showingLast = OwnerSharedStrings.showingLast;

  static const choseYou = 'A traveller chose you';
  static String leftToConfirm(String mmss) => '$mmss left to confirm';
  static const confirm = 'Confirm';
  static const phoneCannot = 'This phone cannot get requests.';
  static const phoneCannotList = 'This phone cannot get requests';
  static const phoneCannotSub = 'Open Get ready to fix it';
  static const checkNow = 'Check now';
  static const notifTitle = 'Turn on notifications';
  static const notifSub = 'Requests cannot ring on this phone';
  static const turnOn = 'Turn on';
  static String missed(int n) => n == 1 ? 'You missed 1 request. Run a test ring.' : 'You missed $n requests. Run a test ring.';
  static String missedList(int n) => n == 1 ? 'You missed 1 request' : 'You missed $n requests';
  static const missedSub = 'Run a test ring';
  static const runTestRing = 'Run test ring';
  static const runTest = 'Run test';
  static const paymentIssue = 'Payment issue';
  static const paymentIssueSub = 'Plus keeps working for now';
  static const fix = 'Fix';
  static String plusEnded(int n) => n == 1 ? 'Plus ended. 1 route is hidden.' : 'Plus ended. $n routes are hidden.';
  static String plansStarted(int n) => n == 1 ? 'Plans have started. 1 route is hidden.' : 'Plans have started. $n routes are hidden.';
  static const nothingDeleted = 'Nothing is deleted.';
  static const choose = 'Choose';
  static String reports(int n) => n == 1 ? '1 report on this taxi' : '$n reports on this taxi';
  static const reportsSub = 'A traveller reported the car';
  static const addLocalRate = 'Add your local day rate';
  static const addLocalRateSub = 'Not in trip planning yet';
  static const add = 'Add';
  static String festivalStarts(String name, String date) => '$name starts $date';
  static const festivalSub = 'Go online and check your fares';
  static const checkFares = 'Check fares';
  static const getMoreCalls = 'Get more calls';
  static String addRoutes(String? from, String? to) =>
      from != null && to != null ? 'Add popular routes like $from to $to' : 'Add popular routes';
}
