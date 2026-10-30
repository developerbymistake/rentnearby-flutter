import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../controllers/plan_controller.dart';
import '../utils/app_toast.dart';
import 'plan_subscription_card.dart';

class PurchaseStatusSheet extends StatelessWidget {
  final Color accent;
  const PurchaseStatusSheet({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    final plans = Get.find<PlanController>();
    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Obx(() {
            final s = plans.activePurchase.value;
            final timedOut = plans.pollTimedOut.value;
            if (s == null) {
              return SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              );
            }
            final waiting = s.isOpen && !timedOut;
            final IconData icon;
            final Color color;
            final String title;
            final String body;
            if (s.isGranted) {
              icon = Icons.check_circle_rounded;
              color = AppColors.success;
              title = 'Plan active';
              body = s.endsAt != null ? '${s.planName} is active till ${PlanStateCopy.date(s.endsAt!)}.' : '${s.planName} is active.';
            } else if (s.status == 'VerifyFailed') {
              icon = Icons.error_outline_rounded;
              color = AppColors.error;
              title = 'Could not verify';
              body = 'If money was taken, your plan activates soon.';
            } else if (s.status == 'Failed') {
              icon = Icons.error_rounded;
              color = AppColors.error;
              title = 'Payment failed';
              body = s.failureReason ?? 'No money was taken. Try again.';
            } else if (s.status == 'Expired') {
              icon = Icons.timer_off_rounded;
              color = AppColors.textLight;
              title = 'Order expired';
              body = 'Please start again.';
            } else if (s.status == 'Refunded') {
              icon = Icons.undo_rounded;
              color = AppColors.textLight;
              title = 'Payment refunded';
              body = 'Your money is on its way back.';
            } else if (s.status == 'StoreUnavailable') {
              icon = Icons.cloud_off_rounded;
              color = AppColors.warning;
              title = 'Google Play unavailable';
              body = 'Try again.';
            } else if (s.status == 'OtherAccount') {
              icon = Icons.info_outline_rounded;
              color = AppColors.warning;
              title = 'Already subscribed';
              body = 'This Google account has a subscription on another Bakhli account.';
            } else if (s.status == 'Detached') {
              icon = Icons.info_outline_rounded;
              color = AppColors.warning;
              title = 'Subscription closed';
              body = s.endsAt != null
                  ? 'Your old subscription ends on ${PlanStateCopy.date(s.endsAt!)}. Buy again after that.'
                  : 'Your old subscription has ended. Buy again.';
            } else if (s.status == 'Created' && timedOut) {
              icon = Icons.hourglass_bottom_rounded;
              color = AppColors.warning;
              title = 'No payment found';
              body = 'If money was taken, your plan activates soon.';
            } else if (s.isOpen && timedOut) {
              icon = Icons.hourglass_bottom_rounded;
              color = AppColors.warning;
              title = 'Almost there';
              body = 'Plan will activate automatically.';
            } else if (s.isBlocked) {
              icon = Icons.error_outline_rounded;
              color = AppColors.warning;
              title = 'Payment on hold';
              body = s.grantBlockedReason == 'AmountMismatch'
                  ? 'Amount did not match. You will be refunded.'
                  : 'Plan could not start. Refund is on its way.';
            } else if (s.isPaid) {
              icon = Icons.autorenew_rounded;
              color = accent;
              title = 'Activating plan';
              body = 'Payment received.';
            } else if (s.status == 'PlayPending') {
              icon = Icons.hourglass_top_rounded;
              color = accent;
              title = 'Waiting for Google Play';
              body = 'Approve the payment in your UPI app.';
            } else if (s.status == 'Restoring') {
              icon = Icons.hourglass_top_rounded;
              color = accent;
              title = 'Restoring purchase';
              body = 'Please wait.';
            } else {
              icon = Icons.hourglass_top_rounded;
              color = accent;
              title = s.status == 'Created' ? 'Checking payment' : 'Confirming payment';
              body = 'Please wait.';
            }
            return Column(mainAxisSize: MainAxisSize.min, children: [
              waiting
                  ? SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 3, color: accent))
                  : Icon(icon, size: 56, color: color),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
              const SizedBox(height: 20),
              if (!waiting)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (s.isGranted) AppToast.success('Plan updated.');
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Done', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
                  ),
                ),
            ]);
          }),
        ),
      ),
    );
  }
}
