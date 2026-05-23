import 'package:razorpay_flutter/razorpay_flutter.dart';

typedef PaymentSuccessCallback = void Function(PaymentSuccessResponse);
typedef PaymentFailureCallback = void Function(PaymentFailureResponse);
class RazorpayPaymentService {
  late Razorpay _razorpay;
  late PaymentSuccessCallback _onSuccess;
  late PaymentFailureCallback _onFailure;

  RazorpayPaymentService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Can be used for analytics or future handling if needed
  }

  void setCallbacks(
    PaymentSuccessCallback onSuccess,
    PaymentFailureCallback onFailure,
  ) {
    _onSuccess = onSuccess;
    _onFailure = onFailure;
  }

  void initiatePayment({
    required String orderId,
    required int amount,
    required String phone,
    required String description,
    required String keyId,
  }) {
    var options = {
      'key': keyId,
      'order_id': orderId,
      'amount': amount * 100,
      'name': 'RentNearBy',
      'description': description,
      'prefill': {
        'contact': phone,
      },
      'theme': {
        'color': '#3399cc',
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      rethrow;
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _onSuccess(response);
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    _onFailure(response);
  }

  void dispose() {
    _razorpay.clear();
  }
}
