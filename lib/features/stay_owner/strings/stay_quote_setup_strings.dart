import '../../owner_core/strings/owner_shared_strings.dart';

abstract final class QuoteSetupStrings {
  static const quotations = 'Quotations';
  static const ownerOnly = 'Quotations are for stay owners.';
  static const connectOnce = 'Connect to the internet once to start.';
  static const updateApp = 'Update the app to continue.';
  static const notApproved = 'Quotations open once your stay is approved.';
  static const couldNotLoad = 'Could not load. Please try again.';
  static const couldNotSave = 'Could not save. Please try again.';
  static const offline = 'You are offline. Please try again.';
  static const tooMany = 'Too many tries. Please wait a little.';
  static const saved = 'Business details saved';

  static const title = 'Business details';
  static const subtitle = 'Filled once, used on every quotation';
  static const optional = 'Optional';
  static const save = 'Save';

  static const logo = 'Logo';
  static const logoHint = 'Square image is best';
  static const signature = 'Stamp or signature';
  static const signatureHint = 'Shown by the signature';
  static const imageAdded = 'Image added';
  static const noImage = 'No image yet';
  static const add = 'Add';
  static const change = 'Change';
  static const remove = 'Remove';
  static const uploading = 'Uploading...';
  static const imageFailed = 'Could not upload the image. Please try again.';
  static const imageInvalid = 'Use a JPG, PNG or WebP image.';
  static const imageTooLarge = 'This image is too large.';
  static const imageBusy = 'Busy right now. Try again in a few seconds.';
  static const imageRemoved = 'Image removed';

  static const businessName = 'Business name';
  static const nameLocked = 'Your approved stay name. To change it, request the admin.';
  static const requestChange = 'Request change';
  static String namePending(String name) => 'Name change waiting for review: $name';
  static const nameApproved = 'Your name change was approved.';
  static const nameRejected = 'Your name change was not approved.';

  static const slogan = 'Slogan';
  static const address = 'Address';
  static const phone = 'Phone';
  static const email = 'Email';

  static const termsRow = 'Terms for quotations';
  static String agreedOn(String date) => 'You agreed on $date';

  static const gstin = 'GST number';
  static const gstinHelp = 'Leave empty if you are not GST registered. Then no GST line is shown.';
  static const gstinInvalid = 'Enter a valid GST number.';
  static const gstinMismatch = 'This GST number does not match the one on your stay.';

  static const bankAndUpi = 'Bank and UPI';
  static const bankAccount = 'Bank account';
  static const addBank = 'Add bank account';
  static String accountLine(String last4, String ifsc) => 'A/c XXXX XXXX $last4${ifsc.isEmpty ? '' : ' · IFSC $ifsc'}';
  static const upi = 'UPI ID';
  static const upiInvalid = 'Enter a valid UPI ID.';
  static const shownOnDocs = 'Shown only on your documents';
  static const bankOff = 'Bank details cannot be saved right now. You can add them later.';
  static const bankUnreadable = 'Your saved bank details could not be read. Please add them again.';
  static const bankLoading = 'Loading bank details...';

  static const defaultTerms = 'Default terms';
  static const cancellation = 'Cancellation policy';

  static const bankSheetTitle = 'Bank account';
  static const holder = 'Account holder';
  static const accountNo = 'Account number';
  static const ifsc = 'IFSC';
  static const bankName = 'Bank';
  static const branch = 'Branch';
  static const done = 'Done';
  static const accountInvalid = 'Enter 9 to 18 digits.';
  static const ifscInvalid = 'Enter a valid IFSC, like SBIN0001234.';
  static const bankFieldsNeeded = 'Fill account holder, account number, IFSC and bank.';

  static const nameSheetTitle = 'Request a name change';
  static const nameSheetSub = 'Name changes need admin approval and are not guaranteed.';
  static const currentName = 'Current name';
  static const newName = 'New name';
  static const reason = 'Reason';
  static const sendRequest = 'Send request';
  static const notNow = OwnerSharedStrings.notNow;
  static const nameRule = 'Use 2 to 80 characters.';
  static const nameSame = 'Enter a different name.';
  static const requestSent = 'Request sent to the admin';
  static const requestLimit = 'You have sent enough requests today. Try again tomorrow.';

  static const tooLong = 'This is too long.';
  static const phoneInvalid = 'Enter a valid phone number.';
  static const emailInvalid = 'Enter a valid email.';
  static const checkFields = 'Please check the highlighted fields.';
}
