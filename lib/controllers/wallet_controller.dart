import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/coin_pack_model.dart';
import '../models/coin_pack_purchase_result.dart';
import '../models/coin_transaction_model.dart';
import '../repositories/wallet_repository.dart';
import '../services/api_service.dart';
import '../utils/app_toast.dart';
import '../utils/dio_error_mapper.dart';
import 'auth_controller.dart';

/// Single source of truth for "what's my balance right now" — nothing else
/// in the app caches it separately. Also owns the coin-pack catalog, the
/// wallet ledger's pagination state, and the reusable purchase/redeem flow
/// (order creation + Razorpay verification + cancel, code redemption) so
/// screens don't embed payment plumbing themselves (mirrors how the old
/// payment_screen.dart drove Razorpay directly, but as a controller method
/// other screens call instead of a screen-embedded flow).
class WalletController extends GetxController {
  final balance = 0.obs;
  final isLoadingBalance = false.obs;
  final coinPacks = <CoinPackModel>[].obs;
  final isLoadingPacks = false.obs;
  final transactions = <CoinTransactionModel>[].obs;
  final isLoadingTransactions = false.obs;
  final hasMoreTransactions = false.obs;
  int _transactionsPage = 1;

  @override
  void onInit() {
    super.onInit();
    loadBalance();
    loadCoinPacks();
  }

  Future<void> loadBalance({bool forceRefresh = false}) async {
    isLoadingBalance.value = true;
    try {
      balance.value = await Get.find<WalletRepository>().getBalance(forceRefresh: forceRefresh);
      _announceWelcomeBonusIfJustSignedUp();
    } catch (_) {
    } finally {
      isLoadingBalance.value = false;
    }
  }

  /// The single funnel for every balance-changing event in the app — both locally-triggered
  /// (a Go-Live/purchase/redeem response already carries the true post-mutation balance, so no
  /// extra network round-trip is needed) and remotely-pushed (WalletHubService, for changes this
  /// device didn't itself initiate — admin credit/debit, a Razorpay webhook fallback credit).
  /// Deliberately bypasses WalletRepository's TTL cache via primeBalance() instead of invalidate+
  /// refetch — the caller already has an authoritative value, so there's nothing to refetch.
  void applyBalanceUpdate(int newBalance, {String? reason}) {
    balance.value = newBalance;
    Get.find<WalletRepository>().primeBalance(newBalance);
  }

  // The 100-coin welcome bonus is credited silently server-side on signup (best-effort, idempotent
  // coupon redemption) — this is the one place that turns it into something the owner actually sees,
  // on the very first balance load after a brand-new account finishes onboarding. Consumed exactly
  // once via AuthController.justSignedUp; never fires for a returning login.
  void _announceWelcomeBonusIfJustSignedUp() {
    final auth = Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    if (auth == null || !auth.justSignedUp) return;
    auth.justSignedUp = false;
    if (balance.value > 0) {
      AppToast.success('🎉 ${balance.value} coins added — Welcome Bonus!');
    }
  }

  Future<void> loadCoinPacks() async {
    isLoadingPacks.value = true;
    try {
      coinPacks.value = await Get.find<WalletRepository>().getCoinPacks();
    } catch (_) {
      AppToast.error('Could not load coin packs. Pull to refresh.');
    } finally {
      isLoadingPacks.value = false;
    }
  }

  Future<void> loadTransactions({bool reset = false, String? reason}) async {
    try {
      if (reset) {
        _transactionsPage = 1;
        transactions.clear();
        hasMoreTransactions.value = false;
      }
      isLoadingTransactions.value = true;
      final result = await Get.find<WalletRepository>()
          .getTransactions(page: _transactionsPage, reason: reason);
      if (_transactionsPage == 1) {
        transactions.value = result.items;
      } else {
        transactions.addAll(result.items);
      }
      hasMoreTransactions.value = result.hasMore;
    } catch (_) {
      AppToast.error('Could not load transactions. Pull to refresh.');
    } finally {
      isLoadingTransactions.value = false;
    }
  }

  Future<void> loadNextTransactionsPage({String? reason}) async {
    if (!hasMoreTransactions.value || isLoadingTransactions.value) return;
    _transactionsPage++;
    await loadTransactions(reason: reason);
  }

  // ---- Purchase / redeem flow — reusable across screens, screen-agnostic ----

  /// [confirmed] should only ever be true when re-submitting after the
  /// caller has already shown the user a CreateOrderRecentPurchaseDetected
  /// warning and they chose to proceed anyway.
  Future<CreateOrderResult> createOrder(String coinPackId, {bool confirmed = false}) async {
    try {
      final res = await ApiService.post(
          '/coin-packs/create-order', {'coinPackId': coinPackId, 'confirmed': confirmed});
      final data = res['data'];
      if (data == null || data is! Map<String, dynamic>) {
        throw Exception('Invalid order response from server');
      }
      final orderId = data['orderId'] as String?;
      final keyId = data['keyId'] as String?;
      final amountRaw = data['amount'];
      if (orderId == null || orderId.isEmpty || keyId == null || keyId.isEmpty || amountRaw == null) {
        throw Exception('Missing order details from server');
      }
      return CreateOrderSuccess(
        orderId: orderId,
        amount: (amountRaw as num).toInt(),
        currency: data['currency'] as String? ?? 'INR',
        keyId: keyId,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 && DioErrorMapper.errorType(e) == 'RECENT_PURCHASE_DETECTED') {
        // No order/DB row was created server-side for this attempt — nothing
        // to toast, the caller shows a confirm dialog instead.
        final message = (e.response?.data is Map<String, dynamic>)
            ? (e.response!.data['error']?['message'] as String?)
            : null;
        return CreateOrderRecentPurchaseDetected(message ?? 'You recently bought coins. Buy again?');
      }
      final message = DioErrorMapper.toMessage(
        e,
        'Could not start purchase. Please try again.',
        showRawMessageForStatusCodes: const {400, 404, 409},
      );
      AppToast.error(message);
      return CreateOrderFailure(message);
    } catch (_) {
      const message = 'Could not start purchase. Please try again.';
      AppToast.error(message);
      return CreateOrderFailure(message);
    }
  }

  /// Never throws (unlike the old shape this replaced) — always resolves to a
  /// VerifyPaymentResult so the caller (mid-Razorpay-callback) can branch on
  /// network-vs-clean-failure, retry accordingly, and treat
  /// VerifyPaymentAlreadyProcessed as success rather than an error.
  Future<VerifyPaymentResult> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      final res = await ApiService.post('/coin-packs/verify-payment', {
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      });
      final data = res['data'];
      if (data == null || data is! Map<String, dynamic> || data['success'] != true) {
        return VerifyPaymentFailure('Payment verification failed', isNetworkError: false);
      }
      Get.find<WalletRepository>().invalidateBalance();
      await loadBalance();
      return VerifyPaymentSuccess(
        coinsCredited: (data['coinsCredited'] as num?)?.toInt() ?? 0,
        newBalance: (data['newBalance'] as num?)?.toInt() ?? balance.value,
      );
    } on DioException catch (e) {
      if (DioErrorMapper.isNetworkError(e)) {
        return VerifyPaymentFailure(
          DioErrorMapper.toMessage(e, 'No internet connection.'),
          isNetworkError: true,
        );
      }
      if (DioErrorMapper.errorType(e) == 'ALREADY_PROCESSED') {
        // Another path (webhook, or an earlier attempt of this same call)
        // already credited it — force-refresh, bypassing the 30s cache,
        // since our own local balance may not reflect it yet.
        balance.value = await Get.find<WalletRepository>().getBalance(forceRefresh: true);
        return VerifyPaymentAlreadyProcessed();
      }
      return VerifyPaymentFailure(
        DioErrorMapper.toMessage(e, 'Payment verification failed.', showRawMessageForStatusCodes: const {400}),
        isNetworkError: false,
      );
    } catch (_) {
      return VerifyPaymentFailure('Payment verification failed', isNetworkError: false);
    }
  }

  /// Last-resort status check — call only after verify-payment retries are
  /// exhausted (or can't run at all, e.g. right after an app relaunch with no
  /// in-memory order state left). Uses only the JWT, no client-held order id.
  Future<LatestPurchaseStatus> getLatestPurchase() async {
    try {
      final res = await ApiService.get('/coin-packs/purchases/latest');
      final data = res['data'];
      if (data == null || data is! Map<String, dynamic> || data['hasPurchase'] != true) {
        return LatestPurchaseStatus(hasPurchase: false);
      }
      return LatestPurchaseStatus(
        hasPurchase: true,
        status: data['status'] as String?,
        completedAt: data['completedAt'] != null ? DateTime.tryParse(data['completedAt'] as String) : null,
      );
    } catch (_) {
      return LatestPurchaseStatus(hasPurchase: false);
    }
  }

  /// Fire-and-forget cleanup of a PENDING purchase row — same pattern the old
  /// payment_screen.dart used against /payments/cancel-order, just pointed at
  /// the coin-pack endpoint. Never blocks the UI.
  Future<void> cancelOrder(String razorpayOrderId) async {
    try {
      await ApiService.post('/coin-packs/cancel-order', {'razorpayOrderId': razorpayOrderId});
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> redeemCode(String code) async {
    try {
      final res = await ApiService.post('/coupons/redeem', {'code': code});
      final data = res['data'];
      if (data == null || data is! Map<String, dynamic>) {
        throw Exception('Invalid response from server');
      }
      Get.find<WalletRepository>().invalidateBalance();
      await loadBalance();
      return data;
    } catch (e) {
      AppToast.error(DioErrorMapper.toMessage(
        e,
        'Could not redeem code. Please try again.',
        showRawMessageForStatusCodes: const {400, 404, 409},
      ));
      return null;
    }
  }
}
