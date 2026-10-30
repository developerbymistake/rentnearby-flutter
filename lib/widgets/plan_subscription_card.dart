import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/plan_controller.dart';
import '../models/my_plan_model.dart';

class PlanStateCopy {
  const PlanStateCopy._();

  static String date(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  static bool autoRenews(MyPlanModel me) {
    final p = me.play;
    return p != null && p.ownsActivePlan && p.renewsAutomatically;
  }

  static bool blocksPurchase(MyPlanModel me) {
    final p = me.play;
    return p != null && (p.onHold || p.paused);
  }

  static bool _showsEnded(MyPlanModel me) {
    final p = me.play;
    return p != null && p.ended && !me.hasPaidPlan;
  }

  static bool opensManage(MyPlanModel me) {
    final p = me.play;
    if (p == null) return false;
    return p.needsFix || (p.ownsActivePlan && !p.renewsAutomatically && me.hasPaidPlan);
  }

  static String? status(MyPlanModel me) {
    final p = me.play;
    if (p != null) {
      if (p.inGrace) return 'Payment issue';
      if (p.onHold) return 'Payment on hold';
      if (p.paused) return 'Paused';
      if (p.ownsActivePlan) {
        final at = p.expiryAt ?? me.endsAt;
        if (at != null) return p.renewsAutomatically ? 'Renews on ${date(at)}' : 'Ends on ${date(at)}';
      }
      if (_showsEnded(me)) return 'Subscription ended';
    }
    if (p != null && p.ownsActivePlan) return null;
    return me.hasPaidPlan && me.daysLeft != null ? '${me.daysLeft} days left' : null;
  }

  static String action(MyPlanModel me) {
    final p = me.play;
    if (p != null) {
      if (p.needsFix) return p.paused ? 'Resume' : 'Fix';
      if (p.ownsActivePlan) return p.renewsAutomatically ? 'Manage' : 'Resubscribe';
      if (_showsEnded(me)) return 'Resubscribe';
    }
    return me.hasPaidPlan ? 'Renew' : 'Subscribe';
  }

  static String pausedTitle(MyPlanModel me) {
    final p = me.play;
    if (p != null && p.needsFix) return status(me) ?? 'Payment issue';
    return p != null && p.ended ? 'Subscription ended' : 'Paused by plan';
  }

  static String pausedAction(MyPlanModel me) {
    final p = me.play;
    if (p != null && p.needsFix) return p.paused ? 'Resume' : 'Fix';
    if (p != null && p.ended) return 'Resubscribe';
    return me.hasPaidPlan ? 'Renew' : 'Subscribe';
  }

  static void openFor(MyPlanModel me) {
    if (opensManage(me)) {
      Get.find<PlanController>().openManageSubscription();
    } else {
      Get.toNamed(AppRoutes.plansBilling);
    }
  }

  static void openPausedAction(MyPlanModel me) {
    final p = me.play;
    if (p != null && p.needsFix) {
      Get.find<PlanController>().openManageSubscription();
    } else {
      Get.toNamed(AppRoutes.plansBilling);
    }
  }
}

class PlanSubscriptionCard extends StatelessWidget {
  final MyPlanModel me;
  final Color accent;
  final VoidCallback? onResubscribe;

  const PlanSubscriptionCard({super.key, required this.me, required this.accent, this.onResubscribe});

  @override
  Widget build(BuildContext context) {
    final p = me.play;
    if (p == null) return const SizedBox.shrink();
    final view = _view(p);
    if (view == null) return const SizedBox.shrink();
    final (title, body, action, viaManage) = view;
    final plans = Get.find<PlanController>();
    final warn = p.needsFix;
    final tone = warn ? AppColors.warning : accent;
    final scheduled = p.scheduledPlanName != null && p.scheduledAt != null
        ? 'Changes to ${p.scheduledPlanName} on ${PlanStateCopy.date(p.scheduledAt!)}'
        : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warn ? AppColors.warningSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(p.ownsActivePlan ? me.planName : 'Subscription',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          ),
          if (p.inTrial) _pill('Trial', accent),
          if (p.isTest) ...[const SizedBox(width: 6), _pill('Test', AppColors.textLight)],
        ]),
        const SizedBox(height: 2),
        Text(title,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: warn ? AppColors.warningText : AppColors.textDark)),
        if (body != null)
          Text(body,
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 12, color: warn ? AppColors.warningText : AppColors.textLight)),
        if (scheduled != null) ...[
          const SizedBox(height: 8),
          _note(Icons.swap_horiz_rounded, scheduled),
        ],
        if (me.carryOverDays > 0) ...[
          const SizedBox(height: 8),
          _note(Icons.add_circle_outline_rounded, '+${me.carryOverDays} days after subscription'),
        ],
        const SizedBox(height: 12),
        Row(children: [
          if (action != null)
            ElevatedButton(
              onPressed: viaManage ? plans.openManageSubscription : onResubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: tone,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(action, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          if (action != null) const SizedBox(width: 8),
          TextButton(
            onPressed: plans.openManageSubscription,
            child: Text('Manage in Google Play',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12, color: tone)),
          ),
        ]),
        const Text('Use the Google account you subscribed with.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textHint)),
      ]),
    );
  }

  (String, String?, String?, bool)? _view(PlaySubInfo p) {
    final at = p.expiryAt ?? me.endsAt;
    if (p.inGrace) {
      return ('Payment issue', 'Update your payment method to keep your plan.', 'Fix', true);
    }
    if (p.onHold) {
      return ('Payment on hold', 'Fix the payment in Google Play to continue.', 'Fix', true);
    }
    if (p.paused) {
      final r = p.pausedAutoResumeAt;
      return ('Paused', r != null ? 'Resumes on ${PlanStateCopy.date(r)}' : 'Resume it in Google Play.', 'Resume', true);
    }
    if (p.ownsActivePlan) {
      if (!p.renewsAutomatically) {
        return (at != null ? 'Ends on ${PlanStateCopy.date(at)}' : 'Ending soon', 'Auto-renew is off.', 'Resubscribe', true);
      }
      if (p.inTrial) {
        return ('Trial ends on ${PlanStateCopy.date(p.trialEndsAt!.toLocal())}', 'Then it renews. Cancel anytime in Google Play.', null, true);
      }
      return (at != null ? 'Renews on ${PlanStateCopy.date(at)}' : 'Renews automatically', null, null, true);
    }
    if (p.ended) {
      return ('Subscription ended', at != null ? 'Ended on ${PlanStateCopy.date(at)}' : null, 'Resubscribe', false);
    }
    return null;
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _note(IconData icon, String text) => Row(children: [
        Icon(icon, size: 15, color: accent),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium))),
      ]);
}
