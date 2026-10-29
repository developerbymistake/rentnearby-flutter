class PlanQuote {
  final String planId;
  final String planName;
  final int cycleMonths;
  final String intent;
  final int listPriceInr;
  final int discountInr;
  final int creditInr;
  final int payableInr;
  final int grantedDays;
  final bool requiresPayment;
  final String? couponCode;
  final bool autoCoupon;

  const PlanQuote({
    required this.planId,
    required this.planName,
    required this.cycleMonths,
    required this.intent,
    required this.listPriceInr,
    required this.discountInr,
    required this.creditInr,
    required this.payableInr,
    required this.grantedDays,
    required this.requiresPayment,
    required this.couponCode,
    required this.autoCoupon,
  });

  factory PlanQuote.fromJson(Map<String, dynamic> j) => PlanQuote(
        planId: j['planId'] as String? ?? '',
        planName: j['planName'] as String? ?? '',
        cycleMonths: (j['cycleMonths'] as num?)?.toInt() ?? 1,
        intent: j['intent'] as String? ?? 'New',
        listPriceInr: (j['listPriceInr'] as num?)?.toInt() ?? 0,
        discountInr: (j['discountInr'] as num?)?.toInt() ?? 0,
        creditInr: (j['creditInr'] as num?)?.toInt() ?? 0,
        payableInr: (j['payableInr'] as num?)?.toInt() ?? 0,
        grantedDays: (j['grantedDays'] as num?)?.toInt() ?? 0,
        requiresPayment: j['requiresPayment'] != false,
        couponCode: (j['coupon'] as Map<String, dynamic>?)?['code'] as String?,
        autoCoupon: j['autoCoupon'] == true,
      );
}

sealed class QuoteResult {}

class QuoteSuccess extends QuoteResult {
  final PlanQuote quote;
  QuoteSuccess(this.quote);
}

class QuoteFailure extends QuoteResult {
  final String message;
  final String? errorType;
  QuoteFailure(this.message, {this.errorType});
}

class PlanOrder {
  final String purchaseId;
  final String status;
  final bool requiresPayment;
  final String? razorpayOrderId;
  final String? keyId;
  final int amountPaise;
  final String currency;
  final DateTime? expiresAt;
  final String planName;
  final int grantedDays;

  const PlanOrder({
    required this.purchaseId,
    required this.status,
    required this.requiresPayment,
    required this.razorpayOrderId,
    required this.keyId,
    required this.amountPaise,
    required this.currency,
    required this.expiresAt,
    required this.planName,
    required this.grantedDays,
  });

  factory PlanOrder.fromJson(Map<String, dynamic> j) => PlanOrder(
        purchaseId: j['purchaseId'] as String,
        status: j['status'] as String? ?? '',
        requiresPayment: j['requiresPayment'] != false,
        razorpayOrderId: j['razorpayOrderId'] as String?,
        keyId: j['keyId'] as String?,
        amountPaise: (j['amountPaise'] as num?)?.toInt() ?? 0,
        currency: j['currency'] as String? ?? 'INR',
        expiresAt: j['expiresAt'] != null ? DateTime.tryParse(j['expiresAt'] as String) : null,
        planName: j['planName'] as String? ?? '',
        grantedDays: (j['grantedDays'] as num?)?.toInt() ?? 0,
      );
}

sealed class CreateOrderResult {}

class CreateOrderSuccess extends CreateOrderResult {
  final PlanOrder order;
  CreateOrderSuccess(this.order);
}

class CreateOrderFailure extends CreateOrderResult {
  final String message;
  final String? errorType;
  CreateOrderFailure(this.message, {this.errorType});
}

class PurchaseStatus {
  final String purchaseId;
  final String status;
  final String planName;
  final int grantedDays;
  final DateTime? endsAt;
  final String? failureReason;

  const PurchaseStatus({
    required this.purchaseId,
    required this.status,
    required this.planName,
    required this.grantedDays,
    required this.endsAt,
    required this.failureReason,
  });

  bool get isGranted => status == 'Granted';
  bool get isWaiting => status == 'Created' || status == 'Pending';
  bool get isPaid => status == 'Paid';
  bool get isOpen => isWaiting || isPaid;

  factory PurchaseStatus.fromJson(Map<String, dynamic> j) => PurchaseStatus(
        purchaseId: j['purchaseId'] as String,
        status: j['status'] as String? ?? '',
        planName: j['planName'] as String? ?? '',
        grantedDays: (j['grantedDays'] as num?)?.toInt() ?? 0,
        endsAt: j['endsAt'] != null ? DateTime.tryParse(j['endsAt'] as String)?.toLocal() : null,
        failureReason: j['failureReason'] as String?,
      );
}

sealed class VerifyPaymentResult {}

class VerifyPaymentSuccess extends VerifyPaymentResult {
  final PurchaseStatus status;
  VerifyPaymentSuccess(this.status);
}

class VerifyPaymentFailure extends VerifyPaymentResult {
  final String message;
  final bool isNetworkError;
  VerifyPaymentFailure(this.message, {required this.isNetworkError});
}

class PurchaseHistoryItem {
  final String id;
  final String planName;
  final int? cycleMonths;
  final int payableInr;
  final String status;
  final DateTime createdAt;
  final DateTime? grantedAt;

  const PurchaseHistoryItem({
    required this.id,
    required this.planName,
    required this.cycleMonths,
    required this.payableInr,
    required this.status,
    required this.createdAt,
    required this.grantedAt,
  });

  factory PurchaseHistoryItem.fromJson(Map<String, dynamic> j) => PurchaseHistoryItem(
        id: j['id'] as String,
        planName: j['planName'] as String? ?? '',
        cycleMonths: (j['cycleMonths'] as num?)?.toInt(),
        payableInr: (j['payableInr'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        grantedAt: j['grantedAt'] != null ? DateTime.tryParse(j['grantedAt'] as String)?.toLocal() : null,
      );
}
