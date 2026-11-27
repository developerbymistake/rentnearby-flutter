import 'package:bakhli/features/stay_owner/quotation/controllers/quote_form_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_business.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_draft.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_prefill.dart';
import 'package:bakhli/features/stay_owner/strings/stay_quote_strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'quote_fakes.dart';

void main() {
  late TimerLog timers;
  var seq = 0;

  QuoteFormController make({QuoteDraft? draft, String gstin = '05ABCDE1234F1Z5'}) {
    timers = TimerLog();
    return QuoteFormController(
      initial: draft ?? QuoteFormController.blank('doc-00000001', DateTime(2026, 11, 12, 9)),
      store: memoryStore(timers: timers),
      business: sampleBusiness(gstin: gstin),
      newId: () => 'id${seq++}',
      now: () => DateTime(2026, 11, 12, 9),
    );
  }

  tearDown(Get.reset);

  test('Q3 blank: today, valid till +7 days, type Quotation, hint number', () {
    final c = make();
    final d = c.draft.value;
    expect(d.kind, QuoteKind.quotation);
    expect(d.date, DateTime(2026, 11, 12));
    expect(d.validTill, DateTime(2026, 11, 19));
    expect(d.lines, isEmpty);
    expect(c.numberHint, 'Q-0042');
  });

  test('add, edit and delete lines; amounts live', () {
    final c = make();
    expect(c.addLine(description: 'Room, double occupancy', rate: 10000, qty: 5, nights: 2), isTrue);
    expect(c.totals.subtotal, 100000);
    final id = c.draft.value.lines.single.id;
    expect(c.updateLine(id, description: 'Room', rate: 9000, qty: 5, nights: 2), isTrue);
    expect(c.totals.subtotal, 90000);
    c.removeLine(id);
    expect(c.draft.value.lines, isEmpty);
  });

  test('line rules: description required, rate 0-99,99,999, qty 1-999, nights 1-99, max 30 lines', () {
    final c = make();
    expect(c.addLine(description: ' ', rate: 100, qty: 1, nights: 1), isFalse);
    expect(c.addLine(description: 'X', rate: 10000000, qty: 1, nights: 1), isFalse);
    expect(c.addLine(description: 'X', rate: 100, qty: 0, nights: 1), isFalse);
    expect(c.addLine(description: 'X', rate: 100, qty: 1, nights: 100), isFalse);
    for (var i = 0; i < QuoteLimits.maxLines; i++) {
      expect(c.addLine(description: 'L$i', rate: 100, qty: 1, nights: 1), isTrue);
    }
    expect(c.canAddLine, isFalse);
    expect(c.addLine(description: 'One more', rate: 100, qty: 1, nights: 1), isFalse);
  });

  test('dates set nights and move lines that used the stay nights', () {
    final c = make();
    c.addLine(description: 'Room', rate: 1000, qty: 1, nights: 1);
    c.setDates(DateTime(2026, 11, 23), DateTime(2026, 11, 26));
    expect(c.draft.value.nights, 3);
    expect(c.draft.value.lines.single.nights, 3);
    expect(c.defaultNights, 3);
  });

  test('validation: guest name, dates, lines, discount, payments', () {
    final c = make();
    expect(c.validate(), isFalse);
    expect(c.errors[QuoteFieldKeys.guestName], StayQuoteStrings.errGuest);
    expect(c.errors[QuoteFieldKeys.lines], StayQuoteStrings.errLines);
    c.setGuestName('Harshit');
    c.addLine(description: 'Room', rate: 1000, qty: 1, nights: 1);
    c.setDiscount(5000);
    expect(c.validate(), isFalse);
    expect(c.errors[QuoteFieldKeys.discount], StayQuoteStrings.errDiscount);
    c.setDiscount(500);
    expect(c.validate(), isTrue);
    c.setKind(QuoteKind.proforma);
    final p = c.addPayment(QuotePayKind.cash)!;
    c.updatePayment(p.id, amount: 999999);
    expect(c.validate(), isFalse);
    expect(c.errors[QuoteFieldKeys.payments], StayQuoteStrings.errReceived);
  });

  test('GST: only with a GSTIN; text rules 0-28 with 2 decimals', () {
    final c = make();
    expect(c.setGstText('5'), isTrue);
    expect(c.draft.value.gstBp, 500);
    expect(c.setGstText('29'), isFalse);
    expect(c.errors[QuoteFieldKeys.gst], StayQuoteStrings.errGst);
    expect(c.draft.value.gstBp, 500);
    final noGst = make(gstin: '');
    expect(noGst.gstAllowed, isFalse);
    noGst.setGstText('18');
    expect(noGst.draft.value.gstBp, 0);
  });

  test('payments: max 6, labels from the kind', () {
    final c = make();
    c.setKind(QuoteKind.proforma);
    expect(c.addPayment(QuotePayKind.advance)!.label, StayQuoteStrings.payAdvanceLabel);
    for (var i = 0; i < 5; i++) {
      c.addPayment(QuotePayKind.upi);
    }
    expect(c.canAddPayment, isFalse);
    expect(c.addPayment(QuotePayKind.cash), isNull);
  });

  test('G11 hint when the other kind already has a number', () {
    final c = make(draft: sampleDraft().withReservation(
      QuoteKind.quotation,
      QuoteReservation(number: 42, display: 'Q-0042', issuedAt: DateTime(2026), freeUntil: DateTime(2026), freeLeft: 5, businessName: 'B'),
    ));
    expect(c.kindNeedsOwnNumber, isFalse);
    c.setKind(QuoteKind.proforma);
    expect(c.kindNeedsOwnNumber, isTrue);
    expect(c.numberHint, 'PI-0007');
  });

  test('unticking saved terms seeds an editable copy, master unchanged', () {
    final c = make();
    c.setUseSavedTerms(false);
    expect(c.draft.value.termsText, c.business.value.termsText);
    c.setTermsText('Only for this booking.');
    expect(c.business.value.termsText, isNot('Only for this booking.'));
  });

  test('every change schedules one debounced save', () {
    final c = make();
    c.setGuestName('A');
    c.setGuestName('AB');
    expect(timers.timers.length, 2);
    expect(timers.timers.first.cancelled, isTrue);
  });

  test('m5 a bad GST text keeps its error after the next edit, until it is fixed', () {
    final c = make();
    expect(c.setGstText('29'), isFalse);
    c.setGuestName('Harshit');
    expect(c.errors[QuoteFieldKeys.gst], StayQuoteStrings.errGst);
    expect(c.validate(), isFalse);
    expect(c.setGstText('12'), isTrue);
    c.setGuestName('Harshit R');
    expect(c.errors.containsKey(QuoteFieldKeys.gst), isFalse);
  });

  test('m6 quantity and nights errors have their own text', () {
    expect(QuoteFormController.lineError(description: 'Room', rate: 100, qty: 0, nights: 1), StayQuoteStrings.errQty(QuoteLimits.maxQty));
    expect(QuoteFormController.lineError(description: 'Room', rate: 100, qty: 1, nights: 0), StayQuoteStrings.errNights(QuoteLimits.maxNights));
    expect(QuoteFormController.lineError(description: 'Room', rate: -1, qty: 1, nights: 1), StayQuoteStrings.errRate);
  });

  test('m12 the same enquiry chosen twice does not add its lines twice', () {
    final c = make();
    const p = QuotePrefill(
      enquiryId: 'enq-1',
      guestName: 'Harshit',
      lines: [QuotePrefillLine(description: 'Deluxe room', rate: 10000, qty: 5, nights: 2)],
    );
    c.applyPrefill(p);
    c.applyPrefill(p);
    expect(c.draft.value.lines.length, 1);
  });

  test('I5 refreshBusiness: a GSTIN saved in Business details shows the GST field at once', () async {
    final c = make(gstin: '');
    expect(c.gstAllowed, isFalse);
    final source = FakeSource(business0: sampleBusiness());
    await c.refreshBusiness(source);
    expect(c.gstAllowed, isTrue);
  });

  test('I5 refreshBusiness keeps the bank lines when the secure copy cannot be read but a bank is saved', () async {
    final c = make();
    final source = FakeSource(business0: sampleBusiness().copyWith(bank: const QuoteBankLines()), bankSaved0: true);
    await c.refreshBusiness(source);
    expect(c.business.value.bank.accountNo, '30987654521');
    source.bankSaved0 = false;
    await c.refreshBusiness(source);
    expect(c.business.value.bank.isEmpty, isTrue);
  });

  test('I4 doc(assetsVersion:) prints the version the download resolved', () {
    final c = make();
    expect(c.doc().toJson()['assetsVersion'], 3);
    expect(c.doc(assetsVersion: 4).toJson()['assetsVersion'], 4);
  });
}
