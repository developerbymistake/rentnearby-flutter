// Quotation terms (ARCHITECTURE 7). Changing any line needs a new version and the server hash (QuoteTerms.Sha256).
abstract final class QuoteTermsStrings {
  static const int version = 1;

  static const title = 'Before you make quotations';
  static const subtitle = 'Please read this once.';
  static const agree = 'I have read and agree';
  static const continueLabel = 'Continue';
  static const readAgain = 'You can read this again in Business details.';
  static const reReadTitle = 'Terms for quotations';
  static const close = 'Close';

  static const lines = <String>[
    'The business details, bank, UPI and prices you enter are your own. You share them at your own risk.',
    'You make and send quotations and proforma invoices yourself. Bakhli does not take or handle payments and is not a party to your agreement with the guest.',
    'You are responsible for correct prices, taxes (GST) and terms.',
    'Use only your own logo, signature, stamp and tax numbers. You are responsible for every name and number you print.',
    'Bakhli and its team are not liable for any loss or dispute arising from documents you create.',
  ];

  static String get text => lines.join('\n');
}
