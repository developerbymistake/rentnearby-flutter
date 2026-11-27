abstract final class StayQuoteStrings {
  static const months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String dayMonth(DateTime d) => '${d.day} ${monthsShort[d.month - 1]}';
  static String weekdayDayMonth(DateTime d) => '${weekdays[d.weekday - 1]}, ${dayMonth(d)}';
  static String dayMonthYear(DateTime d) => '${d.day} ${monthsShort[d.month - 1]} ${d.year}';
  static String range(DateTime a, DateTime b) =>
      a.month == b.month && a.year == b.year ? '${a.day} – ${dayMonth(b)}' : '${dayMonth(a)} – ${dayMonth(b)}';
  static String clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'am' : 'pm'}';
  }

  // Home card and entries
  static const title = 'Quotations';
  static const homeSub = 'Make a quotation or proforma as PDF';
  static const thisMonth = 'This month';
  static const newQuotation = 'New quotation';
  static const makeQuotation = 'Make quotation';
  static const fromAnEnquiry = 'From an enquiry';
  static const businessDetails = 'Business details';

  // Usage lines (numbers always from the plan limits)
  static String ofUsed(int used, int limit) => used >= limit ? allUsed(limit) : '$used of $limit used';
  static String allUsed(int limit) => 'All $limit used this month';
  static String freeLine(int used, int limit) => 'Free plan · ${ofUsed(used, limit)}';
  static String plusLine(int used, int limit) => 'Plus · ${ofUsed(used, limit)}';
  static String offLine(int used, int limit) => used >= limit ? allUsed(limit) : '$used of $limit used this month';
  static String resetsFree(DateTime resets) => 'Resets on 1 ${monthsShort[resets.month - 1]} · Preview is always free';
  static String resetsFull(DateTime resets) => 'Resets on 1 ${monthsShort[resets.month - 1]} · Preview still works';
  static String plusTill(int limit, DateTime end) => '$limit quotations a month · Plus till ${dayMonthYear(end)}';
  static String plusEndsOn(int limit, DateTime end) => '$limit quotations a month · Plus ends on ${dayMonthYear(end)}';
  static String plusEnded(DateTime end) => 'Plus ended on ${dayMonthYear(end)}';
  static const plusEndedNoDate = 'Plus ended';
  static String freeMakes(int limit) => 'Free plan makes $limit a month';
  static const resetsSoon = 'Preview is always free';
  static const offlineNoCount = 'Connect to see this month’s count';

  // List
  static const downloadedHere = 'Downloaded on this phone';
  static const nothingOnline = 'Nothing is kept online.';
  static const notDownloaded = 'Not downloaded yet';
  static const draft = 'Draft';
  static const kindQuotation = 'Quotation';
  static const kindProforma = 'Proforma';
  static const open = 'Open';
  static const today = 'Today';
  static const emptyTitle = 'No quotations yet';
  static const emptyBody = 'Start a new quotation, or make one from an enquiry.';
  static const offline = 'Offline';
  static const firstOpenOffline = 'Connect to the internet once to set up quotations.';
  static const fileGone = 'This file is no longer in Downloads. Download it again.';
  static String rowSub(String kind, String? dates, String? total) => [kind, ?dates, ?total].join(' · ');

  // Form
  static const newProforma = 'New proforma invoice';
  static const editQuotation = 'Quotation';
  static const editProforma = 'Proforma invoice';
  static String fromEnquiry(String guest) => 'From $guest’s enquiry';
  static const documentType = 'Document type';
  static const typeQuotation = 'Quotation';
  static const typeProforma = 'Proforma invoice';
  static String titleOnPdf(String title, String number) => 'Title on the PDF: ${title.toUpperCase()} · number $number';
  static const proformaOwnNumber = 'A proforma gets its own number (PI-) and counts as a new download.';
  static const number = 'Number';
  static const givenOnDownload = 'Given when you download';
  static const date = 'Date';
  static const validTill = 'Valid till';
  static const guest = 'Guest';
  static const fromEnquiryChip = 'From enquiry';
  static const guestName = 'Guest name';
  static const phone = 'Phone';
  static const optional = 'Optional';
  static const bookedBy = 'Booked by';
  static const stay = 'Stay';
  static String nights(int n) => n == 1 ? '1 night' : '$n nights';
  static const checkIn = 'Check-in';
  static const checkOut = 'Check-out';
  static const pickDates = 'Pick dates';
  static const adults = 'Adults';
  static const kids = 'Kids';
  static const rooms = 'Rooms';
  static const mealPlan = 'Meal plan';
  static const mealEp = 'EP';
  static const mealCp = 'CP';
  static const mealMap = 'MAP';
  static const mealAp = 'AP';
  static const mealEpSub = 'Room only';
  static const mealCpSub = 'Breakfast';
  static const mealMapSub = '2 meals';
  static const mealApSub = 'All meals';
  static const items = 'Items';
  static String lines(int n) => n == 1 ? '1 line' : '$n lines';
  static const addLine = 'Add line';
  static const quickAdd = 'Quick add';
  static const quickRoom = 'Room';
  static const quickExtra = 'Extra person';
  static const quickBreakfast = 'Breakfast';
  static const quickPackage = 'Package';
  static const quickRoomChip = '+ Room';
  static const quickExtraChip = '+ Extra person';
  static const quickBreakfastChip = '+ Breakfast';
  static const quickPackageChip = '+ Package';
  static const quickRoomText = 'Room, double occupancy';
  static const subtotal = 'Subtotal';
  static const totals = 'Totals';
  static String subtotalLines(int n) => 'Subtotal (${lines(n)})';
  static const discount = 'Discount';
  static const gst = 'GST';
  static const percentSuffix = '%';
  static const yourRate = 'Your rate';
  static const taxable = 'Taxable value';
  static String gstPercent(String p) => 'GST $p%';
  static const roundOff = 'Round off';
  static const total = 'Total';
  static const gstHint = 'Add your GST number in Business details to show GST.';
  static const noteForGuest = 'Note for the guest';
  static const termsTitle = 'Terms and cancellation';
  static const fromBusiness = 'From business details';
  static const useSavedTerms = 'Use my saved terms';
  static const useSavedCancellation = 'Use my saved cancellation policy';
  static const termsForDoc = 'Terms for this document';
  static const cancellationForDoc = 'Cancellation policy for this document';
  static const docOnly = 'Changes apply to this document only. Your saved policy stays the same.';
  static const noSavedText = 'Nothing saved in Business details yet.';
  static const paymentsReceived = 'Payments received';
  static const payAdvance = '+ Advance';
  static const payBank = '+ Bank';
  static const payCash = '+ Cash';
  static const payUpi = '+ UPI';
  static const payAdvanceLabel = 'Advance cash';
  static const payBankLabel = 'Bank transfer';
  static const payCashLabel = 'Cash';
  static const payUpiLabel = 'UPI';
  static const received = 'Received';
  static const balance = 'Balance';
  static const chooseTemplate = 'Choose template';
  static const remove = 'Remove';
  static const edit = 'Edit';

  // Form errors
  static const errGuest = 'Enter the guest name.';
  static const errLines = 'Add at least one line.';
  static const errDates = 'Check-out must be after check-in.';
  static const errDiscount = 'Discount cannot be more than the subtotal.';
  static const errGst = 'GST must be between 0 and 28%.';
  static const errReceived = 'Payments received cannot be more than the total.';
  static const errValid = 'Valid till cannot be before the date.';
  static const errTotal = 'The total is too large.';
  static const fixForm = 'Check the marked fields first.';

  // Line sheet
  static const editLine = 'Edit line';
  static const description = 'Description';
  static const descriptionSuggestions = ['Room, double occupancy', 'Extra person', 'Breakfast', 'Lunch', 'Dinner', 'Package'];
  static const rate = 'Rate';
  static const perNight = 'Per night';
  static const qty = 'Qty';
  static const nightsLabel = 'Nights';
  static const add = 'Add';
  static const save = 'Save';
  static String lineMath(String rate, int qty, int nights) => '$rate × $qty × $nights';
  static String lineSub(String rate, int qty, int nights) => '$rate rate · ${StayQuoteStrings.qty} $qty · ${StayQuoteStrings.nights(nights)}';
  static const errDescription = 'Enter a description.';
  static const errRate = 'Enter a rate up to ₹99,99,999.';
  static String errQty(int max) => 'Enter a quantity from 1 to $max.';
  static String errNights(int max) => 'Enter nights from 1 to $max.';

  // Payment sheet
  static const payment = 'Payment received';
  static const label = 'Label';
  static const amount = 'Amount';

  // Enquiry chooser
  static const chooseEnquiry = 'Choose an enquiry';
  static const noEnquiries = 'No open enquiries. Start a new quotation instead.';

  // Templates
  static const classic = 'Classic';
  static const classicSub = 'Ruled table with full borders, like a printed bill.';
  static const band = 'Colour band';
  static const bandSub = 'Green title band, rounded table, thank-you strip.';
  static const modern = 'Modern';
  static const modernSub = 'Side panel for guest and stay, clean open table.';
  static const preview = 'Preview';

  // Preview and download
  static const change = 'Change';
  static const previewOnly = 'Preview only. The PDF is made when you download.';
  static const downloadPdf = 'Download PDF';
  static String downloadsLine(String usage) => 'Downloads this month: $usage';
  static String freeUntil(DateTime t) => 'This download is free until ${clock(t)}, ${dayMonth(t)}';
  static const updateToDownload = 'Update the app to download.';
  static const savedTitle = 'Saved to Downloads';
  static String savedSub(String file, int pages) => '$file · A4, ${pages == 1 ? '1 page' : '$pages pages'}';
  static const template = 'Template';
  static const downloadsThisMonth = 'Downloads this month';
  static String freeReDownload(DateTime t) => 'Free re-download until ${clock(t)}, ${dayMonth(t)}';
  static const openFile = 'Open file';
  static const done = 'Done';
  static const offlineDownload = 'You are offline. Connect to download. Your quotation is saved on this phone.';
  static const renderFailed = 'Could not make the PDF. Try again.';
  static const tooLong = 'This document is too long for two pages. Shorten the terms or remove a line.';
  static const unsupported = 'Update Android System WebView from Play Store to make PDFs.';
  static const noPdfApp = 'No app to open PDFs. You can find the file in Downloads.';
  static const storageDenied = 'Allow storage access to save the PDF in Downloads.';
  static const noSpace = 'Not enough space on this phone to save the PDF.';
  static const busy = 'Still working on the last one. Try again in a moment.';
  static const reserveFailed = 'Could not get a number. Try again.';
  static const notApproved = 'Quotations open after your stay is approved.';
  static const termsNeeded = 'Accept the terms for quotations first.';

  // Limits
  static String limitTitle(int used, int limit) => used > limit ? allUsed(limit) : '$used of $limit quotations used';
  static String limitBody(int free, int plus) => 'The Free plan makes $free quotations a month. Plus makes $plus quotations a month.';
  static String perMonth(int n) => '$n a month';
  static const freePlan = 'Free plan';
  static const plusLabel = 'Plus';
  static String limitTip(DateTime resets) => 'Preview always works. Your count resets on 1 ${monthsShort[resets.month - 1]}.';
  static const limitTipNoDate = 'Preview always works.';
  static String calmBody(int limit, DateTime resets) => 'You have used all $limit quotations this month. Resets on 1 ${months[resets.month - 1]}.';
  static String calmBodyNoDate(int limit) => 'You have used all $limit quotations this month.';
  static const calmNote = 'You can still edit and preview. A quotation downloaded in the last 24 hours can be downloaded again.';
  static const ok = 'OK';

  // Plans page
  static const planRow = 'Quotations a month';
  static String planPerk(int n) => 'Up to $n quotations a month';
}
