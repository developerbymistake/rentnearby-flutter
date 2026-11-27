import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../config/app_routes.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../utils/app_toast.dart';
import '../../../owner_core/data/owner_result.dart';
import '../../strings/stay_quote_setup_strings.dart';
import '../../strings/stay_quote_terms_strings.dart';
import '../data/quote_api.dart';
import '../data/quote_asset_store.dart';
import '../data/quote_models.dart';
import '../widgets/quote_terms_sheet.dart';

typedef QuoteTermsPrompt = Future<bool> Function(BuildContext context, QuoteHubController hub);
typedef QuoteBusinessOpener = Future<bool> Function();

// The one quotation controller kept for the session (ARCHITECTURE 10.4): hub, cache, terms and the first-open chain.
class QuoteHubController extends GetxController {
  QuoteHubController({
    QuoteApi? api,
    QuoteAssetStore? store,
    String? Function()? userId,
    DateTime Function()? clock,
    Future<String> Function()? appVersion,
    QuoteTermsPrompt? termsPrompt,
    QuoteBusinessOpener? openBusiness,
    void Function(String message)? tell,
  })  : api = api ?? const QuoteApi(),
        _store = store,
        _userId = userId ?? _authUserId,
        _clock = clock ?? DateTime.now,
        _appVersion = appVersion ?? _packageVersion,
        _termsPrompt = termsPrompt ?? QuoteTermsSheet.ask,
        _openBusiness = openBusiness ?? _openBusinessRoute,
        _tell = tell ?? AppToast.info;

  static QuoteHubController ensure() => Get.isRegistered<QuoteHubController>() ? Get.find<QuoteHubController>() : Get.put(QuoteHubController());

  static QuoteHubController? get maybe => Get.isRegistered<QuoteHubController>() ? Get.find<QuoteHubController>() : null;

  final QuoteApi api;
  QuoteAssetStore? _store;
  final String? Function() _userId;
  final DateTime Function() _clock;
  final Future<String> Function() _appVersion;
  final QuoteTermsPrompt _termsPrompt;
  final QuoteBusinessOpener _openBusiness;
  final void Function(String message) _tell;

  final hub = Rxn<QuoteHub>();
  final loading = false.obs;
  final offline = false.obs;
  final fromCache = false.obs;
  final accepting = false.obs;

  String? _etag;
  DateTime? _savedAt;
  Future<bool>? _loadFlight;
  Future<bool>? _readyFlight;

  QuoteAssetStore get store => _store ??= QuoteAssetStore(api: api);

  String? get userId => _userId();

  static String? _authUserId() => Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null;

  static Future<String> _packageVersion() async {
    try {
      return (await PackageInfo.fromPlatform().timeout(const Duration(seconds: 2))).version;
    } catch (_) {
      return '';
    }
  }

  static Future<bool> _openBusinessRoute() async =>
      await Get.toNamed<dynamic>(AppRoutes.stayQuotationBusiness, arguments: const {'firstRun': true}) == true;

  bool get termsAccepted => hub.value?.terms.accepted ?? false;

  // A cached count from an older month (or past its reset) is never shown (Q17).
  bool get _countFresh {
    final h = hub.value;
    if (h == null) return false;
    final now = _clock();
    final resets = h.usage.resetsAt;
    if (resets != null && !now.isBefore(resets)) return false;
    final saved = _savedAt;
    return !fromCache.value || saved == null || QuoteTime.sameIstMonth(saved, now);
  }

  QuoteUsage? get usage => _countFresh ? hub.value?.usage : null;

  QuoteNext? get next => _countFresh ? hub.value?.next : null;

  Future<bool> load({bool force = false}) => _loadFlight ??= _load(force).whenComplete(() => _loadFlight = null);

  Future<bool> _load(bool force) async {
    final uid = userId;
    if (uid == null) return false;
    if (hub.value == null) {
      final cached = await store.readHub(uid);
      if (cached != null && hub.value == null) {
        hub.value = cached.hub;
        _etag = cached.etag;
        _savedAt = cached.savedAt;
        fromCache.value = true;
      }
    }
    loading.value = true;
    try {
      final r = await api.hub(etag: force || hub.value == null ? null : _etag);
      if (uid != userId) return false;
      switch (r) {
        case OwnerOk<QuoteHubResponse>(:final value):
          offline.value = false;
          if (value.notModified && hub.value != null) {
            _etag = value.etag ?? _etag;
            _markFresh(uid);
            return true;
          }
          final h = value.hub;
          if (h == null) return false;
          _etag = value.etag;
          _set(uid, h);
          return true;
        case OwnerOffline<QuoteHubResponse>():
          offline.value = true;
          return hub.value != null;
        case OwnerRefused<QuoteHubResponse>(:final type):
          offline.value = false;
          if (type == QuoteErrorTypes.stayNotFound || type == QuoteErrorTypes.roleMismatch) hub.value = null;
          return false;
        case OwnerFailed<QuoteHubResponse>():
          return false;
      }
    } finally {
      loading.value = false;
    }
  }

  void _set(String uid, QuoteHub h) {
    hub.value = h;
    fromCache.value = false;
    _savedAt = _clock();
    unawaited(store.writeHub(uid, h, etag: _etag).catchError((_) {}));
  }

  void _markFresh(String uid) {
    final h = hub.value;
    if (h != null) _set(uid, h);
  }

  void _update(QuoteHub h) {
    final uid = userId;
    if (uid == null) return;
    hub.value = h;
    _etag = null;
    unawaited(store.writeHub(uid, h).catchError((_) {}));
  }

  // One straight first-time path (ARCHITECTURE 10.3); false = leave the feature.
  Future<bool> ensureReady(BuildContext context, {int? appTemplateVersion}) =>
      _readyFlight ??= _ready(context, appTemplateVersion).whenComplete(() => _readyFlight = null);

  Future<bool> _ready(BuildContext context, int? appTemplateVersion) async {
    if (hub.value == null || fromCache.value) await load();
    final h = hub.value;
    if (h == null) {
      _tell(offline.value ? QuoteSetupStrings.connectOnce : QuoteSetupStrings.couldNotLoad);
      return false;
    }
    if (!h.stay.approved) {
      _tell(QuoteSetupStrings.notApproved);
      return false;
    }
    if (appTemplateVersion != null && appTemplateVersion < h.minTemplateVersion) {
      _tell(QuoteSetupStrings.updateApp);
      return false;
    }
    if (!h.terms.accepted) {
      if (offline.value) {
        _tell(QuoteSetupStrings.connectOnce);
        return false;
      }
      if (h.terms.currentVersion != QuoteTermsStrings.version) {
        _tell(QuoteSetupStrings.updateApp);
        return false;
      }
      if (!context.mounted || !await _termsPrompt(context, this)) return false;
      if (hub.value?.profile == null && !await _openBusiness()) return false;
    }
    return hub.value?.terms.accepted ?? false;
  }

  // Called by the terms sheet; only a 200 lets the owner in.
  Future<bool> acceptTerms() async {
    if (accepting.value) return false;
    accepting.value = true;
    try {
      final r = await api.acceptTerms(version: QuoteTermsStrings.version, appVersion: await _appVersion());
      switch (r) {
        case OwnerOk<QuoteTermsAccepted>(:final value):
          final h = hub.value;
          if (h != null) {
            _update(h.copyWith(
              terms: QuoteTermsState(currentVersion: h.terms.currentVersion, acceptedVersion: value.acceptedVersion, acceptedAt: value.acceptedAt ?? _clock()),
            ));
          }
          return termsAccepted;
        case OwnerRefused<QuoteTermsAccepted>(:final type, :final message):
          _tell(type == QuoteErrorTypes.termsVersionUnknown ? QuoteSetupStrings.updateApp : (message ?? QuoteSetupStrings.couldNotSave));
          return false;
        case OwnerOffline<QuoteTermsAccepted>():
          _tell(QuoteSetupStrings.connectOnce);
          return false;
        case OwnerFailed<QuoteTermsAccepted>():
          _tell(QuoteSetupStrings.couldNotSave);
          return false;
      }
    } finally {
      accepting.value = false;
    }
  }

  void applyProfile(QuoteProfile profile, {bool? bankUnreadable}) {
    final h = hub.value;
    if (h != null) _update(h.copyWith(profile: profile, bankUnreadable: bankUnreadable ?? (profile.bank.has ? false : h.bankUnreadable)));
  }

  void applyImage(QuoteImageKind kind, {required bool has, required int assetsVersion}) {
    final h = hub.value;
    final p = h?.profile ?? const QuoteProfile();
    if (h != null) _update(h.copyWith(profile: p.withImage(kind, has: has, assetsVersion: assetsVersion)));
  }

  void applyPendingName(String? pendingName) {
    final h = hub.value;
    if (h != null) _update(h.copyWith(stay: h.stay.withPendingName(pendingName)));
  }

  // After every 200 of /reserve: the fresh count, and a hub reload when the images changed elsewhere.
  void applyReserve(QuoteReserveResult r) {
    final h = hub.value;
    if (h == null) return;
    final next = r.kind == QuoteKind.proforma
        ? QuoteNext(quotation: h.next.quotation, proforma: r.number >= h.next.proforma ? r.number + 1 : h.next.proforma)
        : QuoteNext(quotation: r.number >= h.next.quotation ? r.number + 1 : h.next.quotation, proforma: h.next.proforma);
    _update(h.copyWith(usage: r.usage, next: next));
    fromCache.value = false;
    _savedAt = _clock();
    if (r.assetsVersion != (h.profile?.assetsVersion ?? 0)) unawaited(load(force: true));
  }
}
