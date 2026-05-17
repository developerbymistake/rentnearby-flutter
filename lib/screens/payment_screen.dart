import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../controllers/auth_controller.dart';
import '../controllers/listing_controller.dart';
import '../config/app_colors.dart';
import '../utils/app_toast.dart';
import '../widgets/payment_success_dialog.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Razorpay _razorpay;
  bool _isLoading = false;
  Map<String, dynamic>? _order;
  String? _error;

  late String _listingId;
  late String _planType;

  @override
  void initState() {
    super.initState();

    // Extract route arguments
    final args = Get.arguments as Map<String, dynamic>?;
    _listingId = args?['listingId'] as String? ?? '';
    _planType = args?['planType'] as String? ?? 'FREE';

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    _createOrder();
  }

  Future<void> _createOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final listingCtrl = Get.find<ListingController>();
      final response = await listingCtrl.createPaymentOrder(_listingId, _planType);

      if (!mounted) return;

      final orderId = response['orderId'] as String?;
      final amount = response['amount'] as int?;
      final currency = response['currency'] as String? ?? 'INR';
      final keyId = response['keyId'] as String?;

      if (orderId == null || orderId.isEmpty) {
        setState(() => _error = 'Invalid order from server');
        return;
      }

      // For FREE plan: order creation auto-activates on backend
      if (_planType == 'FREE') {
        if (mounted) {
          Get.find<ListingController>().listingPostedTrigger.value++;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => PaymentSuccessDialog(
              planType: 'FREE',
              daysValid: 2,
              maxRooms: 1,
              onDismiss: () => Get.back(),
            ),
          );
        }
        return;
      }

      // For PAID plan: prepare Razorpay order details
      if (keyId == null || keyId.isEmpty) {
        setState(() => _error = 'Payment key not available from server');
        return;
      }

      setState(() {
        _order = {
          'orderId': orderId,
          'amount': amount ?? 0,
          'currency': currency,
          'keyId': keyId,
        };
      });
    } catch (e) {
      setState(() => _error = 'Could not create payment order: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatPhone(String raw) {
    final clean = raw.replaceAll(RegExp(r'[\s+\-()]'), '');
    if (clean.length == 10) return '+91$clean';
    if (clean.length == 12 && clean.startsWith('91')) return '+$clean';
    return raw;
  }

  void _openRazorpay() {
    if (_order == null) return;

    final rawPhone = Get.find<AuthController>().user.value?.phoneNumber ?? '';
    final options = {
      'key': _order!['keyId'],
      'amount': (_order!['amount'] as int) * 100,
      'currency': _order!['currency'],
      'order_id': _order!['orderId'],
      'name': 'Bakhli',
      'description': 'Premium Plan - 30 days, 2 rooms',
      'prefill': {
        'contact': _formatPhone(rawPhone),
      },
      'theme': {
        'color': '#3399cc',
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      AppToast.error('Failed to open payment form: $e');
    }
  }

  void _onSuccess(PaymentSuccessResponse response) async {
    try {
      final orderId = response.orderId;
      final paymentId = response.paymentId;
      final signature = response.signature;

      if (orderId == null || orderId.isEmpty) {
        throw Exception('Invalid order ID from payment gateway');
      }
      if (paymentId == null || paymentId.isEmpty) {
        throw Exception('Invalid payment ID from payment gateway');
      }
      if (signature == null || signature.isEmpty) {
        throw Exception('Invalid signature from payment gateway');
      }

      final listingCtrl = Get.find<ListingController>();
      await listingCtrl.verifyPayment(
        listingId: _listingId,
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => PaymentSuccessDialog(
            planType: 'PAID',
            daysValid: 30,
            maxRooms: 2,
            onDismiss: () => Get.back(),
          ),
        );
      }
    } catch (e) {
      AppToast.error('Payment verification failed: $e');
    }
  }

  void _onError(PaymentFailureResponse response) {
    if (response.code == Razorpay.PAYMENT_CANCELLED) return;
    AppToast.error('Payment failed. Please try again.');
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    AppToast.info('External wallet: ${response.walletName}');
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Complete Payment',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.payment_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _planType == 'FREE' ? 'Activating FREE Plan' : 'Payment Required',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _planType == 'FREE'
                    ? 'Your room will be live for 2 days with 1 room limit.'
                    : 'Complete payment to activate your listing for 30 days with 2 room limit.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontFamily: 'Poppins',
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _createOrder,
                  child: const Text('Retry'),
                ),
              ] else if (_planType == 'FREE') ...[
                const SizedBox(height: 40),
              ] else if (_order != null) ...[
                Text(
                  '₹${_order!['amount']}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _openRazorpay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Pay Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  _planType == 'FREE' ? 'Back to listings' : 'Cancel payment',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
