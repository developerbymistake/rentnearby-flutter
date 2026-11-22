abstract final class StayHubStrings {
  static const title = 'My Stay';
  static const noStayYet = 'No stay yet';
  static const noStayBody = 'Set up your stay to get enquiries from travellers.';
  static const setUpStay = 'Set up your stay';
  static const stayDeleted = 'Stay deleted.';

  static const view = 'View';
  static const share = 'Share';
  static const from = 'FROM';
  static const perNightUnit = '/ night';
  static const accepting = 'Accepting guests';
  static const live = 'LIVE';
  static const featuredChip = '★ Featured';
  static const paused = 'PAUSED';
  static const underReviewChip = 'UNDER REVIEW';
  static const rejectedChip = 'REJECTED';
  static const draftChip = 'DRAFT';
  static const stayFallback = 'Stay';

  static const roomsAndPrices = 'Rooms and prices';
  static String meter(int used, int limit) => '$used of $limit';
  static String roomSub(String price, int guests) => '$price / night · $guests ${guests == 1 ? 'guest' : 'guests'}';
  static const editPrice = 'Edit price';
  static const addRoomType = 'Add room type';
  static String plusCanList(int n) => 'Plus stays can list up to $n';
  static const seePlus = 'See Plus';
  static String usedOf(int used, int limit) => '$used of $limit used';
  static const add = 'Add';
  static const hiddenOnFree = 'Hidden on Free';

  static const specialPrices = 'Special prices';
  static const open = 'Open';
  static String specialPrice(String label, String range, String direction) => '$range · $direction';
  static String percentHigher(int p) => '$p% higher';
  static String percentLower(int p) => '$p% lower';
  static String specialCount(int n) => '$n special prices';
  static String specialNext(String label, String range) => 'Next: $label, $range';
  static const noSpecialPrices = 'No special prices yet';

  static const photos = 'Photos';
  static String photosOf(int used, int limit) => '$used of $limit photos';
  static const manage = 'Manage';
  static const addTile = 'Add';

  static const calendar = 'Calendar';
  static String bookingsThisMonth(int n) => n == 1 ? '1 booking this month' : '$n bookings this month';
  static const bookingsCalendar = 'Bookings calendar';
  static String nextBooking(String date, String label) => 'Next: $date, $label';
  static String nextBookingDateOnly(String date) => 'Next: $date';
  static String nextTravellerRemoved(String date) => 'Next: $date · Traveller removed';

  static const stayDetails = 'Stay details';
  static const basicDetails = 'Basic details';
  static const basicDetailsSub = 'Name, type, facilities, location';
  static const basicDetailsPending = 'Change waiting for review';
  static const rules = 'Rules';
  static const rulesSub = 'Check-in, house rules, cancellation';
  static const upiWhatsApp = 'UPI and WhatsApp';
  static const upiWhatsAppSub = 'Shared with a guest only when you choose';
  static const edit = 'Edit';
  static const deleteStay = 'Delete stay';

  static const underReview = 'Your stay is under review.';
  static String reports(int n) => n == 1 ? '1 report on this stay' : '$n reports on this stay';

  static String pendingStrip(String fieldWord, String oldName) =>
      fieldWord == 'Name' ? 'Name change sent for review. Travellers still see $oldName.' : '$fieldWord change sent for review. Travellers still see the old details.';
  static const pendingStripMany = 'Changes sent for review. Travellers still see the old details.';
  static String approvedStrip(String? newName) => newName == null ? 'Your change is live.' : 'Your change is live. Name updated to $newName.';
  static String rejectedStrip(String? reason) {
    if (reason == null) return 'Change not approved. Your stay stays live.';
    final r = reason.trim();
    return 'Change not approved: $r${r.endsWith('.') ? '' : '.'} Your stay stays live.';
  }

  static const editAgain = 'Edit again';

  static const deleteTitle = 'Delete stay?';
  static const deleteBody = 'Your stay, photos, calendar, money notes, special prices and jobs will be deleted.';
  static String deleteBookings(int n) => n == 1
      ? ' 1 confirmed booking will be cancelled and the guests told.'
      : ' $n confirmed bookings will be cancelled and the guests told.';
  static const delete = 'Delete';
  static const keep = 'Keep';

  static const editPriceTitle = 'Edit price';
  static String priceFor(String room) => '$room · price per night';
  static const priceHint = 'Price per night must be between ₹100 and ₹99,00,000';
  static String effectLine(String range, String price, bool lower, int percent) => '$range shows $price ($percent% ${lower ? 'lower' : 'higher'})';
  static const save = 'Save';
  static const priceUpdated = 'Price updated';
  static const rupee = '₹ ';

  static const couldNotLoad = 'Couldn’t load';
  static const checkConnection = 'Check your connection and try again.';
  static const tryAgain = 'Try again';
  static const showingLast = 'Could not refresh. Showing your last list.';
  static const noConnection = 'No connection. Please try again.';
  static const somethingWrong = 'Something went wrong. Try again.';
  static const keepOnePhoto = 'Keep at least one photo.';
}
