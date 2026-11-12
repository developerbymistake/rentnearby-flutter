import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import '../controllers/plan_controller.dart';
import '../utils/app_toast.dart';
import 'plan_subscription_card.dart';

class PurchaseStatusSheet extends StatefulWidget {
  final Color accent;
  const PurchaseStatusSheet({super.key, required this.accent});

  @override
  State<PurchaseStatusSheet> createState() => _PurchaseStatusSheetState();
}

class _PurchaseStatusSheetState extends State<PurchaseStatusSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(duration: const Duration(milliseconds: 1200), vsync: this, value: 1);
  late final Animation<double> _pulseScale = Tween<double>(begin: 0.92, end: 1.0)
      .animate(CurvedAnimation(parent: _pulse, curve: Curves.fastOutSlowIn));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KitMotion.reduce(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _halo(String asset, Color color, bool waiting) {
    final halo = Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(color: color.withValues(alpha: Alpha.tint), shape: BoxShape.circle),
      padding: const EdgeInsets.all(14),
      child: Image.asset(asset),
    );
    if (!waiting) return halo;
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
            width: 92,
            height: 92,
            child: CircularProgressIndicator(strokeWidth: 3, color: color, backgroundColor: color.withValues(alpha: Alpha.v15))),
        ScaleTransition(scale: _pulseScale, child: halo),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final plans = Get.find<PlanController>();
    const d = 'assets/images/design/travel3d/';
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
                  child: const Text('Close',
                      style: TextStyle(
                          fontFamily: FitnessAppTheme.fontName,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: DesignColors.primary)),
                ),
              );
            }
            final waiting = s.isOpen && !timedOut;
            final String asset;
            final Color color;
            final String title;
            final String body;
            if (s.isGranted) {
              asset = '${d}star.png';
              color = RepliesTone.good;
              title = 'Plan active';
              body = s.endsAt != null ? '${s.planName} is active till ${PlanStateCopy.date(s.endsAt!)}.' : '${s.planName} is active.';
            } else if (s.status == 'VerifyFailed') {
              asset = '${d}clipboard.png';
              color = RepliesTone.bad;
              title = 'Could not verify';
              body = 'If money was taken, your plan activates soon.';
            } else if (s.status == 'Failed') {
              asset = 'assets/images/design/fitness_app/burned.png';
              color = RepliesTone.bad;
              title = 'Payment failed';
              body = s.failureReason ?? 'No money was taken. Try again.';
            } else if (s.status == 'Expired') {
              asset = '${d}calendar.png';
              color = DesignColors.textSecondary;
              title = 'Order expired';
              body = 'Please start again.';
            } else if (s.status == 'Refunded') {
              asset = '${d}money_bag.png';
              color = DesignColors.textSecondary;
              title = 'Payment refunded';
              body = 'Your money is on its way back.';
            } else if (s.status == 'StoreUnavailable') {
              asset = '${d}world_map.png';
              color = RepliesTone.warn;
              title = 'Google Play unavailable';
              body = 'Try again.';
            } else if (s.status == 'OtherAccount') {
              asset = '${d}key.png';
              color = RepliesTone.warn;
              title = 'Already subscribed';
              body = 'This Google account has a subscription on another Bakhli account.';
            } else if (s.status == 'Detached') {
              asset = '${d}pushpin.png';
              color = RepliesTone.warn;
              title = 'Subscription closed';
              body = s.endsAt != null
                  ? 'Your old subscription ends on ${PlanStateCopy.date(s.endsAt!)}. Buy again after that.'
                  : 'Your old subscription has ended. Buy again.';
            } else if (s.status == 'Created' && timedOut) {
              asset = '${d}calendar.png';
              color = RepliesTone.warn;
              title = 'No payment found';
              body = 'If money was taken, your plan activates soon.';
            } else if (s.isOpen && timedOut) {
              asset = '${d}calendar.png';
              color = RepliesTone.warn;
              title = 'Almost there';
              body = 'Plan will activate automatically.';
            } else if (s.isBlocked) {
              asset = '${d}clipboard.png';
              color = RepliesTone.warn;
              title = 'Payment on hold';
              body = s.grantBlockedReason == 'AmountMismatch'
                  ? 'Amount did not match. You will be refunded.'
                  : 'Plan could not start. Refund is on its way.';
            } else if (s.isPaid) {
              asset = '${d}money_bag.png';
              color = accent;
              title = 'Activating plan';
              body = 'Payment received.';
            } else if (s.status == 'PlayPending') {
              asset = '${d}money_bag.png';
              color = accent;
              title = 'Waiting for Google Play';
              body = 'Approve the payment in your UPI app.';
            } else if (s.status == 'Restoring') {
              asset = '${d}money_bag.png';
              color = accent;
              title = 'Restoring purchase';
              body = 'Please wait.';
            } else {
              asset = '${d}money_bag.png';
              color = accent;
              title = s.status == 'Created' ? 'Checking payment' : 'Confirming payment';
              body = 'Please wait.';
            }
            return RepliesEntrance(
              key: ValueKey('$title|$body'),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _halo(asset, color, waiting),
                const SizedBox(height: 16),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: DesignColors.textStrong)),
                const SizedBox(height: 4),
                Text(body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: DesignColors.textSecondary)),
                const SizedBox(height: 20),
                if (!waiting)
                  SizedBox(
                    width: double.infinity,
                    child: RepliesButton(
                      label: 'Done',
                      color: accent,
                      onPressed: () {
                        if (s.isGranted) AppToast.success('Plan updated.');
                        Navigator.pop(context);
                      },
                    ),
                  ),
              ]),
            );
          }),
        ),
      ),
    );
  }
}
