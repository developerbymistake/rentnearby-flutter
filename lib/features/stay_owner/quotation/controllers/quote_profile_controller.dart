import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../owner_core/data/owner_result.dart';
import '../../../stay/setup/stay_registration_validators.dart';
import '../../../trip/trip_constants.dart';
import '../../strings/stay_quote_setup_strings.dart';
import '../data/quote_models.dart';
import 'quote_hub_controller.dart';

// Client rules mirror QuoteRules on the server; the server stays the judge.
abstract final class QuoteProfileRules {
  static const sloganMax = 80;
  static const addressMax = 240;
  static const addressMaxLines = 4;
  static const phoneMax = 20;
  static const emailMax = 120;
  static const termsMax = 1200;
  static const cancellationMax = 800;
  static const bankTextMax = 60;
  static const nameMin = 2;
  static const nameMax = 80;
  static const noteMax = 200;

  static final phone = RegExp(r'^\+?[0-9][0-9 ()-]{5,19}$');
  static final email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final account = RegExp(r'^\d{9,18}$');
  static final ifsc = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
  static final _hidden = RegExp('[​-‏‪-‮⁦-⁩﻿]');
  static final _control = RegExp('[\u0000-\u0009\u000B-\u001F\u007F]');

  static String clean(String v, {bool multiLine = false}) {
    var s = v.replaceAll(_hidden, '').replaceAll('\r', '');
    s = multiLine ? s.replaceAll(_control, '') : s.replaceAll('\n', ' ').replaceAll(_control, '');
    return s.trim();
  }

  static String? gstin(String v) => v.isEmpty || StayRegistrationValidators.isValidGstin(v) ? null : QuoteSetupStrings.gstinInvalid;

  static String? upi(String v) => v.isEmpty || TripConstants.upiPattern.hasMatch(v) ? null : QuoteSetupStrings.upiInvalid;

  static String? bankError(QuoteBank b) {
    if (!b.hasAccount && b.holder.isEmpty && b.ifsc.isEmpty && b.bank.isEmpty && b.branch.isEmpty) return null;
    if (b.holder.isEmpty || b.accountNo.isEmpty || b.ifsc.isEmpty || b.bank.isEmpty) return QuoteSetupStrings.bankFieldsNeeded;
    if (!account.hasMatch(b.accountNo)) return QuoteSetupStrings.accountInvalid;
    if (!ifsc.hasMatch(b.ifsc)) return QuoteSetupStrings.ifscInvalid;
    if (b.holder.length > bankTextMax || b.bank.length > bankTextMax || b.branch.length > bankTextMax) return QuoteSetupStrings.tooLong;
    return null;
  }
}

enum QuoteSaveOutcome { saved, invalid, failed }

// Business details form (mock Q2): plain fields, the full bank block and the name change request.
class QuoteProfileController extends GetxController {
  QuoteProfileController({required this.hub});

  final QuoteHubController hub;

  final slogan = TextEditingController();
  final address = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final gstin = TextEditingController();
  final upi = TextEditingController();
  final terms = TextEditingController();
  final cancellation = TextEditingController();

  final errors = <String, String>{}.obs;
  final saving = false.obs;
  final bankLoading = false.obs;
  final bankReady = false.obs;
  final bank = Rx<QuoteBank>(QuoteBank.empty);
  final sendingName = false.obs;

  QuoteBank _savedBank = QuoteBank.empty;
  bool _bankTouched = false;

  bool get bankStorage => hub.hub.value?.bankStorage ?? true;

  void fill() {
    final h = hub.hub.value;
    final p = h?.profile;
    final d = h?.defaults ?? const QuoteDefaults();
    slogan.text = p?.slogan ?? '';
    address.text = p?.address ?? d.address ?? '';
    phone.text = p?.phone ?? d.phone ?? '';
    email.text = p?.email ?? '';
    gstin.text = p?.gstin ?? '';
    terms.text = p?.termsText ?? '';
    cancellation.text = p?.cancellationText ?? '';
    final summary = p?.bank ?? QuoteBankSummary.none;
    if (p == null) {
      upi.text = d.upi ?? '';
      bank.value = QuoteBank(upi: upi.text);
      _savedBank = QuoteBank.empty;
      bankReady.value = true;
    } else if (!summary.has) {
      bankReady.value = true;
    }
  }

  // The full block only when one is saved: secure copy first, else GET /profile/bank.
  Future<void> loadBank() async {
    final h = hub.hub.value;
    final p = h?.profile;
    final uid = hub.userId;
    if (p == null || !p.bank.has || uid == null || !bankStorage) return;
    bankLoading.value = true;
    try {
      final r = await hub.store.bank(uid, stamp: p.updatedAt);
      if (r is OwnerOk<QuoteBank?>) {
        final b = r.value ?? QuoteBank.empty;
        _savedBank = b;
        if (!_bankTouched) {
          bank.value = b;
          upi.text = b.upi;
        }
        bankReady.value = true;
      }
    } finally {
      bankLoading.value = false;
    }
  }

  void setBankAccount(QuoteBank account) {
    _bankTouched = true;
    bank.value = QuoteBank(holder: account.holder, accountNo: account.accountNo, ifsc: account.ifsc, bank: account.bank, branch: account.branch, upi: bank.value.upi);
  }

  void removeBankAccount() {
    _bankTouched = true;
    bank.value = bank.value.withoutAccount();
  }

  String? _limit(String value, int max) => value.length > max ? QuoteSetupStrings.tooLong : null;

  Map<String, String> validate() {
    final out = <String, String>{};
    void put(String key, String? e) {
      if (e != null) out[key] = e;
    }

    final a = QuoteProfileRules.clean(address.text, multiLine: true);
    put('slogan', _limit(QuoteProfileRules.clean(slogan.text), QuoteProfileRules.sloganMax));
    put('address', _limit(a, QuoteProfileRules.addressMax) ?? ('\n'.allMatches(a).length >= QuoteProfileRules.addressMaxLines ? QuoteSetupStrings.tooLong : null));
    final ph = QuoteProfileRules.clean(phone.text);
    put('phone', ph.isEmpty || QuoteProfileRules.phone.hasMatch(ph) ? null : QuoteSetupStrings.phoneInvalid);
    final em = QuoteProfileRules.clean(email.text);
    put('email', em.isEmpty ? null : (em.length > QuoteProfileRules.emailMax || !QuoteProfileRules.email.hasMatch(em) ? QuoteSetupStrings.emailInvalid : null));
    put('gstin', QuoteProfileRules.gstin(StayRegistrationValidators.normalizeGstin(gstin.text)));
    put('upi', bankStorage ? QuoteProfileRules.upi(upi.text.trim()) : null);
    put('termsText', _limit(QuoteProfileRules.clean(terms.text, multiLine: true), QuoteProfileRules.termsMax));
    put('cancellationText', _limit(QuoteProfileRules.clean(cancellation.text, multiLine: true), QuoteProfileRules.cancellationMax));
    if (bankStorage) put('bank', QuoteProfileRules.bankError(bank.value));
    return out;
  }

  QuoteBank get _bankToSend => bank.value.withUpi(upi.text.trim());

  QuoteProfileInput input() {
    var mode = QuoteBankMode.keep;
    QuoteBank? block;
    if (bankStorage && bankReady.value) {
      final next = _bankToSend;
      if (next != _savedBank) {
        mode = next.isEmpty ? QuoteBankMode.clear : QuoteBankMode.set;
        block = next.isEmpty ? null : next;
      }
    }
    return QuoteProfileInput(
      slogan: QuoteProfileRules.clean(slogan.text),
      address: QuoteProfileRules.clean(address.text, multiLine: true),
      phone: QuoteProfileRules.clean(phone.text),
      email: QuoteProfileRules.clean(email.text),
      gstin: StayRegistrationValidators.normalizeGstin(gstin.text),
      termsText: QuoteProfileRules.clean(terms.text, multiLine: true),
      cancellationText: QuoteProfileRules.clean(cancellation.text, multiLine: true),
      bankMode: mode,
      bank: block,
    );
  }

  Future<QuoteSaveOutcome> save({void Function(String message)? tell}) async {
    if (saving.value) return QuoteSaveOutcome.failed;
    final local = validate();
    errors.assignAll(local);
    if (local.isNotEmpty) return QuoteSaveOutcome.invalid;
    saving.value = true;
    try {
      final body = input();
      final r = await hub.api.saveProfile(body);
      switch (r) {
        case OwnerOk<QuoteProfile>(:final value):
          final uid = hub.userId;
          if (uid != null && body.bankMode != QuoteBankMode.keep) {
            final saved = body.bankMode == QuoteBankMode.clear ? null : body.bank;
            await hub.store.writeBank(uid, saved, stamp: value.updatedAt).catchError((_) {});
            _savedBank = saved ?? QuoteBank.empty;
          }
          hub.applyProfile(value);
          return QuoteSaveOutcome.saved;
        case final OwnerRefused<QuoteProfile> refused:
          final type = refused.type;
          final message = refused.message;
          if (type == QuoteErrorTypes.gstinMismatch) {
            errors.assignAll({'gstin': QuoteSetupStrings.gstinMismatch});
            return QuoteSaveOutcome.invalid;
          }
          final fields = QuoteFieldErrors.of(refused);
          if (fields.isNotEmpty) {
            errors.assignAll(fields);
            return QuoteSaveOutcome.invalid;
          }
          tell?.call(refused.rateLimited ? QuoteSetupStrings.tooMany : (message ?? QuoteSetupStrings.couldNotSave));
          return QuoteSaveOutcome.failed;
        case OwnerOffline<QuoteProfile>():
          tell?.call(QuoteSetupStrings.offline);
          return QuoteSaveOutcome.failed;
        case OwnerFailed<QuoteProfile>():
          final bankDown = body.bankMode == QuoteBankMode.set;
          tell?.call(bankDown ? QuoteSetupStrings.bankOff : QuoteSetupStrings.couldNotSave);
          return QuoteSaveOutcome.failed;
      }
    } finally {
      saving.value = false;
    }
  }

  static String? nameError(String current, String value) {
    final v = QuoteProfileRules.clean(value);
    if (v.length < QuoteProfileRules.nameMin || v.length > QuoteProfileRules.nameMax) return QuoteSetupStrings.nameRule;
    if (v == current.trim()) return QuoteSetupStrings.nameSame;
    return null;
  }

  Future<bool> requestName(String name, String note, {void Function(String message)? tell}) async {
    if (sendingName.value) return false;
    sendingName.value = true;
    try {
      final r = await hub.api.nameChange(name: QuoteProfileRules.clean(name), note: QuoteProfileRules.clean(note, multiLine: true));
      switch (r) {
        case OwnerOk<String?>(:final value):
          hub.applyPendingName(value ?? QuoteProfileRules.clean(name));
          tell?.call(QuoteSetupStrings.requestSent);
          return true;
        case final OwnerRefused<String?> refused:
          tell?.call(refused.rateLimited ? QuoteSetupStrings.requestLimit : (refused.message ?? QuoteSetupStrings.couldNotSave));
          return false;
        case OwnerOffline<String?>():
          tell?.call(QuoteSetupStrings.offline);
          return false;
        case OwnerFailed<String?>():
          tell?.call(QuoteSetupStrings.couldNotSave);
          return false;
      }
    } finally {
      sendingName.value = false;
    }
  }

  @override
  void onClose() {
    for (final c in [slogan, address, phone, email, gstin, upi, terms, cancellation]) {
      c.dispose();
    }
    super.onClose();
  }
}
