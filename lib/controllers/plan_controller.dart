import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/my_plan_model.dart';
import '../models/plan_model.dart';
import '../models/plan_purchase_result.dart';
import '../models/store_product.dart';
import '../repositories/plan_repository.dart';
import '../services/billing/billing_gateway.dart';
import '../services/billing/play_billing_gateway.dart';
import '../services/billing/razorpay_gateway.dart';
import '../utils/app_toast.dart';
import '../utils/dio_error_mapper.dart';
import 'listing_controller.dart';
import 'plot_controller.dart';

class _PlayInflight {
  final PlanOrder order;
  final OwnedPurchase? old;
  final done = Completer<BillingEvent?>();

  _PlayInflight(this.order, this.old);

  bool matches(BillingEvent e) {
    final pid = e.productId;
    if (pid == null) return e.kind == BillingEventKind.purchased;
    final old = this.old;
    if (old != null && e.purchaseToken == old.purchaseToken) return false;
    return pid == order.playProductId || (old != null && pid == old.productId);
  }
}

class PlanController extends GetxController {
  final myPlan = const MyPlanModel().obs;
  final catalog = Rxn<PlanCatalogModel>();
  final history = <PurchaseHistoryItem>[].obs;
  final isLoadingPlan = false.obs;
  final isLoadingCatalog = false.obs;
  final isLoadingHistory = false.obs;
  final isPurchasing = false.obs;
  final activePurchase = Rxn<PurchaseStatus>();
  final pollTimedOut = false.obs;
  final planLoadFailed = false.obs;

  final storeState = StoreState.idle.obs;
  final storeProducts = <String, StoreProduct>{}.obs;
  final ownedPurchases = <String, OwnedPurchase>{}.obs;
  final otherAccountProducts = <String>{}.obs;
  final detachedProducts = <String, DateTime?>{}.obs;
  final isRestoring = false.obs;

  bool _polling = false;
  bool _loaded = false;
  int _planSeq = 0;
  int _pollSeq = 0;
  bool _disposed = false;
  Timer? _reloadTimer;
  final _skipOpenIds = <String>{};

  BillingGateway? _gateway;
  StreamSubscription<BillingEvent>? _gatewaySub;
  Future<void>? _gatewayInit;
  RazorpayGateway? _fallbackRazorpay;
  Future<void>? _storeFlight;
  Future<void>? _restoreFlight;
  DateTime? _lastRestoreAt;
  List<OwnedPurchase>? _restoreBatch;
  _PlayInflight? _inflight;
  final _strayTokens = <String>{};

  static const _restoreThrottle = Duration(minutes: 2);
  static const _restoreChunk = 10;
  static const _playLaunchTimeout = Duration(minutes: 10);
  static const _reloadListTypes = {
    'planactivated',
    'planexpired',
    'planonhold',
    'planpaused',
    'planrenewed',
    'plancarryoveractivated',
  };

  PlanRepository get _repo => Get.find<PlanRepository>();

  PlanLimitsModel get limits => myPlan.value.limits;
  bool get paymentEnabled => myPlan.value.paymentEnabled;
  bool get hasPlanFeature => myPlan.value.featureKey != null;
  bool get hasRoomForLive => limits.live < limits.listingLimit;
  bool get isLoaded => _loaded;

  String get paymentProvider => _providerKey(myPlan.value.paymentProvider);
  bool get isPlay => paymentProvider == 'Play';
  bool get hasPlaySubscription => myPlan.value.play != null;

  static String _providerKey(String? p) => p == 'Razorpay' ? 'Razorpay' : 'Play';

  List<PlanModel> get plans => catalog.value?.plansOf(myPlan.value.featureKey) ?? const [];
  PlanModel? get currentPlanModel {
    final id = myPlan.value.planId;
    for (final p in plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    refreshPlan();
  }

  Future<void> refreshPlan({bool force = false}) async {
    if (isLoadingPlan.value && !force) return;
    final seq = ++_planSeq;
    isLoadingPlan.value = true;
    try {
      final me = await _repo.getMe(forceRefresh: force);
      if (seq != _planSeq) return;
      myPlan.value = me;
      _loaded = true;
      planLoadFailed.value = false;
      _syncGateway(me);
      final open = me.openPurchaseId;
      final active = activePurchase.value;
      if (open == null && active != null && active.isOpen && pollTimedOut.value && !_polling && !isPurchasing.value) {
        activePurchase.value = null;
        pollTimedOut.value = false;
      } else if (open != null && !_skipOpenIds.contains(open) && active == null && !_polling) {
        unawaited(resumeOpenPurchase());
      }
    } catch (_) {
      if (seq == _planSeq) planLoadFailed.value = true;
    } finally {
      if (seq == _planSeq) isLoadingPlan.value = false;
    }
  }

  Future<void> ensureLoaded() async {
    if (!_loaded) await refreshPlan();
  }

  void invalidate() {
    _repo.invalidateMe();
    refreshPlan(force: true);
  }

  void onPushNotification(String? type) {
    if (type == null) return;
    final t = type.toLowerCase().replaceAll('_', '');
    if (t.startsWith('plan')) invalidate();
    if (_reloadListTypes.contains(t)) _reloadMyLists();
  }

  void _reloadMyLists() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(seconds: 2), _doReloadMyLists);
  }

  void _doReloadMyLists() {
    if (Get.isRegistered<ListingController>() && Get.find<ListingController>().hasLoadedMyListings) {
      Get.find<ListingController>().loadMyListings();
    }
    if (Get.isRegistered<PlotController>() && Get.find<PlotController>().hasLoadedMyPlots) {
      Get.find<PlotController>().loadMyPlots(reset: true);
    }
  }

  void _applyMe(MyPlanModel me) {
    if (_disposed) return;
    _planSeq++;
    isLoadingPlan.value = false;
    myPlan.value = me;
    _loaded = true;
    planLoadFailed.value = false;
    _syncGateway(me);
  }

  void clear() {
    _repo.clear();
    _cancelInflight();
    _disposeGateway();
    _fallbackRazorpay?.dispose();
    _fallbackRazorpay = null;
    myPlan.value = const MyPlanModel();
    catalog.value = null;
    history.clear();
    activePurchase.value = null;
    planLoadFailed.value = false;
    _skipOpenIds.clear();
    _strayTokens.clear();
    _lastRestoreAt = null;
    _loaded = false;
  }

  @override
  void onClose() {
    _disposed = true;
    _reloadTimer?.cancel();
    _pollSeq++;
    _cancelInflight();
    _disposeGateway();
    _fallbackRazorpay?.dispose();
    _fallbackRazorpay = null;
    super.onClose();
  }

  void onAppResumed() {
    final g = _gateway;
    if (g is RazorpayGateway) g.onAppResumed();
    _fallbackRazorpay?.onAppResumed();
    if (g is PlayBillingGateway) unawaited(restorePurchases());
  }

  void _cancelInflight() {
    final f = _inflight;
    _inflight = null;
    if (f != null && !f.done.isCompleted) f.done.complete(null);
  }

  void _syncGateway(MyPlanModel me) {
    if (_disposed || me.featureKey == null) return;
    final want = _providerKey(me.paymentProvider);
    final current = _gateway;
    if (current != null && (current.provider == want || isPurchasing.value)) return;
    unawaited(_startGateway(want));
  }

  Future<void> _startGateway(String provider) async {
    await _ensureGateway(provider);
    if (_disposed || provider != 'Play') return;
    if (catalog.value != null) unawaited(loadStore());
    await restorePurchases();
  }

  Future<BillingGateway> _ensureGateway(String provider) async {
    final current = _gateway;
    if (current != null && current.provider == provider) {
      await _gatewayInit;
      return current;
    }
    _disposeGateway();
    final BillingGateway g = provider == 'Play' ? PlayBillingGateway() : RazorpayGateway();
    _gateway = g;
    _gatewaySub = g.events.listen(_onBillingEvent);
    final init = g.init();
    _gatewayInit = init;
    await init;
    return g;
  }

  void _disposeGateway() {
    _gatewaySub?.cancel();
    _gatewaySub = null;
    _gateway?.dispose();
    _gateway = null;
    _gatewayInit = null;
    _restoreBatch = null;
    if (_disposed) return;
    storeState.value = StoreState.idle;
    storeProducts.clear();
    ownedPurchases.clear();
    otherAccountProducts.clear();
    detachedProducts.clear();
    isRestoring.value = false;
  }

  RazorpayGateway _razorpayGateway() {
    final g = _gateway;
    if (g is RazorpayGateway) return g;
    return _fallbackRazorpay ??= RazorpayGateway();
  }

  void _onBillingEvent(BillingEvent e) {
    if (_disposed) return;
    final owned = e.purchase;
    final batch = _restoreBatch;
    if (e.kind == BillingEventKind.restored && batch != null) {
      if (owned != null) batch.add(owned);
      return;
    }
    if (owned != null && (e.kind == BillingEventKind.purchased || e.kind == BillingEventKind.restored)) {
      ownedPurchases[owned.productId] = owned;
    }
    final inflight = _inflight;
    if (inflight != null && !inflight.done.isCompleted) {
      switch (e.kind) {
        case BillingEventKind.pending:
        case BillingEventKind.purchased:
          if (inflight.matches(e)) {
            inflight.done.complete(e);
            return;
          }
        case BillingEventKind.canceled:
        case BillingEventKind.error:
        case BillingEventKind.alreadyOwned:
          inflight.done.complete(e);
          return;
        case BillingEventKind.restored:
          break;
      }
    }
    if (owned != null && (e.kind == BillingEventKind.purchased || e.kind == BillingEventKind.restored)) {
      unawaited(_restoreStray(owned));
    }
  }

  Future<void> loadCatalog({bool force = false}) async {
    if (isLoadingCatalog.value) return;
    isLoadingCatalog.value = true;
    try {
      catalog.value = await _repo.getCatalog(forceRefresh: force);
    } catch (_) {
      if (catalog.value == null) AppToast.error('Could not load plans. Pull to refresh.');
    } finally {
      isLoadingCatalog.value = false;
    }
    if (isPlay && catalog.value != null) unawaited(loadStore(force: force));
  }

  Future<void> loadStore({bool force = false}) {
    final running = _storeFlight;
    if (running != null) return running;
    final flight = _loadStore(force);
    _storeFlight = flight;
    return flight.whenComplete(() {
      if (identical(_storeFlight, flight)) _storeFlight = null;
    });
  }

  Future<void> reloadStore() => loadStore(force: true);

  Future<void> _loadStore(bool force) async {
    if (_disposed || !hasPlanFeature || !isPlay || catalog.value == null) return;
    final ids = <String>{
      for (final p in plans)
        if (!p.isDefault && p.playProductId != null) p.playProductId!,
    };
    if (ids.isEmpty) {
      storeState.value = StoreState.ready;
      return;
    }
    if (!force && storeState.value == StoreState.ready && ids.every(storeProducts.containsKey)) return;
    final g = await _ensureGateway('Play');
    if (_disposed) return;
    storeState.value = StoreState.loading;
    try {
      if (!await g.isAvailable()) {
        if (!_disposed) storeState.value = StoreState.unavailable;
        return;
      }
      final products = await g.loadProducts(ids);
      if (_disposed) return;
      storeProducts
        ..clear()
        ..addAll(products);
      storeState.value = StoreState.ready;
    } catch (_) {
      if (!_disposed) storeState.value = StoreState.unavailable;
    }
  }

  StoreOffer? _baseOffer(PlanModel plan, int cycleMonths) {
    final productId = plan.playProductId;
    final basePlanId = plan.priceFor(cycleMonths)?.playBasePlanId;
    if (productId == null || basePlanId == null) return null;
    return storeProducts[productId]?.basePlan(basePlanId);
  }

  StorePrice? storePriceFor(PlanModel plan, int cycleMonths) => _baseOffer(plan, cycleMonths)?.price;

  StoreOffer? trialOfferFor(PlanModel plan) {
    final productId = plan.playProductId;
    if (productId == null) return null;
    for (final p in plan.prices) {
      final basePlanId = p.playBasePlanId;
      final offerId = p.playTrialOfferId;
      if (basePlanId != null && offerId != null) return storeProducts[productId]?.trialOffer(basePlanId, offerId);
    }
    return null;
  }

  OwnedPurchase? oldPurchaseFor(String token) {
    for (final p in ownedPurchases.values) {
      if (p.purchaseToken == token) return p;
    }
    return null;
  }

  StoreOffer? _offerForOrder(PlanOrder order) {
    final productId = order.playProductId;
    final basePlanId = order.playBasePlanId;
    if (productId == null || basePlanId == null) return null;
    final product = storeProducts[productId];
    if (product == null) return null;
    final offerId = order.playOfferId;
    return offerId != null ? product.trialOffer(basePlanId, offerId) : product.basePlan(basePlanId);
  }

  String _planNameForProduct(String productId) {
    for (final p in plans) {
      if (p.playProductId == productId) return p.name;
    }
    return myPlan.value.planName;
  }

  Future<void> loadHistory() async {
    isLoadingHistory.value = true;
    try {
      history.value = await _repo.getHistory();
    } catch (_) {
    } finally {
      isLoadingHistory.value = false;
    }
  }

  Future<QuoteResult> quote(String planId, int cycleMonths, String? couponCode, {bool useTrial = false}) async {
    try {
      return QuoteSuccess(await _repo.quote(planId, cycleMonths, couponCode, useTrial: useTrial));
    } catch (e) {
      return QuoteFailure(
        DioErrorMapper.toMessage(e, 'Could not get price. Try again.',
            showRawMessageForStatusCodes: const {400, 403, 404, 409}),
        errorType: DioErrorMapper.errorType(e),
      );
    }
  }

  Future<bool> startTrial(String planId) async {
    if (isPlay) {
      AppToast.info('Start the free trial from the plan card.');
      return false;
    }
    if (isPurchasing.value) return false;
    isPurchasing.value = true;
    try {
      final me = await _repo.startTrial(planId);
      _planSeq++;
      isLoadingPlan.value = false;
      myPlan.value = me;
      AppToast.success('Trial started.');
      return true;
    } catch (e) {
      AppToast.error(DioErrorMapper.toMessage(e, 'Could not start trial.',
          showRawMessageForStatusCodes: const {400, 403, 409}));
      if (DioErrorMapper.errorType(e) == 'TrialNotAvailable') invalidate();
      return false;
    } finally {
      isPurchasing.value = false;
    }
  }

  Future<void> swapLive({required bool isPlot, required String targetId, required String pauseListingId}) =>
      _repo.swapLive(isPlot: isPlot, targetId: targetId, pauseListingId: pauseListingId);

  Future<void> openManageSubscription() async {
    final url = myPlan.value.manageUrl;
    final g = _gateway;
    var ok = g != null && await g.openManage(url);
    if (!ok) {
      final uri = Uri.tryParse(url ?? PlayBillingGateway.subscriptionsUrl) ??
          Uri.parse(PlayBillingGateway.subscriptionsUrl);
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!ok) AppToast.error('Could not open Google Play.');
  }

  Future<void> showInAppMessages() async {
    final play = myPlan.value.play;
    final g = _gateway;
    if (play == null || !(play.inGrace || play.onHold) || g is! PlayBillingGateway) return;
    await g.showInAppMessages();
  }

  static const _verifyRetryDelays = [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)];
  static const _refreshOnOrderErrors = {'TrialNotAvailable', 'AlreadySubscribed', 'SubscriptionOnHold'};

  Future<CreateOrderResult> _createOrder(String planId, int cycleMonths, String? couponCode,
      {bool useTrial = false}) async {
    try {
      return CreateOrderSuccess(await _repo.createOrder(planId, cycleMonths, couponCode, useTrial: useTrial));
    } catch (e) {
      final message = DioErrorMapper.toMessage(e, 'Could not start purchase. Try again.',
          showRawMessageForStatusCodes: const {400, 403, 409});
      AppToast.error(message);
      final type = DioErrorMapper.errorType(e);
      if (_refreshOnOrderErrors.contains(type)) invalidate();
      return CreateOrderFailure(message, errorType: type);
    }
  }

  /// Runs create order -> store/checkout -> verify -> poll. Progress is exposed via [activePurchase].
  Future<void> purchase(PlanModel plan, int cycleMonths, String? couponCode, {bool useTrial = false}) async {
    if (isPurchasing.value) return;
    isPurchasing.value = true;
    _pollSeq++;
    _polling = false;
    pollTimedOut.value = false;
    try {
      final created = await _createOrder(plan.id, cycleMonths, couponCode, useTrial: useTrial);
      if (_disposed) return;
      if (created is! CreateOrderSuccess) return;
      final order = created.order;
      activePurchase.value = PurchaseStatus(
        purchaseId: order.purchaseId,
        status: order.status,
        planName: order.planName,
        grantedDays: order.grantedDays,
        endsAt: null,
        failureReason: null,
        grantBlockedReason: null,
        provider: order.provider,
      );
      if (order.isPlay) {
        await _purchasePlay(order);
        return;
      }
      if (!order.requiresPayment) {
        await _pollUntilSettled(order.purchaseId);
        _afterSettled();
        return;
      }
      final paid = await _razorpayGateway().checkout(order);
      if (_disposed) return;
      if (paid == null) {
        _skipOpenIds.add(order.purchaseId);
        activePurchase.value = null;
        return;
      }
      activePurchase.value = PurchaseStatus(
        purchaseId: order.purchaseId,
        status: 'Pending',
        planName: order.planName,
        grantedDays: order.grantedDays,
        endsAt: null,
        failureReason: null,
        grantBlockedReason: null,
        provider: order.provider,
      );
      final result = await _verifyWithRetry(order.purchaseId, paid);
      if (result is VerifyPaymentSuccess) {
        activePurchase.value = result.status;
      } else if (result is VerifyPaymentFailure && result.isDefinite) {
        _skipOpenIds.add(order.purchaseId);
        activePurchase.value = PurchaseStatus(
          purchaseId: order.purchaseId,
          status: 'VerifyFailed',
          planName: order.planName,
          grantedDays: order.grantedDays,
          endsAt: null,
          failureReason: null,
          grantBlockedReason: null,
          provider: order.provider,
        );
        _afterSettled();
        return;
      }
      if (activePurchase.value?.isOpen ?? false) await _pollUntilSettled(order.purchaseId);
      _afterSettled();
    } catch (_) {
      if (!_disposed) AppToast.error('Could not complete purchase. Check My Plan.');
    } finally {
      isPurchasing.value = false;
    }
  }

  PurchaseStatus _playStatus(PlanOrder? order, String status, {String? purchaseId, DateTime? endsAt, String? planName}) =>
      PurchaseStatus(
        purchaseId: purchaseId ?? order?.purchaseId ?? '',
        status: status,
        planName: planName ?? order?.planName ?? myPlan.value.planName,
        grantedDays: order?.grantedDays ?? 0,
        endsAt: endsAt,
        failureReason: null,
        grantBlockedReason: null,
        provider: 'Play',
      );

  PurchaseStatus _present(PurchaseStatus s) =>
      s.isPlay && s.status == 'Pending' ? s.copyWith(status: 'PlayPending') : s;

  void _abandon(PlanOrder order, String message) {
    _skipOpenIds.add(order.purchaseId);
    activePurchase.value = null;
    AppToast.error(message);
  }

  Future<void> _purchasePlay(PlanOrder order) async {
    final g = await _ensureGateway('Play');
    if (_disposed) return;
    if (order.playProductId == null || order.playBasePlanId == null) {
      _abandon(order, 'This plan is not available yet.');
      return;
    }
    var offer = _offerForOrder(order);
    if (offer == null) {
      await loadStore(force: true);
      if (_disposed) return;
      offer = _offerForOrder(order);
    }
    if (offer == null) {
      if (storeState.value == StoreState.unavailable) {
        _skipOpenIds.add(order.purchaseId);
        activePurchase.value = _playStatus(order, 'StoreUnavailable');
        return;
      }
      _abandon(
        order,
        order.playOfferId != null
            ? 'Free trial is not available on this Google account.'
            : 'This plan is not available in Google Play yet.',
      );
      return;
    }
    OwnedPurchase? old;
    final oldToken = order.playOldPurchaseToken;
    if (oldToken != null) {
      old = oldPurchaseFor(oldToken);
      if (old == null && g is PlayBillingGateway) {
        try {
          await _queryOwned(g);
        } catch (_) {}
        if (_disposed) return;
        old = oldPurchaseFor(oldToken);
      }
      if (old == null) {
        _abandon(order, 'Restore your subscription first.');
        return;
      }
    }

    final inflight = _PlayInflight(order, old);
    _inflight = inflight;
    BillingEvent? event;
    try {
      final launched = await g.launch(order, offer: offer, oldPurchase: old);
      if (_disposed) return;
      if (!launched) {
        if (identical(_inflight, inflight)) _inflight = null;
        await _restore(force: true, userInitiated: true, order: order);
        return;
      }
      event = await inflight.done.future.timeout(_playLaunchTimeout, onTimeout: () => null);
    } finally {
      if (identical(_inflight, inflight)) _inflight = null;
    }
    if (_disposed) return;
    if (event == null) {
      _skipOpenIds.add(order.purchaseId);
      activePurchase.value = null;
      unawaited(restorePurchases(force: true));
      return;
    }

    if (event.kind == BillingEventKind.canceled) {
      _skipOpenIds.add(order.purchaseId);
      activePurchase.value = null;
      return;
    }
    final isPending = event.kind == BillingEventKind.pending;
    final token = event.purchaseToken;
    final productId = event.productId;
    if (token == null || productId == null || !(isPending || event.kind == BillingEventKind.purchased)) {
      if (isPending) {
        activePurchase.value = _playStatus(order, 'PlayPending');
        await _pollUntilSettled(order.purchaseId);
        _afterSettled();
      } else {
        await _restore(force: true, userInitiated: true, order: order);
      }
      return;
    }

    activePurchase.value = _playStatus(order, isPending ? 'PlayPending' : 'Pending');
    final result = await _verifyPlayWithRetry(order.purchaseId, token, productId);
    if (_disposed) return;
    if (result is VerifyPaymentSuccess) {
      if (result.status.outcome == 'Detached') {
        _skipOpenIds.add(order.purchaseId);
        activePurchase.value = _playStatus(order, 'Detached', endsAt: result.status.endsAt);
        return;
      }
      activePurchase.value = _present(result.status);
    } else if (result is VerifyPaymentFailure) {
      if (result.errorType == 'PurchaseBelongsToAnotherAccount') {
        _skipOpenIds.add(order.purchaseId);
        otherAccountProducts.add(productId);
        activePurchase.value = _playStatus(order, 'OtherAccount');
        return;
      }
      if (result.isDefinite) {
        _skipOpenIds.add(order.purchaseId);
        activePurchase.value = _playStatus(order, 'VerifyFailed');
        _afterSettled();
        return;
      }
    }
    if (activePurchase.value?.isOpen ?? false) await _pollUntilSettled(order.purchaseId);
    _afterSettled();
  }

  Future<VerifyPaymentResult> _verifyPlayOnce(String purchaseId, String token, String productId) async {
    try {
      return VerifyPaymentSuccess(await _repo.verifyPlay(purchaseId, purchaseToken: token, productId: productId));
    } catch (e) {
      if (DioErrorMapper.isNetworkError(e)) {
        return VerifyPaymentFailure('No internet connection.', isNetworkError: true);
      }
      final type = DioErrorMapper.errorType(e);
      if (type == 'AlreadyProcessed') {
        try {
          return VerifyPaymentSuccess(await _repo.getStatus(purchaseId));
        } catch (_) {}
      }
      final status = e is DioException ? e.response?.statusCode : null;
      return VerifyPaymentFailure(
        DioErrorMapper.toMessage(e, 'Payment verification failed.'),
        isNetworkError: status == 502 || status == 503 || status == 504,
        isDefinite: status == 400 || status == 403 || status == 404 || status == 409,
        errorType: type,
      );
    }
  }

  Future<VerifyPaymentResult> _verifyPlayWithRetry(String purchaseId, String token, String productId) async {
    var result = await _verifyPlayOnce(purchaseId, token, productId);
    for (final delay in _verifyRetryDelays) {
      if (result is! VerifyPaymentFailure || !result.isNetworkError || _disposed) break;
      await Future.delayed(delay);
      result = await _verifyPlayOnce(purchaseId, token, productId);
    }
    return result;
  }

  Future<void> restorePurchases({bool force = false, bool userInitiated = false}) =>
      _restore(force: force, userInitiated: userInitiated);

  Future<void> _restore({required bool force, required bool userInitiated, PlanOrder? order}) async {
    if (_disposed || !hasPlanFeature) return;
    final g = userInitiated && isPlay && _gateway is! PlayBillingGateway ? await _ensureGateway('Play') : _gateway;
    if (_disposed) return;
    if (g is! PlayBillingGateway) {
      if (order != null) _abandon(order, 'Could not open Google Play. Try again.');
      return;
    }
    if (!force) {
      if (isPurchasing.value || isRestoring.value) return;
      final last = _lastRestoreAt;
      if (last != null && DateTime.now().difference(last) < _restoreThrottle) return;
    }
    if (isRestoring.value) {
      if (!userInitiated) return;
      await _restoreFlight;
      if (_disposed) return;
    }
    final flight = _runRestore(g, userInitiated: userInitiated, order: order);
    _restoreFlight = flight;
    try {
      await flight;
    } finally {
      if (identical(_restoreFlight, flight)) _restoreFlight = null;
    }
  }

  Future<List<OwnedPurchase>> _queryOwned(PlayBillingGateway g) async {
    final batch = <OwnedPurchase>[];
    _restoreBatch = batch;
    try {
      await g.restore();
    } finally {
      if (identical(_restoreBatch, batch)) _restoreBatch = null;
    }
    final byToken = <String, OwnedPurchase>{for (final p in batch) p.purchaseToken: p};
    if (!_disposed) {
      ownedPurchases
        ..clear()
        ..addAll({for (final p in byToken.values) p.productId: p});
    }
    return byToken.values.toList();
  }

  Future<void> _runRestore(PlayBillingGateway g, {required bool userInitiated, PlanOrder? order}) async {
    _lastRestoreAt = DateTime.now();
    isRestoring.value = true;
    if (userInitiated) {
      pollTimedOut.value = false;
      activePurchase.value = _playStatus(order, 'Restoring');
    }
    try {
      var owned = const <OwnedPurchase>[];
      try {
        owned = await _queryOwned(g);
      } catch (_) {
        isRestoring.value = false;
        if (userInitiated && !_disposed) await _showStoreFailure(g, order);
        return;
      }
      if (_disposed) return;
      final items = <(OwnedPurchase, RestoreItemResult)>[];
      try {
        for (var i = 0; i < owned.length; i += _restoreChunk) {
          final chunk = owned.sublist(i, i + _restoreChunk > owned.length ? owned.length : i + _restoreChunk);
          final res = await _repo.restorePlay([
            for (final p in chunk) (token: p.purchaseToken, productId: p.productId),
          ]);
          if (_disposed) return;
          for (final r in res.results) {
            if (r.index >= 0 && r.index < chunk.length) items.add((chunk[r.index], r));
          }
          _applyMe(res.me);
        }
      } catch (e) {
        isRestoring.value = false;
        if (userInitiated && !_disposed) {
          if (order != null) _skipOpenIds.add(order.purchaseId);
          activePurchase.value = null;
          AppToast.error(DioErrorMapper.toMessage(e, 'Could not restore. Try again.',
              showRawMessageForStatusCodes: const {400, 409}));
        }
        return;
      }
      otherAccountProducts
        ..clear()
        ..addAll({
          for (final x in items)
            if (x.$2.outcome == 'OtherAccount') x.$1.productId,
        });
      detachedProducts
        ..clear()
        ..addAll({
          for (final x in items)
            if (x.$2.outcome == 'Detached') x.$1.productId: x.$2.endsAt,
        });
      if (items.any((x) => x.$2.outcome == 'Granted')) _reloadMyLists();
      isRestoring.value = false;
      if (userInitiated) await _showRestoreOutcome(g, items, order);
    } finally {
      if (!_disposed) isRestoring.value = false;
    }
  }

  Future<void> _showStoreFailure(PlayBillingGateway g, PlanOrder? order) async {
    if (order != null) _skipOpenIds.add(order.purchaseId);
    final available = await g.isAvailable();
    if (_disposed) return;
    if (!available) {
      activePurchase.value = _playStatus(order, 'StoreUnavailable');
      return;
    }
    activePurchase.value = null;
    AppToast.error('Could not reach Google Play. Try again.');
  }

  static const _outcomePriority = ['Granted', 'OtherAccount', 'Detached', 'Pending', 'Unchanged'];

  Future<void> _showRestoreOutcome(
      PlayBillingGateway g, List<(OwnedPurchase, RestoreItemResult)> items, PlanOrder? order) async {
    if (_disposed) return;
    if (order != null) {
      (OwnedPurchase, RestoreItemResult)? hit;
      for (final x in items) {
        if (x.$1.productId == order.playProductId) hit = x;
      }
      if (hit == null) {
        _skipOpenIds.add(order.purchaseId);
        if (!await g.isAvailable()) {
          if (!_disposed) activePurchase.value = _playStatus(order, 'StoreUnavailable');
          return;
        }
        if (_disposed) return;
        activePurchase.value = null;
        AppToast.error('Could not open Google Play. Try again.');
        return;
      }
      await _showRestoreItem(hit.$1, hit.$2, order);
      return;
    }
    if (items.isEmpty) {
      activePurchase.value = null;
      AppToast.info('No subscription found on this Google account.');
      return;
    }
    var pick = items.first;
    var best = _outcomePriority.length;
    for (final x in items) {
      final rank = _outcomePriority.indexOf(x.$2.outcome);
      if (rank >= 0 && rank < best) {
        best = rank;
        pick = x;
      }
    }
    await _showRestoreItem(pick.$1, pick.$2, null);
  }

  Future<void> _showRestoreItem(OwnedPurchase owned, RestoreItemResult r, PlanOrder? order) async {
    final planName = order?.planName ?? _planNameForProduct(owned.productId);
    final purchaseId = r.purchaseId;
    switch (r.outcome) {
      case 'Granted':
      case 'Unchanged':
        if (order != null && purchaseId != order.purchaseId) _skipOpenIds.add(order.purchaseId);
        activePurchase.value = _playStatus(order, 'Granted', purchaseId: purchaseId, endsAt: r.endsAt, planName: planName);
      case 'OtherAccount':
        if (order != null) _skipOpenIds.add(order.purchaseId);
        activePurchase.value = _playStatus(order, 'OtherAccount', purchaseId: purchaseId, planName: planName);
      case 'Detached':
        if (order != null) _skipOpenIds.add(order.purchaseId);
        activePurchase.value = _playStatus(order, 'Detached', purchaseId: purchaseId, endsAt: r.endsAt, planName: planName);
      case 'Pending':
        if (order != null && purchaseId != order.purchaseId) _skipOpenIds.add(order.purchaseId);
        activePurchase.value = _playStatus(order, 'PlayPending', purchaseId: purchaseId, planName: planName);
        if (purchaseId != null) {
          await _pollUntilSettled(purchaseId);
          _afterSettled();
        }
      default:
        if (order != null) _skipOpenIds.add(order.purchaseId);
        activePurchase.value = null;
        AppToast.error(order != null ? 'Could not complete purchase. Try again.' : 'Could not restore this purchase.');
    }
  }

  Future<void> _restoreStray(OwnedPurchase p) async {
    if (_disposed || !hasPlanFeature || !_strayTokens.add(p.purchaseToken)) return;
    try {
      final res = await _repo.restorePlay([(token: p.purchaseToken, productId: p.productId)]);
      if (_disposed) return;
      _applyMe(res.me);
      for (final r in res.results) {
        if (r.index != 0) continue;
        if (r.outcome == 'OtherAccount') {
          otherAccountProducts.add(p.productId);
        } else {
          otherAccountProducts.remove(p.productId);
        }
        if (r.outcome == 'Detached') {
          detachedProducts[p.productId] = r.endsAt;
        } else {
          detachedProducts.remove(p.productId);
        }
        if (r.outcome == 'Granted') _reloadMyLists();
      }
    } catch (_) {
    } finally {
      _strayTokens.remove(p.purchaseToken);
    }
  }

  Future<VerifyPaymentResult> _verifyOnce(String purchaseId, PaymentSuccessResponse r) async {
    final orderId = r.orderId;
    final paymentId = r.paymentId;
    final signature = r.signature;
    if (orderId == null || paymentId == null || signature == null) {
      return VerifyPaymentFailure('Invalid payment response.', isNetworkError: false);
    }
    try {
      final status = await _repo.verify(
        purchaseId,
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
      );
      return VerifyPaymentSuccess(status);
    } catch (e) {
      if (DioErrorMapper.isNetworkError(e)) {
        return VerifyPaymentFailure('No internet connection.', isNetworkError: true);
      }
      if (DioErrorMapper.errorType(e) == 'AlreadyProcessed') {
        try {
          return VerifyPaymentSuccess(await _repo.getStatus(purchaseId));
        } catch (_) {}
      }
      final status = e is DioException ? e.response?.statusCode : null;
      return VerifyPaymentFailure(
        DioErrorMapper.toMessage(e, 'Payment verification failed.'),
        isNetworkError: false,
        isDefinite: status == 400 || status == 404,
      );
    }
  }

  Future<VerifyPaymentResult> _verifyWithRetry(String purchaseId, PaymentSuccessResponse r) async {
    var result = await _verifyOnce(purchaseId, r);
    for (final delay in _verifyRetryDelays) {
      if (result is! VerifyPaymentFailure || !result.isNetworkError) break;
      await Future.delayed(delay);
      result = await _verifyOnce(purchaseId, r);
    }
    return result;
  }

  Future<void> _pollUntilSettled(String purchaseId) async {
    final seq = ++_pollSeq;
    _polling = true;
    try {
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (seq == _pollSeq && DateTime.now().isBefore(deadline)) {
        try {
          final s = await _repo.getStatus(purchaseId);
          if (seq != _pollSeq) return;
          activePurchase.value = _present(s);
          if (!s.isOpen) return;
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 2));
      }
      if (seq == _pollSeq) pollTimedOut.value = true;
    } finally {
      if (seq == _pollSeq) _polling = false;
    }
  }

  void _afterSettled() {
    final s = activePurchase.value;
    if (s == null || s.isOpen) return;
    if (s.isGranted) _reloadMyLists();
    invalidate();
  }

  Future<void> resumeOpenPurchase() async {
    if (_polling || isPurchasing.value) return;
    try {
      final open = await _repo.getOpen();
      if (open != null && open.status == 'Created') {
        _skipOpenIds.add(open.purchaseId);
        return;
      }
      if (open == null || !open.isOpen || _skipOpenIds.contains(open.purchaseId)) return;
      pollTimedOut.value = false;
      activePurchase.value = _present(open);
      await _pollUntilSettled(open.purchaseId);
      _afterSettled();
    } catch (_) {}
  }

  void dismissPurchase() {
    final s = activePurchase.value;
    if (s == null) return;
    final staleCreated = s.status == 'Created' && pollTimedOut.value;
    if (staleCreated) _skipOpenIds.add(s.purchaseId);
    if (!s.isOpen || staleCreated || pollTimedOut.value) {
      activePurchase.value = null;
      pollTimedOut.value = false;
    }
  }

  void hidePurchaseSheet() {
    pollTimedOut.value = false;
  }
}
