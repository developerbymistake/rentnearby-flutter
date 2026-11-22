abstract final class StayHomeStrings {
  static String hi(String name) => 'Hi, $name';
  static const hiFallback = 'there';

  static const subLive = 'Your stay is live';
  static const subReview = 'Your stay is under review';
  static const subNotLive = 'Your stay is not live';
  static const subPaused = 'Not taking guests';
  static const subAreaPaused = 'New enquiries are paused';

  static const pillLive = 'LIVE';
  static const pillPaused = 'PAUSED';
  static const pillReview = 'UNDER REVIEW';
  static const pillRejected = 'REJECTED';
  static const pillTakenDown = 'TAKEN DOWN';
  static const featured = '★ Featured';
  static String livePill(bool featured) => featured ? '$pillLive · ${StayHomeStrings.featured}' : pillLive;

  static const lineLive = 'Guests can find and ask you now.';
  static const linePaused = 'Guests cannot send new enquiries.';
  static const lineReview = 'We will notify you';
  static const lineAreaPaused = 'Your stay stays saved as it is.';
  static const areaPausedBanner = 'New enquiries are paused in your area.';
  static const plansStartedToday = 'Plans started today.';
  static String needReply(int n) => n == 1 ? '1 enquiry needs a reply.' : '$n enquiries need a reply.';
  static String checkIns(int n) => n == 1 ? '1 check-in this week.' : '$n check-ins this week.';
  static String firstInTripPlans(String city) => 'First in trip plans for $city.';
  static String rejectedLine(String? reason) => reason == null ? 'Rejected' : 'Rejected: $reason';
  static String takenDownLine(String? reason) => reason == null ? 'Taken down by Bakhli' : 'Taken down by Bakhli: $reason';
  static const fixAndResubmit = 'Fix and resubmit';
  static const takenDownStrip = 'Your confirmed bookings still stand. Guests can still reach you in chat.';

  static const acceptingGuests = 'Accepting guests';
  static const toastPaused = 'Paused';
  static const toastAccepting = 'Accepting guests';
  static const notLiveYet = 'Your stay is not live yet.';

  static const whileYouWait = 'While you wait';
  static const needsAttention = 'Needs attention';
  static String seeAll(int n) => 'See all ($n)';
  static const attentionTitle = 'Needs attention';

  static String enquiriesWaiting(int n) => n == 1 ? '1 enquiry waiting' : '$n enquiries waiting';
  static String replyBefore(String time) => 'Reply before $time';
  static const reply = 'Reply';
  static String askedChange(String name) => '$name asked to change his booking.';
  static String sentNewPrice(String name) => '$name sent a new price.';
  static String acceptedOffer(String name) => '$name accepted your offer';
  static String bookingConfirmedFor(String range) => 'Booking confirmed for $range';
  static const open = 'Open';
  static const paymentIssue = 'Payment issue';
  static const fix = 'Fix';
  static const notificationsTitle = 'Turn on notifications';
  static const notificationsMiss = 'You will miss new enquiries';
  static const notificationsMissUntil = 'You will miss new enquiries until notifications are on.';
  static const notificationsReview = 'We tell you when the review is done.';
  static const turnOn = 'Turn on';
  static const nothingDeleted = 'Nothing is deleted.';
  static const choose = 'Choose';
  static String plusEnded(String what, {bool single = false}) => 'Plus ended. $what ${single ? 'is' : 'are'} hidden.';
  static String plansStarted(String what, {bool single = false}) => 'Plans have started. $what ${single ? 'is' : 'are'} hidden.';
  static String photos(int n) => n == 1 ? '1 photo' : '$n photos';
  static String roomTypes(int n) => n == 1 ? '1 room type' : '$n room types';
  static String and(String a, String b) => '$a and $b';
  static String reports(int n) => n == 1 ? '1 report on this stay' : '$n reports on this stay';
  static const view = 'View';
  static String changeNotApproved(String reason) => 'Change not approved: $reason';
  static String nameChangeNotApproved(String reason) => 'Your name change was not approved: $reason';
  static String festivalStarts(String name, String date) => '$name starts $date';
  static const festivalSub = 'Set your price for those days.';
  static const setPrice = 'Set price';
  static const addShare = 'Add UPI and WhatsApp';
  static const addShareSub = 'Optional. Shared only when you choose';
  static const add = 'Add';
  static const shareStay = 'Share your stay';
  static const shareStaySub = 'Send your link to past guests to get first enquiries.';
  static const share = 'Share';
  static const needHelp = 'Need help? Contact Support';
  static const needHelpSub = 'We reply within a day';

  static const newEnquiries = 'New enquiries';
  static const offersWaiting = 'Offers waiting';
  static const confirmed = 'Confirmed';
  static const dash = '–';
  static const chevron = '›';
  static String number(int? n) => n == null ? dash : '$n';

  static const quickActions = 'Quick actions';
  static const editPrices = 'Edit prices';
  static const editPricesSub = 'Rooms and rates';
  static const shareMyStay = 'Share my stay';
  static const shareMyStaySub = 'Send your stay link';
  static const postJob = 'Post a job';
  static const postJobSub = 'Hire for your stay';
  static const contactDetails = 'Contact details';
  static const contactDetailsSub = 'UPI and WhatsApp, to share';

  static const instagram = 'Instagram';
  static const followUs = 'Follow us';
  static const follow = 'Follow';

  static const couldNotLoad = 'Couldn’t load';
  static const checkConnection = 'Check your connection and try again.';
  static const tryAgain = 'Try again';
  static const showingLast = 'Could not refresh. Showing your last list.';
  static const noConnection = 'No connection. Please try again.';
  static const somethingWrong = 'Something went wrong. Try again.';

  static const attentionPageTitle = 'Needs attention';
  static const supportMail = 'supportbakhli@gmail.com';
  static const supportSubject = 'Bakhli Support Request';
  static const supportFailed = 'Could not open email app. Please email supportbakhli@gmail.com';
}
