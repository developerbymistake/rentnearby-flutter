import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../controllers/plan_controller.dart';
import '../../../owner_core/data/owner_result.dart';
import '../controllers/quote_hub_controller.dart';
import '../data/quote_models.dart';
import 'quote_business.dart';

sealed class QuoteReserveOutcome {
  const QuoteReserveOutcome();
}

class QuoteReserved extends QuoteReserveOutcome {
  const QuoteReserved(this.result);
  final QuoteReserveResult result;
}

class QuoteReserveRefused extends QuoteReserveOutcome {
  const QuoteReserveRefused(this.refusal);
  final OwnerRefused<dynamic> refusal;
}

class QuoteReserveOffline extends QuoteReserveOutcome {
  const QuoteReserveOffline();
}

class QuoteReserveFailed extends QuoteReserveOutcome {
  const QuoteReserveFailed([this.message]);
  final String? message;
}

// Everything the form, preview and download need from the hub (APP-A), read in one place.
abstract class QuoteSource {
  String? get userId;
  String get businessName;
  QuoteBusiness? business({QuoteBank? bank});
  QuoteUsage? get usage;
  // The month limit /plans/me says now (null while the plan is not loaded); the local pre-check runs only when the hub agrees.
  int? get planLimit;
  // Business details hold a bank block (the secure copy may still be missing on this phone).
  bool get bankSaved;
  bool get offline;
  Future<bool> ensureReady(BuildContext context, {int? appTemplateVersion});
  Future<QuoteBank?> bank();
  Future<bool> hasImage(QuoteImageKind kind, int version);
  Future<void> ensureImages(int assetsVersion);
  Future<QuoteReserveOutcome> reserve(String documentId, QuoteKind kind);
  // Forced hub reload (after a limit sheet: the owner may have bought Plus).
  Future<void> refreshUsage();
  // Calls onChange whenever the hub (Business details, images, numbers) changes; returns the stop function.
  void Function() watchBusiness(void Function() onChange);
}

class AppQuoteSource implements QuoteSource {
  AppQuoteSource({QuoteHubController? hub}) : _hub = hub;

  final QuoteHubController? _hub;
  QuoteHubController get hub => _hub ?? QuoteHubController.ensure();

  static QuoteBankLines lines(QuoteBank? b) => b == null
      ? const QuoteBankLines()
      : QuoteBankLines(holder: b.holder, accountNo: b.accountNo, ifsc: b.ifsc, bank: b.bank, branch: b.branch, upi: b.upi);

  static QuoteBusiness? fromHub(QuoteHub? h, {QuoteBank? bank, QuoteNext? next, QuoteUsage? usage}) {
    if (h == null) return null;
    final p = h.profile;
    final n = next ?? h.next;
    return QuoteBusiness(
      name: h.stay.name,
      approved: h.stay.approved,
      slogan: p?.slogan ?? '',
      address: p?.address ?? h.defaults.address ?? '',
      phone: p?.phone ?? h.defaults.phone ?? '',
      email: p?.email ?? '',
      gstin: p?.gstin ?? '',
      preparedBy: h.preparedBy ?? '',
      termsText: p?.termsText ?? '',
      cancellationText: p?.cancellationText ?? '',
      hasLogo: p?.hasLogo ?? false,
      hasSignature: p?.hasSignature ?? false,
      assetsVersion: p?.assetsVersion ?? 0,
      bank: lines(bank),
      nextQuotation: n.quotation,
      nextProforma: n.proforma,
      previewWatermark: h.previewWatermark,
      minTemplateVersion: h.minTemplateVersion,
      usage: usage,
    );
  }

  @override
  String? get userId => hub.userId;

  @override
  String get businessName => hub.hub.value?.stay.name ?? '';

  @override
  QuoteBusiness? business({QuoteBank? bank}) => fromHub(hub.hub.value, bank: bank, next: hub.next, usage: hub.usage);

  @override
  QuoteUsage? get usage => hub.usage;

  @override
  int? get planLimit {
    if (!Get.isRegistered<PlanController>()) return null;
    final plans = Get.find<PlanController>();
    return plans.loaded.value ? plans.myPlan.value.limits.quotationsPerMonth : null;
  }

  @override
  bool get bankSaved => hub.hub.value?.profile?.bank.has ?? false;

  @override
  bool get offline => hub.offline.value;

  @override
  Future<bool> ensureReady(BuildContext context, {int? appTemplateVersion}) => hub.ensureReady(context, appTemplateVersion: appTemplateVersion);

  @override
  Future<QuoteBank?> bank() async {
    final uid = userId;
    if (uid == null) return null;
    final h = hub.hub.value;
    if (h == null || h.profile?.bank.has != true) return null;
    final r = await hub.store.bank(uid, stamp: h.profile?.updatedAt);
    return r.valueOrNull;
  }

  @override
  Future<bool> hasImage(QuoteImageKind kind, int version) async {
    final uid = userId;
    if (uid == null || version <= 0) return false;
    return await hub.store.imagePath(uid, kind, version) != null;
  }

  @override
  Future<void> ensureImages(int assetsVersion) => hub.fetchMissingImages(assetsVersion: assetsVersion);

  @override
  Future<QuoteReserveOutcome> reserve(String documentId, QuoteKind kind) async {
    final r = await hub.api.reserve(documentId: documentId, kind: kind);
    switch (r) {
      case OwnerOk<QuoteReserveResult>(:final value):
        hub.applyReserve(value);
        return QuoteReserved(value);
      case OwnerRefused<QuoteReserveResult>():
        final info = QuoteLimitInfo.of(r);
        if (info != null) {
          hub.applyUsage(QuoteUsage(used: info.used, limit: info.limit, resetsAt: info.resetsAt, canUpgrade: info.canUpgrade));
          if (Get.isRegistered<PlanController>()) Get.find<PlanController>().invalidate().ignore();
        }
        return QuoteReserveRefused(r);
      case OwnerOffline<QuoteReserveResult>():
        return const QuoteReserveOffline();
      default:
        return QuoteReserveFailed(r is OwnerFailed<QuoteReserveResult> ? r.message : null);
    }
  }

  @override
  Future<void> refreshUsage() async {
    await hub.load(force: true);
  }

  @override
  void Function() watchBusiness(void Function() onChange) {
    final w = ever<QuoteHub?>(hub.hub, (_) => onChange());
    return w.dispose;
  }
}
