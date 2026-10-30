import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/my_plan_model.dart';
import '../models/plan_model.dart';
import '../models/plan_purchase_result.dart';
import '../repositories/plan_repository.dart';
import '../utils/app_toast.dart';
import '../utils/dio_error_mapper.dart';
import 'auth_controller.dart';
import 'listing_controller.dart';
import 'plot_controller.dart';

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

  bool _polling = false;
  bool _loaded = false;
  int _planSeq = 0;
  int _pollSeq = 0;
  bool _disposed = false;
  Timer? _reloadTimer;
  Completer<PaymentSuccessResponse?>? _checkout;
  final _skipOpenIds = <String>{};

  PlanRepository get _repo => Get.find<PlanRepository>();

  PlanLimitsModel get limits => myPlan.value.limits;
  bool get paymentEnabled => myPlan.value.paymentEnabled;
  bool get hasPlanFeature => myPlan.value.featureKey != null;
  bool get hasRoomForLive => limits.live < limits.listingLimit;
  bool get isLoaded => _loaded;

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
    if (t == 'planactivated' || t == 'planexpired') _reloadMyLists();
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

  void clear() {
    _repo.clear();
    myPlan.value = const MyPlanModel();
    catalog.value = null;
    history.clear();
    activePurchase.value = null;
    planLoadFailed.value = false;
    _skipOpenIds.clear();
    _loaded = false;
  }

  @override
  void onClose() {
    _disposed = true;
    _reloadTimer?.cancel();
    _pollSeq++;
    final c = _checkout;
    if (c != null && !c.isCompleted) c.complete(null);
    super.onClose();
  }

  void onAppResumed() {
    final c = _checkout;
    if (c == null) return;
    Future.delayed(const Duration(seconds: 3), () {
      if (!c.isCompleted) c.complete(null);
    });
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

  Future<QuoteResult> quote(String planId, int cycleMonths, String? couponCode) async {
    try {
      return QuoteSuccess(await _repo.quote(planId, cycleMonths, couponCode));
    } catch (e) {
      return QuoteFailure(
        DioErrorMapper.toMessage(e, 'Could not get price. Try again.',
            showRawMessageForStatusCodes: const {400, 403, 404, 409}),
        errorType: DioErrorMapper.errorType(e),
      );
    }
  }

  Future<bool> startTrial(String planId) async {
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

  static const _verifyRetryDelays = [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)];

  Future<CreateOrderResult> _createOrder(String planId, int cycleMonths, String? couponCode) async {
    try {
      return CreateOrderSuccess(await _repo.createOrder(planId, cycleMonths, couponCode));
    } catch (e) {
      final message = DioErrorMapper.toMessage(e, 'Could not start purchase. Try again.',
          showRawMessageForStatusCodes: const {400, 403, 409});
      AppToast.error(message);
      return CreateOrderFailure(message, errorType: DioErrorMapper.errorType(e));
    }
  }

  /// Runs create order -> checkout -> verify -> poll. Progress is exposed via [activePurchase].
  Future<void> purchase(PlanModel plan, int cycleMonths, String? couponCode) async {
    if (isPurchasing.value) return;
    isPurchasing.value = true;
    _pollSeq++;
    _polling = false;
    pollTimedOut.value = false;
    try {
      final created = await _createOrder(plan.id, cycleMonths, couponCode);
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
      );
      if (!order.requiresPayment) {
        await _pollUntilSettled(order.purchaseId);
        _afterSettled();
        return;
      }
      final paid = await _openCheckout(order);
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

  Future<PaymentSuccessResponse?> _openCheckout(PlanOrder order) async {
    final completer = Completer<PaymentSuccessResponse?>();
    _checkout = completer;
    final razorpay = Razorpay();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      if (!completer.isCompleted) completer.complete(r);
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (r.code != Razorpay.PAYMENT_CANCELLED) AppToast.error('Payment failed. Try again.');
      if (!completer.isCompleted) completer.complete(null);
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      AppToast.info('External wallet: ${r.walletName}');
    });
    try {
      final phone = Get.find<AuthController>().user.value?.phoneNumber ?? '';
      razorpay.open({
        'key': order.keyId,
        'amount': order.amountPaise,
        'currency': order.currency,
        'order_id': order.razorpayOrderId,
        'name': 'Bakhli',
        'description': order.planName,
        'prefill': {'contact': _formatPhone(phone)},
        'theme': {'color': '#1E3A8A'},
      });
      return await completer.future;
    } catch (_) {
      AppToast.error('Could not open payment. Try again.');
      return null;
    } finally {
      _checkout = null;
      razorpay.clear();
    }
  }

  String _formatPhone(String raw) {
    final clean = raw.replaceAll(RegExp(r'[\s+\-()]'), '');
    if (clean.length == 10) return '+91$clean';
    if (clean.length == 12 && clean.startsWith('91')) return '+$clean';
    return raw;
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
          activePurchase.value = s;
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
      activePurchase.value = open;
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
