import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../strings/stay_quote_strings.dart';
import '../data/quote_doc_store.dart';
import '../data/quote_models.dart';
import '../model/quote_business.dart';
import '../model/quote_doc.dart';
import '../model/quote_draft.dart';
import '../model/quote_money.dart';
import '../model/quote_prefill.dart';
import '../model/quote_text_clean.dart';
import '../model/quote_source.dart';
import '../pdf/quote_engine.dart';
import '../pdf/quote_templates.dart';

abstract final class QuoteFieldKeys {
  static const guestName = 'guestName';
  static const dates = 'dates';
  static const validTill = 'validTill';
  static const lines = 'lines';
  static const discount = 'discount';
  static const gst = 'gst';
  static const payments = 'payments';
  static const total = 'total';
}

// One document: fields, lines, live totals, rules of ARCHITECTURE 10.6 and the debounced autosave.
class QuoteFormController extends GetxController {
  QuoteFormController({required QuoteDraft initial, required this.store, required QuoteBusiness business, this.ownerId, String Function()? newId, DateTime Function()? now})
      : draft = initial.obs,
        business = business.obs,
        _newId = newId ?? (() => const Uuid().v4()),
        _now = now ?? DateTime.now;

  static const String tag = 'quote_form';

  static QuoteFormController? get maybe => Get.isRegistered<QuoteFormController>(tag: tag) ? Get.find<QuoteFormController>(tag: tag) : null;

  final Rx<QuoteDraft> draft;
  final Rx<QuoteBusiness> business;
  final QuoteDocStore store;
  final String? ownerId;
  final String Function() _newId;
  final DateTime Function() _now;
  final errors = <String, String>{}.obs;
  final fromEnquiryGuest = RxnString();

  String newId() => _newId();

  static Future<QuoteDocStore> Function(String userId) openStore = (userId) => QuoteDocStore.openFor(userId, QuoteEngine.instance);

  // The one form of the feature; template and preview reuse it, or rebuild it from the saved document.
  static Future<QuoteFormController?> open(Map<String, dynamic> args, QuoteSource source, {DateTime Function()? now}) async {
    final existing = maybe;
    final id = args['documentId'];
    if (existing != null && (id == null || existing.draft.value.documentId == id)) return existing;
    final uid = source.userId;
    if (uid == null) return null;
    final bank = await source.bank();
    final business = source.business(bank: bank);
    if (business == null) return null;
    final store = await openStore(uid);
    final clock = now ?? DateTime.now;
    QuoteDraft? draft;
    if (id is String && id.isNotEmpty) draft = await store.load(id);
    final fresh = draft == null;
    draft ??= blank(const Uuid().v4(), clock(), template: store.index.readTemplate());
    if (fresh && args['kind'] == QuoteKind.proforma.name) draft = draft.copyWith(kind: QuoteKind.proforma);
    final c = QuoteFormController(initial: draft, store: store, business: business, ownerId: uid, now: clock);
    final prefill = QuotePrefill.fromArgs(args);
    if (fresh && prefill != null) c.applyPrefill(prefill);
    if (existing != null) Get.delete<QuoteFormController>(tag: tag, force: true);
    return Get.put(c, tag: tag);
  }

  static QuoteDraft blank(String id, DateTime now, {String? template}) =>
      QuoteDraft.blank(documentId: id, today: now, template: QuoteTemplates.safe(template ?? QuoteTemplates.classic));

  QuoteTotals get totals => QuoteDocBuilder.totals(draft.value, business.value);

  String get numberHint => QuoteDocBuilder.hintDisplay(draft.value, business.value);

  bool get gstAllowed => business.value.hasGstin;

  bool get kindNeedsOwnNumber {
    final d = draft.value;
    final other = d.kind == QuoteKind.quotation ? QuoteKind.proforma : QuoteKind.quotation;
    return d.reservationFor(other) != null && d.reservation == null;
  }

  QuoteDoc doc({String? number, String? businessName, bool? logo, bool? signature}) {
    var b = business.value;
    if (logo != null || signature != null) {
      b = QuoteBusiness(
        name: b.name,
        approved: b.approved,
        slogan: b.slogan,
        address: b.address,
        phone: b.phone,
        email: b.email,
        gstin: b.gstin,
        preparedBy: b.preparedBy,
        termsText: b.termsText,
        cancellationText: b.cancellationText,
        hasLogo: logo ?? b.hasLogo,
        hasSignature: signature ?? b.hasSignature,
        assetsVersion: b.assetsVersion,
        bank: b.bank,
        nextQuotation: b.nextQuotation,
        nextProforma: b.nextProforma,
        previewWatermark: b.previewWatermark,
        minTemplateVersion: b.minTemplateVersion,
        usage: b.usage,
      );
    }
    return QuoteDocBuilder.build(draft.value, b, number: number, businessName: businessName, owner: ownerId);
  }

  void _set(QuoteDraft next) {
    draft.value = next.copyWith(updatedAt: _now());
    if (errors.isNotEmpty) validate(silent: true);
    store.saveLater(draft.value, total: totals.total);
  }

  void setBusiness(QuoteBusiness b) {
    business.value = b;
    if (!b.hasGstin && draft.value.gstBp != 0) _set(draft.value.copyWith(gstBp: 0));
  }

  void setKind(QuoteKind k) {
    if (draft.value.kind == k) return;
    _set(draft.value.copyWith(kind: k));
  }

  void setDate(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final valid = draft.value.validTill.isBefore(day) ? day.add(const Duration(days: QuoteLimits.validDays)) : null;
    _set(draft.value.copyWith(date: day, validTill: valid));
  }

  void setValidTill(DateTime d) => _set(draft.value.copyWith(validTill: DateTime(d.year, d.month, d.day)));

  void setGuestName(String v) => _set(draft.value.copyWith(guestName: QuoteTextClean.cap(v, QuoteLimits.guestName)));
  void setGuestPhone(String v) => _set(draft.value.copyWith(guestPhone: QuoteTextClean.cap(v, QuoteLimits.guestPhone)));
  void setBookedBy(String v) => _set(draft.value.copyWith(bookedBy: QuoteTextClean.cap(v, QuoteLimits.bookedBy)));

  void setDates(DateTime a, DateTime b) {
    final from = DateTime(a.year, a.month, a.day);
    final to = DateTime(b.year, b.month, b.day);
    final old = draft.value.nights;
    var next = draft.value.copyWith(checkIn: from, checkOut: to);
    final n = next.nights;
    if (n > 0) {
      next = next.copyWith(lines: [
        for (final l in next.lines) (old > 0 && l.nights == old) || (old == 0 && l.nights == 1) ? l.copyWith(nights: n.clamp(1, QuoteLimits.maxNights)) : l,
      ]);
    }
    _set(next);
  }

  void setAdults(int v) => _set(draft.value.copyWith(adults: v.clamp(1, QuoteLimits.maxPeople)));
  void setKids(int v) => _set(draft.value.copyWith(kids: v.clamp(0, QuoteLimits.maxPeople)));
  void setRooms(int v) => _set(draft.value.copyWith(rooms: v.clamp(0, QuoteLimits.maxPeople)));

  void setMeal(QuoteMeal m) => _set(draft.value.copyWith(meal: draft.value.meal == m ? QuoteMeal.none : m));

  int get defaultNights {
    final n = draft.value.nights;
    return n > 0 ? n.clamp(1, QuoteLimits.maxNights) : 1;
  }

  bool get canAddLine => draft.value.lines.length < QuoteLimits.maxLines;

  static String? lineError({required String description, required int rate, required int qty, required int nights}) {
    if (description.trim().isEmpty) return StayQuoteStrings.errDescription;
    if (rate < 0 || rate > QuoteMoney.maxRate) return StayQuoteStrings.errRate;
    if (qty < 1 || qty > QuoteLimits.maxQty || nights < 1 || nights > QuoteLimits.maxNights) return StayQuoteStrings.errRate;
    return null;
  }

  bool addLine({required String description, required int rate, required int qty, required int nights}) {
    if (!canAddLine || lineError(description: description, rate: rate, qty: qty, nights: nights) != null) return false;
    final line = QuoteLine(id: _newId(), description: QuoteTextClean.line(description, QuoteLimits.description), rate: rate, qty: qty, nights: nights);
    _set(draft.value.copyWith(lines: [...draft.value.lines, line]));
    return true;
  }

  bool updateLine(String id, {required String description, required int rate, required int qty, required int nights}) {
    if (lineError(description: description, rate: rate, qty: qty, nights: nights) != null) return false;
    _set(draft.value.copyWith(lines: [
      for (final l in draft.value.lines)
        l.id == id ? l.copyWith(description: QuoteTextClean.line(description, QuoteLimits.description), rate: rate, qty: qty, nights: nights) : l,
    ]));
    return true;
  }

  void removeLine(String id) => _set(draft.value.copyWith(lines: draft.value.lines.where((l) => l.id != id).toList()));

  void setDiscount(int v) => _set(draft.value.copyWith(discount: v < 0 ? 0 : v));

  // Returns false when the text is not a valid rate (the field shows the error, the old value stays).
  bool setGstText(String text) {
    final bp = QuoteMoney.parseBp(text);
    if (bp == null) {
      errors[QuoteFieldKeys.gst] = StayQuoteStrings.errGst;
      return false;
    }
    errors.remove(QuoteFieldKeys.gst);
    _set(draft.value.copyWith(gstBp: gstAllowed ? bp : 0));
    return true;
  }

  static String payLabel(QuotePayKind k) => switch (k) {
        QuotePayKind.advance => StayQuoteStrings.payAdvanceLabel,
        QuotePayKind.bank => StayQuoteStrings.payBankLabel,
        QuotePayKind.cash => StayQuoteStrings.payCashLabel,
        QuotePayKind.upi => StayQuoteStrings.payUpiLabel,
      };

  bool get canAddPayment => draft.value.payments.length < QuoteLimits.maxPayments;

  QuotePayment? addPayment(QuotePayKind kind) {
    if (!canAddPayment) return null;
    final now = _now();
    final p = QuotePayment(id: _newId(), kind: kind, label: payLabel(kind), date: DateTime(now.year, now.month, now.day), amount: 0);
    _set(draft.value.copyWith(payments: [...draft.value.payments, p]));
    return p;
  }

  void updatePayment(String id, {String? label, DateTime? date, int? amount}) => _set(draft.value.copyWith(payments: [
        for (final p in draft.value.payments)
          p.id == id ? p.copyWith(label: label == null ? null : QuoteTextClean.line(label, QuoteLimits.payLabel), date: date, amount: amount == null ? null : (amount < 0 ? 0 : amount)) : p,
      ]));

  void removePayment(String id) => _set(draft.value.copyWith(payments: draft.value.payments.where((p) => p.id != id).toList()));

  void setNote(String v) => _set(draft.value.copyWith(note: QuoteTextClean.cap(v, QuoteLimits.note)));

  void setUseSavedTerms(bool on) {
    final d = draft.value;
    final seed = !on && d.termsText.isEmpty ? business.value.termsText : null;
    _set(d.copyWith(useSavedTerms: on, termsText: seed));
  }

  void setUseSavedCancellation(bool on) {
    final d = draft.value;
    final seed = !on && d.cancellationText.isEmpty ? business.value.cancellationText : null;
    _set(d.copyWith(useSavedCancellation: on, cancellationText: seed));
  }

  void setTermsText(String v) => _set(draft.value.copyWith(termsText: QuoteTextClean.cap(v, QuoteLimits.terms)));
  void setCancellationText(String v) => _set(draft.value.copyWith(cancellationText: QuoteTextClean.cap(v, QuoteLimits.cancellation)));

  void setTemplate(String id) {
    final t = QuoteTemplates.safe(id);
    _set(draft.value.copyWith(template: t));
    store.index.writeTemplate(t).ignore();
  }

  void applyPrefill(QuotePrefill p) {
    _set(p.applyTo(draft.value, _newId));
    fromEnquiryGuest.value = p.guestName.isEmpty ? null : p.guestName;
  }

  void applyReservation(QuoteKind k, QuoteReservation r) => _set(draft.value.withReservation(k, r));

  Map<String, String> check() {
    final d = draft.value;
    final t = totals;
    final out = <String, String>{};
    if (QuoteTextClean.line(d.guestName, QuoteLimits.guestName).isEmpty) out[QuoteFieldKeys.guestName] = StayQuoteStrings.errGuest;
    final a = d.checkIn;
    final b = d.checkOut;
    if ((a == null) != (b == null) || (a != null && b != null && !b.isAfter(a))) out[QuoteFieldKeys.dates] = StayQuoteStrings.errDates;
    if (d.validTill.isBefore(d.date)) out[QuoteFieldKeys.validTill] = StayQuoteStrings.errValid;
    if (d.lines.isEmpty) out[QuoteFieldKeys.lines] = StayQuoteStrings.errLines;
    if (d.discount > t.subtotal) out[QuoteFieldKeys.discount] = StayQuoteStrings.errDiscount;
    if (d.gstBp < 0 || d.gstBp > QuoteMoney.maxGstBp) out[QuoteFieldKeys.gst] = StayQuoteStrings.errGst;
    if (d.kind == QuoteKind.proforma && t.received > t.total) out[QuoteFieldKeys.payments] = StayQuoteStrings.errReceived;
    if (t.tooLarge) out[QuoteFieldKeys.total] = StayQuoteStrings.errTotal;
    return out;
  }

  bool validate({bool silent = false}) {
    final out = check();
    errors
      ..clear()
      ..addAll(out);
    return out.isEmpty;
  }

  Future<void> flush() => store.flush();

  Future<void> saveNow() => store.saveNow(draft.value, total: totals.total);

  @override
  void onClose() {
    store.flush().ignore();
    super.onClose();
  }
}
