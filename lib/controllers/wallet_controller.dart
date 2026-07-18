import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/coin_pack_model.dart';
import '../models/coin_transaction_model.dart';
import '../repositories/wallet_repository.dart';
import '../services/api_service.dart';
import '../utils/app_toast.dart';
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

  /// Called from AuthController.logout()/deleteAccount(), mirroring
  /// ListingController.clearData(). This is a long-lived singleton (put once in
  /// MainScreen.initState, never re-created on a fresh login without an app restart —
  /// Get.put() on an already-registered controller is a no-op), so without this a second
  /// user logging in on the same device would see the previous user's balance/ledger until
  /// they happened to open a screen that reloads it. coinPacks is a global, not per-user,
  /// catalog — left alone.
  void clearData() {
    balance.value = 0;
    transactions.clear();
    hasMoreTransactions.value = false;
    _transactionsPage = 1;
    Get.find<WalletRepository>().invalidateBalance();
  }

  // ---- Purchase / redeem flow — reusable across screens, screen-agnostic ----

  Future<Map<String, dynamic>?> createOrder(String coinPackId) async {
    try {
      final res = await ApiService.post('/coin-packs/create-order', {'coinPackId': coinPackId});
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
      return {
        'orderId': orderId,
        'amount': (amountRaw as num).toInt(),
        'currency': data['currency'] as String? ?? 'INR',
        'keyId': keyId,
      };
    } catch (e) {
      AppToast.error(_errorMessage(e, 'Could not start purchase. Please try again.'));
      return null;
    }
  }

  /// Rethrows on failure (rather than toasting) — same shape as the old
  /// ListingController.verifyPayment — so the caller (which is mid-Razorpay-
  /// callback) can show its own "contact support if amount was deducted"
  /// messaging instead of a generic toast.
  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final res = await ApiService.post('/coin-packs/verify-payment', {
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
    });
    final data = res['data'];
    if (data == null || data is! Map<String, dynamic> || data['success'] != true) {
      throw Exception('Payment verification failed');
    }
    Get.find<WalletRepository>().invalidateBalance();
    await loadBalance();
    return data;
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
      AppToast.error(_errorMessage(e, 'Could not redeem code. Please try again.'));
      return null;
    }
  }

  static String _errorMessage(dynamic e, String fallback) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }
      final status = e.response?.statusCode;
      String? message;
      final responseData = e.response?.data;
      if (responseData is Map<String, dynamic>) {
        message = responseData['error']?['message'] as String? ?? responseData['message'] as String?;
      } else if (responseData is String) {
        message = responseData;
      }
      // 400/404/409 all carry clear, user-facing messages on these endpoints
      // (invalid/disabled pack, "already in progress", invalid/expired/
      // exhausted/already-redeemed code) — show them verbatim.
      if ((status == 400 || status == 404 || status == 409) && message != null) return message;
      if (status == 429) return 'Too many attempts. Please try again later.';
      if (status != null && status >= 500) return 'Server error. Please try again.';
      if (message != null) return message;
    }
    return fallback;
  }
}
