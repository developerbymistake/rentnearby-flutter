import 'dart:convert';

import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quote_setup_fakes.dart';

void main() {
  test('hub parses every contract field', () {
    final h = QuoteHub.fromJson(hubJson(pendingName: 'New'));
    expect(h.stay.name, 'The Banyan Retreat');
    expect(h.stay.approved, isTrue);
    expect(h.stay.pendingName, 'New');
    expect(h.preparedBy, 'Meena Bisht');
    expect(h.profile!.bank.accountLast4, '4521');
    expect(h.profile!.assetsVersion, 3);
    expect(h.terms.accepted, isTrue);
    expect(h.usage.used, 1);
    expect(h.usage.limit, 2);
    expect(h.usage.resetsAt, DateTime.utc(2026, 11, 30, 18, 30));
    expect(h.next.of(QuoteKind.proforma), 7);
    expect(h.previewWatermark, isTrue);
    expect(h.maxFreePerWindow, 5);
    expect(h.minTemplateVersion, 1);
    expect(h.hasGstin, isTrue);
  });

  test('profile null before the first save; terms not accepted without a version', () {
    final h = QuoteHub.fromJson(hubJson(profile: false, acceptedVersion: null));
    expect(h.profile, isNull);
    expect(h.terms.accepted, isFalse);
    expect(h.defaults.address, 'Stay address');
  });

  test('the phone cache carries no bank value and no UPI', () {
    final cached = jsonEncode(hubOf().toCacheJson());
    for (final secret in ['4521', 'SBIN0001234', 'ba***@sbi', 'State Bank', 'banyan@sbi']) {
      expect(cached, isNot(contains(secret)), reason: secret);
    }
    final back = QuoteHub.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    expect(back.profile!.bank.has, isTrue);
    expect(back.stay.name, 'The Banyan Retreat');
    expect(back.usage.limit, 2);
  });

  test('kind sets prefix and 4-digit number', () {
    expect(QuoteKind.quotation.display(42), 'Q-0042');
    expect(QuoteKind.proforma.display(7), 'PI-0007');
    expect(QuoteKind.quotation.display(12345), 'Q-12345');
    expect(QuoteKind.fromWire('Proforma'), QuoteKind.proforma);
    expect(QuoteKind.fromWire('x'), QuoteKind.quotation);
  });

  test('profile body never names the business; bank only with Set', () {
    const keep = QuoteProfileInput(slogan: 'S', gstin: '05ABCDE1234F1Z6');
    final j = keep.toJson();
    expect(j.containsKey('name'), isFalse);
    expect(j.containsKey('businessName'), isFalse);
    expect(j['bankMode'], 'Keep');
    expect(j['bank'], isNull);
    expect(j['email'], isNull);
    const set = QuoteProfileInput(bankMode: QuoteBankMode.set, bank: sampleBank);
    expect((set.toJson()['bank'] as Map)['accountNo'], '123456784521');
    expect(const QuoteProfileInput(bankMode: QuoteBankMode.clear, bank: sampleBank).toJson()['bank'], isNull);
  });

  test('reserve result and month limit data', () {
    final r = QuoteReserveResult.fromJson({
      'number': 42,
      'display': 'Q-0042',
      'kind': 'Quotation',
      'counted': true,
      'freeUntil': '2026-11-28T09:00:00Z',
      'freeLeft': 5,
      'issuedAt': '2026-11-27T09:00:00Z',
      'usage': {'used': 2, 'limit': 2, 'resetsAt': '2026-11-30T18:30:00Z', 'canUpgrade': true},
      'businessName': 'The Banyan Retreat',
      'assetsVersion': 3,
    });
    expect(r.display, 'Q-0042');
    expect(r.usage.full, isTrue);
    expect(r.freeLeft, 5);
    const refused = OwnerRefused<void>(
      type: 'QuotationMonthLimit',
      statusCode: 409,
      data: {'key': 'StayQuotationsPerMonth', 'limit': 2, 'used': 7, 'canUpgrade': true, 'resetsAt': '2026-11-30T18:30:00Z'},
    );
    final l = QuoteLimitInfo.of(refused)!;
    expect(l.limit, 2);
    expect(l.used, 7);
    expect(l.canUpgrade, isTrue);
    expect(QuoteLimitInfo.of(const OwnerRefused<void>(type: 'Other', statusCode: 409)), isNull);
  });

  test('validation field map uses the request field names', () {
    const r = OwnerRefused<void>(type: 'ValidationError', statusCode: 400, data: {'Gstin': ['Enter a valid GSTIN'], 'bank.AccountNo': 'Bad'});
    expect(QuoteFieldErrors.of(r), {'gstin': 'Enter a valid GSTIN', 'accountNo': 'Bad'});
  });

  test('IST month and storage names', () {
    expect(QuoteTime.sameIstMonth(DateTime.utc(2026, 11, 30, 18, 29), DateTime.utc(2026, 11, 1)), isTrue);
    expect(QuoteTime.sameIstMonth(DateTime.utc(2026, 11, 30, 18, 31), DateTime.utc(2026, 11, 15)), isFalse);
    expect(QuoteStorageNames.indexBox('u1'), 'quote_index_u1');
    expect(QuoteStorageNames.cacheBox('u1'), 'quote_cache_u1');
    expect(QuoteStorageNames.bankKey('u1'), 'quote_bank_u1');
    expect(QuoteStorageNames.imageFile(QuoteImageKind.signature, 4), 'signature_4.jpg');
  });
}
