import '../../strings/stay_quote_doc_strings.dart';
import '../data/quote_models.dart';
import 'quote_business.dart';
import 'quote_draft.dart';
import 'quote_money.dart';
import 'quote_text_clean.dart';
import 'quote_words.dart';

// The view model given to the A4 template: every value is a final display string (the template never calculates).
class QuoteDoc {
  const QuoteDoc(this.json, {required this.lineCount, required this.totals});

  final Map<String, dynamic> json;
  final int lineCount;
  final QuoteTotals totals;

  Map<String, dynamic> toJson() => json;
}

abstract final class QuoteDocBuilder {
  static String meal(QuoteMeal m) => switch (m) {
        QuoteMeal.ep => StayQuoteDocStrings.mealEp,
        QuoteMeal.cp => StayQuoteDocStrings.mealCp,
        QuoteMeal.map => StayQuoteDocStrings.mealMap,
        QuoteMeal.ap => StayQuoteDocStrings.mealAp,
        QuoteMeal.none => '',
      };

  static String mealCode(QuoteMeal m) => m == QuoteMeal.none ? '' : m.name.toUpperCase();

  static String terms(QuoteDraft d, QuoteBusiness b) =>
      QuoteTextClean.block(d.useSavedTerms ? b.termsText : d.termsText, QuoteLimits.terms);

  static String cancellation(QuoteDraft d, QuoteBusiness b) =>
      QuoteTextClean.block(d.useSavedCancellation ? b.cancellationText : d.cancellationText, QuoteLimits.cancellation);

  static QuoteTotals totals(QuoteDraft d, QuoteBusiness b) => QuoteMoney.compute(
        lineAmounts: d.lines.map((l) => l.amount),
        discount: d.discount,
        gstBp: d.gstBp,
        gstAllowed: b.hasGstin,
        payments: d.kind == QuoteKind.proforma ? d.payments.map((p) => p.amount) : const [],
      );

  static String hintDisplay(QuoteDraft d, QuoteBusiness b) {
    final r = d.reservation;
    if (r != null) return r.display;
    return QuoteKinds.display(d.kind, d.kind == QuoteKind.proforma ? b.nextProforma : b.nextQuotation);
  }

  static String _guests(QuoteDraft d) {
    final people = [
      StayQuoteDocStrings.adults(d.adults),
      if (d.kids > 0) StayQuoteDocStrings.kids(d.kids),
    ].join(', ');
    return d.rooms > 0 ? '$people · ${StayQuoteDocStrings.rooms(d.rooms)}' : people;
  }

  static String _lineDetail(QuoteLine l) =>
      '${QuoteMoney.group(l.rate)} × ${l.qty} × ${StayQuoteDocStrings.nights(l.nights)}';

  static QuoteDoc build(
    QuoteDraft d,
    QuoteBusiness b, {
    String? number,
    String? businessName,
    String? owner,
  }) {
    final proforma = d.kind == QuoteKind.proforma;
    final t = totals(d, b);
    final name = QuoteTextClean.line(businessName ?? b.name, 120);
    final shownNumber = number ?? hintDisplay(d, b);
    final quotationRef = proforma ? d.reservationFor(QuoteKind.quotation)?.display ?? '' : '';
    final a = d.checkIn;
    final c = d.checkOut;
    final n = d.nights;
    final bank = b.bank;
    final branchLine = [bank.bank, bank.branch].where((s) => s.trim().isNotEmpty).join(', ');
    final json = <String, dynamic>{
      'kind': proforma ? 'Proforma' : 'Quotation',
      'title': proforma ? StayQuoteDocStrings.proforma : StayQuoteDocStrings.quotation,
      'number': shownNumber,
      'numberLabel': proforma ? StayQuoteDocStrings.invoiceNo : StayQuoteDocStrings.quotationNo,
      'quotationRef': quotationRef,
      'date': StayQuoteDocStrings.day(d.date),
      'validTill': proforma ? '' : StayQuoteDocStrings.day(d.validTill),
      'businessName': name,
      'slogan': QuoteTextClean.line(b.slogan, 80),
      'address': QuoteTextClean.block(b.address, 240),
      'phone': QuoteTextClean.line(b.phone, 20),
      'email': QuoteTextClean.line(b.email, 120),
      'gstin': b.hasGstin ? QuoteTextClean.line(b.gstin, 15) : '',
      'logo': b.hasLogo,
      'signature': b.hasSignature,
      'assetsVersion': b.assetsVersion,
      'owner': owner ?? '',
      'preparedBy': QuoteTextClean.line(b.preparedBy, 80),
      'guest': {
        'name': QuoteTextClean.line(d.guestName, QuoteLimits.guestName),
        'phone': QuoteTextClean.line(d.guestPhone, QuoteLimits.guestPhone),
        'bookedBy': QuoteTextClean.line(d.bookedBy, QuoteLimits.bookedBy),
      },
      'stay': {
        'checkIn': a == null ? '' : StayQuoteDocStrings.weekdayDay(a),
        'checkOut': c == null ? '' : StayQuoteDocStrings.weekdayDay(c),
        'nights': n > 0 ? StayQuoteDocStrings.nights(n) : '',
        'guests': _guests(d),
        'rooms': d.rooms > 0 ? StayQuoteDocStrings.rooms(d.rooms) : '',
        'mealPlan': meal(d.meal),
        'mealCode': mealCode(d.meal),
        'range': a != null && c != null ? '${StayQuoteDocStrings.day(a)} – ${StayQuoteDocStrings.day(c)}' : '',
      },
      'lines': [
        for (var i = 0; i < d.lines.length; i++)
          {
            'no': '${i + 1}',
            'no2': (i + 1).toString().padLeft(2, '0'),
            'description': QuoteTextClean.line(d.lines[i].description, QuoteLimits.description),
            'detail': _lineDetail(d.lines[i]),
            'rate': QuoteMoney.group(d.lines[i].rate),
            'qty': '${d.lines[i].qty}',
            'nights': '${d.lines[i].nights}',
            'amount': QuoteMoney.group(d.lines[i].amount),
          },
      ],
      'totals': {
        'subtotal': QuoteMoney.group(t.subtotal),
        'discount': t.discount > 0 ? '-${QuoteMoney.group(t.discount)}' : '',
        'taxable': t.hasGst ? QuoteMoney.group(t.taxable) : '',
        'gstLabel': t.hasGst ? StayQuoteDocStrings.gstAt(QuoteMoney.bpText(t.gstBp)) : '',
        'gst': t.hasGst ? QuoteMoney.paise(t.gstPaise) : '',
        'roundOff': t.roundOffPaise != 0 ? QuoteMoney.signedPaise(t.roundOffPaise) : '',
        'total': '₹ ${QuoteMoney.group(t.total)}',
        'words': QuoteWords.rupees(t.total),
      },
      'payments': proforma
          ? [
              for (final p in d.payments)
                {
                  'label': QuoteTextClean.line(p.label, QuoteLimits.payLabel),
                  'date': StayQuoteDocStrings.day(p.date),
                  'amount': QuoteMoney.group(p.amount),
                },
            ]
          : const <Map<String, String>>[],
      'received': proforma && d.payments.isNotEmpty ? QuoteMoney.group(t.received) : '',
      'balance': proforma ? '₹ ${QuoteMoney.group(t.balance)}' : '',
      'balanceWords': proforma ? QuoteWords.rupees(t.balance) : '',
      'note': QuoteTextClean.block(d.note, QuoteLimits.note),
      'terms': terms(d, b),
      'cancellation': cancellation(d, b),
      'bank': {
        'holder': QuoteTextClean.line(bank.holder, 60),
        'accountNo': QuoteTextClean.line(bank.accountNo, 18),
        'ifsc': QuoteTextClean.line(bank.ifsc, 11),
        'bank': QuoteTextClean.line(branchLine, 130),
        'branch': '',
        'upi': QuoteTextClean.line(bank.upi, 60),
      },
      'labels': StayQuoteDocStrings.labels(),
      'footer': {
        'preparedBy': name.isEmpty ? '' : StayQuoteDocStrings.preparedByLine(name),
        'pagePattern': StayQuoteDocStrings.pagePattern,
        'notTaxInvoice': proforma ? StayQuoteDocStrings.notTaxInvoice : '',
        'forBusiness': name.isEmpty ? '' : StayQuoteDocStrings.forBusiness(name),
        'thankYou': name.isEmpty ? '' : StayQuoteDocStrings.thankYou(name),
        'kindLabel': proforma ? StayQuoteDocStrings.proforma : StayQuoteDocStrings.quotation,
      },
    };
    return QuoteDoc(json, lineCount: d.lines.length, totals: t);
  }
}
