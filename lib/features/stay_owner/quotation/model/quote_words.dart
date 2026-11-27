import '../../strings/stay_quote_doc_strings.dart';

abstract final class QuoteWords {
  static const int max = 9999999999;

  static String _two(int n) {
    const s = StayQuoteDocStrings.ones;
    if (n < 20) return s[n];
    final t = StayQuoteDocStrings.tens[n ~/ 10];
    return n % 10 == 0 ? t : '$t-${s[n % 10]}';
  }

  static String _three(int n) {
    final h = n ~/ 100;
    final r = n % 100;
    return [
      if (h > 0) '${StayQuoteDocStrings.ones[h]} ${StayQuoteDocStrings.hundred}',
      if (r > 0) _two(r),
    ].join(' ');
  }

  static String _group(int n) => n < 100 ? _two(n) : _three(n);

  // Indian system: "Rupees One Lakh Forty-One Thousand Twenty-Six Only".
  static String rupees(int amount) {
    var n = amount < 0 ? 0 : (amount > max ? max : amount);
    if (n == 0) return StayQuoteDocStrings.rupeesZero;
    final cr = n ~/ 10000000;
    n %= 10000000;
    final lk = n ~/ 100000;
    n %= 100000;
    final th = n ~/ 1000;
    n %= 1000;
    final parts = [
      if (cr > 0) '${_group(cr)} ${StayQuoteDocStrings.crore}',
      if (lk > 0) '${_two(lk)} ${StayQuoteDocStrings.lakh}',
      if (th > 0) '${_two(th)} ${StayQuoteDocStrings.thousand}',
      if (n > 0) _three(n),
    ];
    return '${StayQuoteDocStrings.rupees} ${parts.join(' ')} ${StayQuoteDocStrings.only}';
  }
}
