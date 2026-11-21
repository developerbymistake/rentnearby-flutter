abstract final class StayWorkStrings {
  static const enquiries = 'Enquiries';
  static const bucketNew = 'New';
  static const bucketOffered = 'Offered';
  static const bucketConfirmed = 'Confirmed';
  static const bucketClosed = 'Closed';
  static String withCount(String label, int n) => n > 0 ? '$label ($n)' : label;

  static String guests(int n) => n == 1 ? '1 guest' : '$n guests';
  static String rooms(int n) => n == 1 ? '1 room' : '$n rooms';
  static String nights(int n) => n == 1 ? '1 night' : '$n nights';
  static String roomsNights(int rooms, int nights) => '${StayWorkStrings.rooms(rooms)} x ${StayWorkStrings.nights(nights)}';
  static String roomNights(String room, int nights) => '$room x ${StayWorkStrings.nights(nights)}';
  static const listedWhenAsked = 'Listed when asked';
  static String listedWhenAskedAmount(String amount) => '$listedWhenAsked $amount';
  static const urgentPrefix = 'Urgent: ';
  static String hours(int h) => '$h h';
  static String minutes(int m) => '$m min';

  static const chipNew = 'New';
  static const chipNewPrice = 'New price';
  static const chipOffered = 'Offered';
  static const chipConfirmed = 'Confirmed';
  static const chipChangeRequest = 'Change request';

  static const offerWithin = 'Offer within';
  static const answerWithin = 'Answer within';
  static const validUntil = 'Valid until';
  static const offersSent = 'Offers sent';
  static String nOfThree(int n) => '$n of 3';
  static const counter = 'Counter';

  static const sendOffer = 'Send offer';
  static const sendNewOffer = 'Send new offer';
  static const callGuest = 'Call guest';
  static const notAvailable = 'Not available';
  static const acceptPrice = 'Accept price';
  static const sendDifferentOffer = 'Send a different offer';
  static const acceptChange = 'Accept change';
  static const cancelBooking = 'Cancel booking';
  static const shareUpiWhatsApp = 'Share UPI and WhatsApp';
  static const openChat = 'Open chat';
  static const calendarEntry = 'Calendar entry';
  static const open = 'Open';
  static const keep = 'Keep';

  static const room = 'Room';
  static const trip = 'Trip';
  static String tripInDays(int n) => n == 1 ? 'trip in 1 day' : 'trip in $n days';
  static const yourOffer = 'Your offer';
  static String perNight(String amount) => '$amount / night';
  static String asks(String name) => '$name asks';
  static const totalAtHisPrice = 'Total at his price';
  static String acceptPriceLine(String amount) => 'Accept price sends him an offer at $amount a night.';
  static const total = 'Total';
  static String roomPerNight(String room, String amount) => '$room · $amount / night';

  static String offerAmount(String amount) => 'Offer $amount';
  static const confirmed = 'Confirmed';
  static String byBoth(String date) => 'By both, $date';
  static const inYourCalendar = 'In your calendar';
  static const moneyOutside = 'Money is settled between you and the guest, outside the app.';

  static String confirmedRoom(String room) => 'Confirmed · $room';
  static const dates = 'Dates';
  static const guestsLabel = 'Guests';
  static const agreedPrice = 'Agreed price';
  static const changeInfo = 'Your calendar moves only when you accept. Money notes stay as they are.';
  static const blockedAcceptAnyway = 'These days are blocked by you. Accept anyway?';
  static const acceptAnyway = 'Accept anyway';
  static const datesTaken = 'These dates are no longer free.';

  static const reason = 'Reason';
  static const required = 'Required';
  static const reasonMax = 300;
  static String reasonCount(int n) => '$n / $reasonMax';
  static String cancelInfo(String name) => '$name is told at once. Your calendar entry stays, marked Cancelled, with your money notes.';
  static String cancelledByYouOn(String date) => 'Cancelled by you on $date';
  static String nameDates(String name, String dates) => '$name · $dates';

  static const sendRevisedOffer = 'Send a revised offer';
  static const reportTraveller = 'Report traveller';
  static const block = 'Block';
  static const blockTitle = 'Block this user?';
  static String blockBody(String name) => '$name will no longer be able to message you in any conversation.';
  static const shareFailed = 'Could not send that. Please try again.';
  static const blockFailed = 'Could not block this user. Please try again.';
  static String revisedNote(String amount) => 'Revised offer $amount / night · Not accepted yet';
  static String revisedLine(String name) => 'The agreed price stays until $name accepts.';

  static const closedExpired = 'Expired';
  static const closedOfferDeclined = 'Offer declined';
  static const closedOfferExpired = 'Offer expired';
  static const closedTravellerLeft = 'Traveller left';
  static const closedBookedElsewhere = 'Booked elsewhere';
  static const closedBookedByPhone = 'Booked by phone';
  static const closedCancelledByGuest = 'Cancelled by guest';
  static const closedCancelledByYou = 'Cancelled by you';
  static const closedByBakhli = 'Closed by Bakhli';
  static const closedNotAvailable = 'Not available';
  static const detailNoReply = 'no reply in time';
  static const detailTripCancelled = 'trip cancelled';
  static const detailByPhone = 'by phone';
  static const problemStrip = 'The guest reported a problem. Bakhli will contact you.';

  static const noEnquiries = 'No enquiries yet';
  static const noEnquiriesSub = 'Trip enquiries for your stay show here.';
  static const plannerOff = 'Not available right now';
  static const plannerOffSub = 'New enquiries will come back soon. You can still answer the open ones.';
  static String moreActionsFor(String name) => 'More actions for $name';
  static String offerWithinHours(int h) => h == 1 ? 'Offer within 1 hour' : 'Offer within $h hours';

  static const listedForDates = 'Listed for these dates';
  static String breakdownPart(int nights, String perNight, String? label) =>
      '${StayWorkStrings.nights(nights)} x $perNight${label == null || label.isEmpty ? '' : ' ($label)'}';
  static const offerTotal = 'Offer total';
  static const wholeStay = 'Whole stay';
  static String aboveListed(String amount) => 'Above your listed price for these dates ($amount).';
  static const offerInfo = 'The guest sees only your offer total. The listed price is your own reference. Payment is settled outside the app.';

  static const shareLine1 = 'You share these from a guest’s chat, one tap. Nobody sees them before that.';
  static const shareLine2 = 'The app does not take, hold or track payments. Settle money with the guest directly.';
  static const shareHeaderSub = 'Your contact details';
  static const shareCardTitle = 'Contact details';
  static const upiInvalid = 'Enter a valid UPI ID, like name@bank.';
  static const whatsAppInvalid = 'Enter a 10-digit WhatsApp number.';
  static const removeMyDetails = 'Remove my details';
  static const save = 'Save';

  static const myJobs = 'My Jobs';
  static String activeOf(int active, int max) => '$active of $max active';
  static String jobsPlusCap(int max) => 'You can have up to $max active jobs. Close one to post another.';
  static const stayNotLive = 'Stay must be live first';
  static const jobActive = 'ACTIVE';
  static const jobClosed = 'CLOSED';
  static const salary = 'SALARY';
  static const perMonth = '/ month';
  static const view = 'View';
  static const edit = 'Edit';
  static const close = 'Close';
  static const applicantsLine = 'Applicants call or WhatsApp you.';
  static const postAJob = 'Post a Job';
  static const postAJobTitle = 'Post a job';
  static const foodAndStay = 'Food and stay given';
  static const closeJobTitle = 'Close this job?';
  static const closeJobBody = 'A closed job cannot be opened again. It frees a slot for a new post.';
  static const closeJob = 'Close job';
  static const jobSaved = 'Saved';
  static const noJobs = 'No jobs yet';
  static const noJobsSub = 'Post your first job';
  static const couldNotLoadJobs = "Couldn't load jobs";
  static const jobSteps = ['Role', 'Pay', 'Contact'];
  static const _stepNames = ['Role', 'Pay and experience', 'Contact'];
  static String jobStepLine(int i) => 'Step ${i + 1} of 3 · ${_stepNames[i.clamp(0, 2)]}';
  static const next = 'Next';
  static const jobPayHint = 'Salary ₹100 to ₹99,00,000. Experience 0 to 20 years.';
  static String experience(int years) => years <= 0 ? 'Fresher' : '$years+ years';
}
