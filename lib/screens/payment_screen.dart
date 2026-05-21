import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../controllers/auth_controller.dart';
import '../controllers/listing_controller.dart';
import '../controllers/plot_controller.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
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
  bool _isVerifying = false;
  bool _razorpayOpened = false;
  bool _payNowDisabled = false;
  Map<String, dynamic>? _order;
  String? _error;

  late String _listingId;
  late String _plotId;
  late String _planType;
  late Map<String, dynamic> _plan;
  late bool _isUpgrade;
  late bool _isPlot;

  @override
  void initState() {
    super.initState();

    // Extract route arguments — callers pass 'plan' (full map) + 'listingId' or 'plotId'
    final args = Get.arguments as Map<String, dynamic>?;
    _isPlot = args?['isPlot'] as bool? ?? false;
    _listingId = args?['listingId'] as String? ?? '';
    _plotId = args?['plotId'] as String? ?? '';
    _plan = (args?['plan'] as Map<String, dynamic>?) ?? {};
    _planType = _plan['planType'] as String? ?? args?['planType'] as String? ?? 'PAID';
    _isUpgrade = _isPlot ? _plotId.isEmpty : _listingId.isEmpty;

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    _createOrder();
  }

  Future<void> _createOrder() async {
    _razorpayOpened = false;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Map<String, dynamic>? response;
      if (_isPlot) {
        final plotCtrl = Get.find<PlotController>();
        response = _isUpgrade
            ? await plotCtrl.createPlotUpgradeOrder(_planType)
            : await plotCtrl.activatePlotPlan(_plotId, _planType);
      } else {
        final listingCtrl = Get.find<ListingController>();
        response = _isUpgrade
            ? await listingCtrl.createUpgradeOrder(_planType)
            : await listingCtrl.createPaymentOrder(_listingId, _planType);
      }

      if (!mounted) return;

      if (response == null) {
        setState(() => _error = 'Could not create payment order. Please try again.');
        return;
      }

      final orderId = response['orderId'] as String?;
      final amount = response['amount'] as int?;
      final currency = response['currency'] as String? ?? 'INR';
      final keyId = response['keyId'] as String?;

      if (orderId == null || orderId.isEmpty) {
        setState(() => _error = 'Invalid order from server');
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
    setState(() => _payNowDisabled = true);
    _razorpayOpened = true;

    final rawPhone = Get.find<AuthController>().user.value?.phoneNumber ?? '';
    final options = {
      'key': _order!['keyId'],
      'amount': (_order!['amount'] as int) * 100,
      'currency': _order!['currency'],
      'order_id': _order!['orderId'],
      'name': 'Bakhli',
      'description': _isPlot
          ? '$_planType Plan - ${_plan['days'] ?? 30} days, ${_plan['plotLimit'] ?? 1} plots'
          : '$_planType Plan - ${_plan['days'] ?? 30} days, ${_plan['roomLimit'] ?? 2} rooms',
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
    if (!_razorpayOpened) return;
    if (mounted) setState(() => _isVerifying = true);
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

      if (_isPlot) {
        final plotCtrl = Get.find<PlotController>();
        if (_isUpgrade) {
          await plotCtrl.verifyPlotUpgradePayment({
            'razorpayOrderId': orderId,
            'razorpayPaymentId': paymentId,
            'razorpaySignature': signature,
          });
        } else {
          await plotCtrl.verifyPlotPayment({
            'plotId': _plotId,
            'razorpayOrderId': orderId,
            'razorpayPaymentId': paymentId,
            'razorpaySignature': signature,
          });
        }
      } else {
        final listingCtrl = Get.find<ListingController>();
        if (_isUpgrade) {
          await listingCtrl.verifyUpgradePayment(
            razorpayOrderId: orderId,
            razorpayPaymentId: paymentId,
            razorpaySignature: signature,
          );
        } else {
          await listingCtrl.verifyPayment(
            listingId: _listingId,
            razorpayOrderId: orderId,
            razorpayPaymentId: paymentId,
            razorpaySignature: signature,
          );
        }
      }

      if (mounted) {
        setState(() => _isVerifying = false);
        Get.dialog(
          PaymentSuccessDialog(
            planType: _planType,
            daysValid: (_plan['days'] as num?)?.toInt() ?? 30,
            maxRooms: (_plan['roomLimit'] as num?)?.toInt() ?? 2,
            maxPlots: (_plan['plotLimit'] as num?)?.toInt() ?? 1,
            isPlot: _isPlot,
            onDismiss: () {
              Get.until((route) => route.settings.name == AppRoutes.main);
              Get.find<AuthController>().tabIndex.value = _isPlot ? 3 : 1;
            },
          ),
          barrierDismissible: false,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isVerifying = false);
      AppToast.error('Payment verification failed: $e');
    }
  }

  void _onError(PaymentFailureResponse response) {
    if (!_razorpayOpened) return;
    setState(() => _payNowDisabled = false);
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      setState(() => _error = 'Payment was cancelled. Tap "Pay Now" to try again.');
    } else {
      setState(() => _error = 'Payment failed. Please try again.');
    }
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
        iconTheme: const IconThemeData(color: AppColors.textDark),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Complete Payment',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.textDark,
          ),
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
              const Text(
                'Payment Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _isPlot
                    ? 'Complete payment to activate your plot for ${_plan['days'] ?? 30} days with ${_plan['plotLimit'] ?? 1} plot limit.'
                    : 'Complete payment to activate your listing for ${_plan['days'] ?? 30} days with ${_plan['roomLimit'] ?? 2} room limit.',
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
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textLight),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Non-refundable payment. Amount cannot be returned once processed.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.textLight,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_isVerifying)
                  Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text(
                        'Verifying your payment...',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: AppColors.textMedium,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Please wait, do not close this screen.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _payNowDisabled ? null : _openRazorpay,
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
                child: const Text(
                  'Cancel payment',
                  style: TextStyle(
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
