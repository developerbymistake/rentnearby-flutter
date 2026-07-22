/// Outcome of WalletController.createOrder — lets CoinPacksScreen branch on
/// "user recently bought coins" specifically (show a confirm dialog) instead
/// of just toasting a generic error. Mirrors the GoLiveResult pattern
/// (lib/models/go_live_result.dart).
sealed class CreateOrderResult {}

class CreateOrderSuccess extends CreateOrderResult {
  final String orderId;
  final int amount;
  final String currency;
  final String keyId;
  CreateOrderSuccess({required this.orderId, required this.amount, required this.currency, required this.keyId});
}

/// Server declined to create an order — no order/DB row was created for this
/// attempt. Caller should confirm with the user, then retry with confirmed: true.
class CreateOrderRecentPurchaseDetected extends CreateOrderResult {
  final String message;
  CreateOrderRecentPurchaseDetected(this.message);
}

/// Already toasted by WalletController before returning — same "controller
/// already toasted the reason" convention the old nullable-Map return used.
class CreateOrderFailure extends CreateOrderResult {
  final String message;
  CreateOrderFailure(this.message);
}

/// Outcome of WalletController.verifyPayment.
sealed class VerifyPaymentResult {}

class VerifyPaymentSuccess extends VerifyPaymentResult {
  final int coinsCredited;
  final int newBalance;
  VerifyPaymentSuccess({required this.coinsCredited, required this.newBalance});
}

/// Another path (the webhook, or an earlier attempt of this same call) already
/// credited this exact purchase — treat as success, but there's no fresh
/// coinsCredited/newBalance here; caller should force-refresh balance.
class VerifyPaymentAlreadyProcessed extends VerifyPaymentResult {}

/// isNetworkError distinguishes "worth retrying" (timeout/connection drop)
/// from a clean rejection (bad signature, etc.) that retrying can't fix.
class VerifyPaymentFailure extends VerifyPaymentResult {
  final String message;
  final bool isNetworkError;
  VerifyPaymentFailure(this.message, {required this.isNetworkError});
}

/// Outcome of WalletController.getLatestPurchase — the last-resort check used
/// after verify-payment retries are exhausted, or on the case the app was
/// killed mid-payment and lost all in-memory order state.
class LatestPurchaseStatus {
  final bool hasPurchase;
  final String? status;
  final DateTime? completedAt;
  LatestPurchaseStatus({required this.hasPurchase, this.status, this.completedAt});

  bool get isSuccess => hasPurchase && status == 'SUCCESS';
}
