import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_doc.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_draft.dart';
import 'package:bakhli/features/stay_owner/strings/stay_quote_doc_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quote_fakes.dart';

void main() {
  group('Q7 type sets title and prefix', () {
    test('quotation: title, Q- hint number from the hub, valid till', () {
      final j = QuoteDocBuilder.build(sampleDraft(), sampleBusiness()).toJson();
      expect(j['kind'], 'Quotation');
      expect(j['title'], 'Quotation');
      expect(j['number'], 'Q-0042');
      expect(j['numberLabel'], 'Quotation no');
      expect(j['validTill'], '19 Nov 2026');
      expect((j['footer'] as Map)['proformaNote'], '');
    });

    test('proforma: PI- number, not-a-tax-invoice line, payments and balance', () {
      final d = sampleDraft(kind: QuoteKind.proforma).copyWith(payments: [
        QuotePayment(id: 'p1', kind: QuotePayKind.advance, label: 'Advance cash', date: DateTime(2026, 11, 10), amount: 20000),
        QuotePayment(id: 'p2', kind: QuotePayKind.bank, label: 'Bank transfer', date: DateTime(2026, 11, 14), amount: 50000),
        QuotePayment(id: 'p3', kind: QuotePayKind.cash, label: 'Cash', date: DateTime(2026, 11, 23), amount: 30000),
      ]);
      final j = QuoteDocBuilder.build(d, sampleBusiness()).toJson();
      expect(j['kind'], 'Proforma');
      expect(j['number'], 'PI-0007');
      expect(j['validTill'], '');
      expect((j['footer'] as Map)['proformaNote'], StayQuoteDocStrings.notTaxInvoice);
      expect(j['received'], '1,00,000');
      expect(j['balance'], '₹ 41,026');
      expect(j['balanceWords'], 'Rupees Forty-One Thousand Twenty-Six Only');
      expect((j['payments'] as List).length, 3);
    });

    test('a saved reservation number wins over the hint; the real number is passed at render', () {
      final d = sampleDraft().withReservation(
        QuoteKind.quotation,
        QuoteReservation(number: 50, display: 'Q-0050', issuedAt: DateTime(2026), freeUntil: DateTime(2026), freeLeft: 5, businessName: 'X'),
      );
      expect(QuoteDocBuilder.build(d, sampleBusiness()).toJson()['number'], 'Q-0050');
      expect(QuoteDocBuilder.build(d, sampleBusiness(), number: 'Q-0051', businessName: 'Approved Name').toJson()['businessName'], 'Approved Name');
    });
  });

  test('Q9 totals as final strings; GST rows only with a GSTIN', () {
    final t = QuoteDocBuilder.build(sampleDraft(), sampleBusiness()).toJson()['totals'] as Map;
    expect(t['subtotal'], '1,39,310');
    expect(t['discount'], '-5,000');
    expect(t['taxable'], '1,34,310');
    expect(t['gstLabel'], 'GST @ 5%');
    expect(t['gst'], '6,715.50');
    expect(t['roundOff'], '+0.50');
    expect(t['total'], '₹ 1,41,026');
    expect(t['words'], 'Rupees One Lakh Forty-One Thousand Twenty-Six Only');
    final noGst = QuoteDocBuilder.build(sampleDraft(), sampleBusiness(gstin: '')).toJson();
    final t2 = noGst['totals'] as Map;
    expect(t2['gst'], '');
    expect(t2['gstLabel'], '');
    expect(t2['roundOff'], '');
    expect(t2['total'], '₹ 1,34,310');
    expect(noGst['gstin'], '');
  });

  test('Q10 ticked terms print the master text; unticked print the document copy, master untouched', () {
    final b = sampleBusiness();
    expect(QuoteDocBuilder.build(sampleDraft(), b).toJson()['terms'], b.termsText);
    final own = sampleDraft().copyWith(useSavedTerms: false, termsText: 'Only for this group.', useSavedCancellation: false, cancellationText: 'No refund.');
    final j = QuoteDocBuilder.build(own, b).toJson();
    expect(j['terms'], 'Only for this group.');
    expect(j['cancellation'], 'No refund.');
    expect(b.termsText, 'Check-in from 12:00 pm.\nRates are per night.');
  });

  test('stay, lines, guest and labels are display strings; bidi stripped', () {
    final d = sampleDraft().copyWith(guestName: 'Ali‮fdp');
    final j = QuoteDocBuilder.build(d, sampleBusiness(), owner: 'user-1').toJson();
    expect((j['guest'] as Map)['name'], 'Alifdp');
    final stay = j['stay'] as Map;
    expect(stay['checkIn'], 'Mon, 23 Nov 2026');
    expect(stay['nights'], '2 nights');
    expect(stay['guests'], '12 adults, 2 kids · 5 rooms');
    expect(stay['mealPlan'], StayQuoteDocStrings.mealAp);
    final first = (j['lines'] as List).first as Map;
    expect(first['amount'], '1,00,000');
    expect(first['rate'], '10,000');
    expect(j['owner'], 'user-1');
    expect(j['logo'], isTrue);
    expect(j['assetsVersion'], 3);
    expect((j['labels'] as Map).values.every((v) => v is String), isTrue);
    expect(j.containsKey('preparedBy'), isTrue);
  });

  test('meal plan none and no rooms are left out', () {
    final d = sampleDraft().copyWith(meal: QuoteMeal.none, rooms: 0, kids: 0);
    final stay = QuoteDocBuilder.build(d, sampleBusiness()).toJson()['stay'] as Map;
    expect(stay['mealPlan'], '');
    expect(stay['rooms'], '');
    expect(stay['guests'], '12 adults');
  });
}
