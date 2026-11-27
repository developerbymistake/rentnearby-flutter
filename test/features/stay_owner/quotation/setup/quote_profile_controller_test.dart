import 'dart:convert';

import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/stay_owner/quotation/controllers/quote_hub_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/controllers/quote_profile_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_asset_store.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:bakhli/features/stay_owner/strings/stay_quote_setup_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quote_setup_fakes.dart';

class _T {
  _T({QuoteHub? hub}) {
    store = QuoteAssetStore(engine: FakeEngine(), api: api, secure: secure, boxes: MemBoxes());
    this.hub = QuoteHubController(api: api, store: store, userId: () => 'u1', tell: told.add);
    if (hub != null) api.hubResult = OwnerOk(QuoteHubResponse(notModified: false, hub: hub));
    form = QuoteProfileController(hub: this.hub);
  }

  final api = FakeQuoteApi();
  final secure = MemKeyValue();
  final told = <String>[];
  late final QuoteAssetStore store;
  late final QuoteHubController hub;
  late final QuoteProfileController form;

  Future<void> open() async {
    await hub.load();
    form.fill();
    await form.loadBank();
  }
}

void main() {
  test('first save is pre-filled from the stay defaults', () async {
    final t = _T(hub: hubOf(profile: false));
    await t.open();
    expect(t.form.address.text, 'Stay address');
    expect(t.form.phone.text, '9837041122');
    expect(t.form.upi.text, 'banyan@sbi');
    expect(t.form.slogan.text, isEmpty);
    expect(t.api.calls, isNot(contains('bank')));
    final body = t.form.input();
    expect(body.bankMode, QuoteBankMode.set);
    expect(body.bank!.upi, 'banyan@sbi');
  });

  test('saved profile: full bank comes from GET /profile/bank once, then from secure storage', () async {
    final t = _T();
    await t.open();
    expect(t.api.calls.where((c) => c == 'bank'), hasLength(1));
    expect(t.form.upi.text, 'banyan@sbi');
    expect(t.form.bankReady.value, isTrue);
    expect(t.secure.values.keys.toList(), ['quote_bank_u1']);

    final again = QuoteProfileController(hub: t.hub);
    again.fill();
    await again.loadBank();
    expect(t.api.calls.where((c) => c == 'bank'), hasLength(1));
    expect(again.bank.value, sampleBank);
  });

  test('nothing changed in bank = Keep; UPI edited = Set with the full block; all removed = Clear', () async {
    final t = _T();
    await t.open();
    expect(t.form.input().bankMode, QuoteBankMode.keep);
    t.form.upi.text = 'newbanyan@sbi';
    final set = t.form.input();
    expect(set.bankMode, QuoteBankMode.set);
    expect(set.bank!.accountNo, '123456784521');
    expect(set.bank!.upi, 'newbanyan@sbi');
    t.form.removeBankAccount();
    t.form.upi.text = '';
    expect(t.form.input().bankMode, QuoteBankMode.clear);
  });

  test('bank not yet readable: the save keeps the bank as it is', () async {
    final t = _T();
    t.api.bankResult = const OwnerOffline();
    await t.open();
    expect(t.form.bankReady.value, isFalse);
    t.form.upi.text = 'x@y';
    expect(t.form.input().bankMode, QuoteBankMode.keep);
  });

  test('client rules: GSTIN check digit, phone, email, lengths, bank block', () async {
    final t = _T();
    await t.open();
    t.form.gstin.text = '05ABCDE1234F1Z5';
    t.form.phone.text = 'abc';
    t.form.email.text = 'no-at';
    t.form.slogan.text = 'x' * (QuoteProfileRules.sloganMax + 1);
    t.form.upi.text = 'bad upi';
    final e = t.form.validate();
    expect(e.keys, containsAll(['gstin', 'phone', 'email', 'slogan', 'upi']));
    expect(QuoteProfileRules.bankError(const QuoteBank(holder: 'A', accountNo: '12', ifsc: 'SBIN0001234', bank: 'B')), QuoteSetupStrings.accountInvalid);
    expect(QuoteProfileRules.bankError(const QuoteBank(holder: 'A', accountNo: '123456789', ifsc: 'SBIN1001234', bank: 'B')), QuoteSetupStrings.ifscInvalid);
    expect(QuoteProfileRules.bankError(const QuoteBank(accountNo: '123456789')), QuoteSetupStrings.bankFieldsNeeded);
    expect(QuoteProfileRules.bankError(const QuoteBank(upi: 'a@b')), isNull);
    expect(QuoteProfileRules.bankError(sampleBank), isNull);
  });

  test('hidden direction marks and control characters are stripped', () {
    expect(QuoteProfileRules.clean('Ab‮c​d\u0007'), 'Abcd');
    expect(QuoteProfileRules.clean('a\nb', multiLine: true), 'a\nb');
    expect(QuoteProfileRules.clean('a\nb'), 'a b');
  });

  test('save sends no business name, stores the bank only in secure storage, updates the hub', () async {
    final t = _T();
    await t.open();
    t.form.upi.text = 'newbanyan@sbi';
    expect(await t.form.save(), QuoteSaveOutcome.saved);
    final body = t.api.bodies.single;
    expect(body.containsKey('name'), isFalse);
    expect(body.containsKey('businessName'), isFalse);
    expect(body['bankMode'], 'Set');
    expect(jsonDecode(t.secure.values['quote_bank_u1']!)['bank']['upi'], 'newbanyan@sbi');
    expect(t.hub.hub.value!.profile!.updatedAt, DateTime.utc(2026, 11, 27, 10));
  });

  test('server GSTIN mismatch and field errors land on the fields', () async {
    final t = _T();
    await t.open();
    t.api.profileResult = const OwnerRefused(type: 'QuoteGstinMismatch', statusCode: 400);
    expect(await t.form.save(), QuoteSaveOutcome.invalid);
    expect(t.form.errors['gstin'], QuoteSetupStrings.gstinMismatch);
    t.api.profileResult = const OwnerRefused(type: 'ValidationError', statusCode: 400, data: {'Phone': ['Enter a valid phone number.']});
    expect(await t.form.save(), QuoteSaveOutcome.invalid);
    expect(t.form.errors['phone'], 'Enter a valid phone number.');
  });

  test('name change: rules, request sent, pending name shown', () async {
    final t = _T();
    await t.open();
    expect(QuoteProfileController.nameError('The Banyan Retreat', 'A'), QuoteSetupStrings.nameRule);
    expect(QuoteProfileController.nameError('The Banyan Retreat', ' The Banyan Retreat '), QuoteSetupStrings.nameSame);
    expect(QuoteProfileController.nameError('The Banyan Retreat', 'The Banyan Riverside Retreat'), isNull);
    final said = <String>[];
    expect(await t.form.requestName('The Banyan Riverside Retreat', 'Registered name changed', tell: said.add), isTrue);
    expect(t.api.bodies.last, {'name': 'The Banyan Riverside Retreat', 'note': 'Registered name changed'});
    expect(t.hub.hub.value!.stay.pendingName, 'The Banyan Riverside Retreat');
    expect(t.hub.hub.value!.stay.name, 'The Banyan Retreat');
    expect(said, [QuoteSetupStrings.requestSent]);
    t.api.nameResult = const OwnerRefused(type: 'RateLimited', statusCode: 429);
    expect(await t.form.requestName('Other Name', '', tell: said.add), isFalse);
    expect(said.last, QuoteSetupStrings.requestLimit);
  });
}
