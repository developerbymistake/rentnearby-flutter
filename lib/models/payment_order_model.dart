class PaymentOrderResponse {
  final String orderId;
  final double amount;
  final String currency;
  final String keyId;

  PaymentOrderResponse({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.keyId,
  });

  factory PaymentOrderResponse.fromJson(Map<String, dynamic> json) =>
      PaymentOrderResponse(
        orderId: json['orderId'] ?? '',
        amount: (json['amount'] ?? 0).toDouble(),
        currency: json['currency'] ?? 'INR',
        keyId: json['keyId'] ?? '',
      );
}
