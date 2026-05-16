import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../controllers/auth_controller.dart';
import '../controllers/listing_controller.dart';
import '../services/razorpay_service.dart';
import '../utils/app_toast.dart';

class PaymentDialog extends StatefulWidget {
  final String listingId;
  final bool hasUsedFreePlan;
  final VoidCallback onPaymentSuccess;

  const PaymentDialog({
    required this.listingId,
    required this.hasUsedFreePlan,
    required this.onPaymentSuccess,
    Key? key,
  }) : super(key: key);

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  bool _isLoading = false;
  late RazorpayPaymentService _razorpayService;

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayPaymentService();
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Make Room Live',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
                GestureDetector(
                  onTap: () => _isLoading ? null : Navigator.pop(context),
                  child: Icon(
                    Icons.close,
                    size: 24,
                    color: _isLoading ? Colors.grey[300] : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a plan to activate your listing',
              style: TextStyle(fontSize: 13, color: Colors.grey[600], fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 24),
            if (!widget.hasUsedFreePlan)
              _buildPlanButton(
                title: 'Free Plan',
                subtitle: '10 days • 1 room',
                price: '₹0',
                icon: Icons.star_rounded,
                color: const Color(0xFF10B981),
                isLoading: _isLoading,
                onTap: _activateFreePlan,
              ),
            if (!widget.hasUsedFreePlan) const SizedBox(height: 12),
            _buildPlanButton(
              title: 'Premium Plan',
              subtitle: '30 days • 2 rooms',
              price: '₹99',
              icon: Icons.flash_on_rounded,
              color: const Color(0xFF3B82F6),
              isLoading: _isLoading,
              onTap: _initiatePaidPayment,
              isHighlighted: widget.hasUsedFreePlan,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanButton({
    required String title,
    required String subtitle,
    required String price,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return Material(
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isHighlighted ? color : color.withOpacity(0.3),
              width: isHighlighted ? 2 : 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isHighlighted ? color.withOpacity(0.05) : Colors.grey[50],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(width: 8),
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(Icons.arrow_forward_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _activateFreePlan() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final listingCtrl = Get.find<ListingController>();
      await listingCtrl.activateFreePlan(widget.listingId);
      if (mounted) Navigator.pop(context);
      widget.onPaymentSuccess();
      AppToast.success('Room is now LIVE! 🎉');
    } catch (e) {
      AppToast.error('Could not activate plan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initiatePaidPayment() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final listingCtrl = Get.find<ListingController>();
      final authCtrl = Get.find<AuthController>();

      final res = await listingCtrl.initiatePaidPayment(widget.listingId);
      if (!mounted) return;

      // Validate response (Issue 3: Null checks)
      final orderId = res['razorpayOrderId'] as String?;
      final amount = res['amount'] as int?;

      if (orderId == null || orderId.isEmpty) {
        throw Exception('Invalid order ID from server');
      }
      if (amount == null || amount <= 0) {
        throw Exception('Invalid amount from server');
      }

      final user = authCtrl.user.value;
      if (user == null) {
        throw Exception('User not found');
      }

      if (user.email == null || user.email!.isEmpty) {
        throw Exception('User email is required for payment');
      }
      if (user.phone == null || user.phone!.isEmpty) {
        throw Exception('User phone is required for payment');
      }

      // Set up callbacks BEFORE opening payment (Issue 2: Handle cancel)
      _razorpayService.setCallbacks(
        (PaymentSuccessResponse response) {
          _handlePaymentSuccess(response);
        },
        (PaymentFailureResponse response) {
          _handlePaymentFailure(response);
        },
        onCancel: () {
          _handlePaymentCancel();
        },
      );

      // Open Razorpay payment form (keep dialog open for error handling)
      try {
        _razorpayService.initiatePayment(
          orderId: orderId,
          amount: amount,
          email: user.email!,
          phone: user.phone!,
          description: 'Premium Plan - 30 days, 2 rooms',
        );
        // Close dialog only AFTER Razorpay opens successfully
        if (mounted) Navigator.pop(context);
      } catch (razorpayError) {
        throw Exception('Failed to open payment form: $razorpayError');
      }
    } catch (e) {
      AppToast.error('Payment Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      // Validate response fields (Issue 3: Null checks)
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
        listingId: widget.listingId,
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
      );
      widget.onPaymentSuccess();
      AppToast.success('Payment successful! Room is now LIVE! 🎉');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      AppToast.error('Payment verification failed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    AppToast.error('Payment failed: ${response.message ?? 'Unknown error'}');
    if (mounted) setState(() => _isLoading = false);
  }

  void _handlePaymentCancel() {
    AppToast.info('Payment cancelled');
    if (mounted) setState(() => _isLoading = false);
  }
}
