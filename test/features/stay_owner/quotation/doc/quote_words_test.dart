import 'package:bakhli/features/stay_owner/quotation/model/quote_words.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Q9 Indian number words', () {
    expect(QuoteWords.rupees(0), 'Rupees Zero Only');
    expect(QuoteWords.rupees(1), 'Rupees One Only');
    expect(QuoteWords.rupees(19), 'Rupees Nineteen Only');
    expect(QuoteWords.rupees(100), 'Rupees One Hundred Only');
    expect(QuoteWords.rupees(100000), 'Rupees One Lakh Only');
    expect(QuoteWords.rupees(141026), 'Rupees One Lakh Forty-One Thousand Twenty-Six Only');
    expect(QuoteWords.rupees(41026), 'Rupees Forty-One Thousand Twenty-Six Only');
    expect(QuoteWords.rupees(10000000), 'Rupees One Crore Only');
    expect(QuoteWords.rupees(9999999999), 'Rupees Nine Hundred Ninety-Nine Crore Ninety-Nine Lakh Ninety-Nine Thousand Nine Hundred Ninety-Nine Only');
  });

  test('negative and above-cap amounts stay inside the range', () {
    expect(QuoteWords.rupees(-5), 'Rupees Zero Only');
    expect(QuoteWords.rupees(99999999999), QuoteWords.rupees(9999999999));
  });
}
