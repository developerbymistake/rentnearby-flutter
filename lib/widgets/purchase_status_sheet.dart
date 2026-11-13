import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_plans.dart';
import '../controllers/plan_controller.dart';
import '../utils/app_toast.dart';
import 'plan_subscription_card.dart';

class PurchaseStatusSheet extends StatefulWidget {
  final Color accent;
  final ListingTone? tone;
  const PurchaseStatusSheet({super.key, required this.accent, this.tone});

  @override
  State<PurchaseStatusSheet> createState() => _PurchaseStatusSheetState();
}

class _PurchaseStatusSheetState extends State<PurchaseStatusSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(duration: const Duration(milliseconds: 1200), vsync: this, value: 0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KitMotion.reduce(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plans = Get.find<PlanController>();
    const d = 'assets/images/design/travel3d/';
    const good = PlanInk.statusGood;
    const bad = PlanInk.statusBad;
    const warn = PlanInk.statusWarn;
    const grey = PlanInk.statusGrey;
    final tone = widget.tone ?? PlanLook.toneOf(plans.myPlan.value.featureKey);
    return PopScope(
      canPop: false,
      child: Obx(() {
            final s = plans.activePurchase.value;
            final timedOut = plans.pollTimedOut.value;
            if (s == null) {
              return PlanCloseSheet3D(tone: tone, onClose: () => Navigator.pop(context));
            }
            final waiting = s.isOpen && !timedOut;
            final String asset;
            final Color color;
            final String title;
            final String body;
            if (s.isGranted) {
              asset = '${d}star.png';
              color = good;
              title = 'Plan active';
              body = s.endsAt != null ? '${s.planName} is active till ${PlanStateCopy.date(s.endsAt!)}.' : '${s.planName} is active.';
            } else if (s.status == 'VerifyFailed') {
              asset = '${d}clipboard.png';
              color = bad;
              title = 'Could not verify';
              body = 'If money was taken, your plan activates soon.';
            } else if (s.status == 'Failed') {
              asset = '${d}money_bag.png';
              color = bad;
              title = 'Payment failed';
              body = s.failureReason ?? 'No money was taken. Try again.';
            } else if (s.status == 'Expired') {
              asset = '${d}calendar.png';
              color = grey;
              title = 'Order expired';
              body = 'Please start again.';
            } else if (s.status == 'Refunded') {
              asset = '${d}money_bag.png';
              color = grey;
              title = 'Payment refunded';
              body = 'Your money is on its way back.';
            } else if (s.status == 'StoreUnavailable') {
              asset = '${d}world_map.png';
              color = warn;
              title = 'Google Play unavailable';
              body = 'Try again.';
            } else if (s.status == 'OtherAccount') {
              asset = '${d}key.png';
              color = warn;
              title = 'Already subscribed';
              body = 'This Google account has a subscription on another Bakhli account.';
            } else if (s.status == 'Detached') {
              asset = '${d}pushpin.png';
              color = warn;
              title = 'Subscription closed';
              body = s.endsAt != null
                  ? 'Your old subscription ends on ${PlanStateCopy.date(s.endsAt!)}. Buy again after that.'
                  : 'Your old subscription has ended. Buy again.';
            } else if (s.status == 'Created' && timedOut) {
              asset = '${d}calendar.png';
              color = warn;
              title = 'No payment found';
              body = 'If money was taken, your plan activates soon.';
            } else if (s.isOpen && timedOut) {
              asset = '${d}calendar.png';
              color = warn;
              title = 'Almost there';
              body = 'Plan will activate automatically.';
            } else if (s.isBlocked) {
              asset = '${d}clipboard.png';
              color = warn;
              title = 'Payment on hold';
              body = s.grantBlockedReason == 'AmountMismatch'
                  ? 'Amount did not match. You will be refunded.'
                  : 'Plan could not start. Refund is on its way.';
            } else if (s.isPaid) {
              asset = '${d}money_bag.png';
              color = tone.g2;
              title = 'Activating plan';
              body = 'Payment received.';
            } else if (s.status == 'PlayPending') {
              asset = '${d}money_bag.png';
              color = tone.g2;
              title = 'Waiting for Google Play';
              body = 'Approve the payment in your UPI app.';
            } else if (s.status == 'Restoring') {
              asset = '${d}money_bag.png';
              color = tone.g2;
              title = 'Restoring purchase';
              body = 'Please wait.';
            } else {
              asset = '${d}money_bag.png';
              color = tone.g2;
              title = s.status == 'Created' ? 'Checking payment' : 'Confirming payment';
              body = 'Please wait.';
            }
            return KeyedSubtree(
              key: ValueKey('$title|$body'),
              child: PlanStatusSheet3D(
                tone: tone,
                art: asset,
                status: color,
                title: title,
                body: body,
                waiting: waiting,
                ring: KitMotion.reduce(context) ? null : _pulse,
                onDone: () {
                  if (s.isGranted) AppToast.success('Plan updated.');
                  Navigator.pop(context);
                },
              ),
            );
          }),
    );
  }
}
