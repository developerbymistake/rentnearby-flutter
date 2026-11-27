import 'package:bakhli/features/stay_owner/quotation/model/quote_money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Q9 money (paise integers)', () {
    test('mock numbers: 1,39,310 - 5,000 + GST 5% -> 1,41,026 with +0.50 round off', () {
      final t = QuoteMoney.compute(lineAmounts: [100000, 28000, 5310, 6000], discount: 5000, gstBp: 500, gstAllowed: true);
      expect(t.subtotal, 139310);
      expect(t.taxable, 134310);
      expect(t.gstPaise, 671550);
      expect(QuoteMoney.paise(t.gstPaise), '6,715.50');
      expect(t.total, 141026);
      expect(t.roundOffPaise, 50);
      expect(QuoteMoney.signedPaise(t.roundOffPaise), '+0.50');
      expect(QuoteMoney.group(t.total), '1,41,026');
    });

    test('.50 rounds up, .49 rounds down', () {
      expect(QuoteMoney.roundHalfUpDiv(150, 100), 2);
      expect(QuoteMoney.roundHalfUpDiv(149, 100), 1);
      expect(QuoteMoney.roundHalfUpDiv(50, 100), 1);
      expect(QuoteMoney.roundHalfUpDiv(49, 100), 0);
      final t = QuoteMoney.compute(lineAmounts: [1001], gstBp: 50, gstAllowed: true);
      expect(t.gstPaise, 501);
      expect(t.total, 1006);
      expect(t.roundOffPaise, -1);
      expect(QuoteMoney.signedPaise(t.roundOffPaise), '-0.01');
    });

    test('discount is capped at the subtotal and never negative', () {
      expect(QuoteMoney.compute(lineAmounts: [1000], discount: 5000).taxable, 0);
      expect(QuoteMoney.compute(lineAmounts: [1000], discount: -10).discount, 0);
    });

    test('GST only with a GSTIN', () {
      final t = QuoteMoney.compute(lineAmounts: [10000], gstBp: 1800, gstAllowed: false);
      expect(t.hasGst, isFalse);
      expect(t.gstPaise, 0);
      expect(t.total, 10000);
      expect(t.roundOffPaise, 0);
    });

    test('proforma balance = total - received', () {
      final t = QuoteMoney.compute(lineAmounts: [100000, 28000, 5310, 6000], discount: 5000, gstBp: 500, gstAllowed: true, payments: [20000, 50000, 30000]);
      expect(t.received, 100000);
      expect(t.balance, 41026);
    });

    test('GST text parses 0-28 with up to 2 decimals', () {
      expect(QuoteMoney.parseBp('5'), 500);
      expect(QuoteMoney.parseBp('12.5'), 1250);
      expect(QuoteMoney.parseBp('18.00'), 1800);
      expect(QuoteMoney.parseBp(''), 0);
      expect(QuoteMoney.parseBp('28'), 2800);
      expect(QuoteMoney.parseBp('28.01'), isNull);
      expect(QuoteMoney.parseBp('5.555'), isNull);
      expect(QuoteMoney.parseBp('abc'), isNull);
      expect(QuoteMoney.bpText(500), '5');
      expect(QuoteMoney.bpText(1250), '12.5');
      expect(QuoteMoney.bpText(1225), '12.25');
    });

    test('total above the cap is flagged', () {
      expect(QuoteMoney.compute(lineAmounts: [QuoteMoney.maxTotal + 1]).tooLarge, isTrue);
      expect(QuoteMoney.compute(lineAmounts: [QuoteMoney.maxTotal]).tooLarge, isFalse);
    });
  });
}
