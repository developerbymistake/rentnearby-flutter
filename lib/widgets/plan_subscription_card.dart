import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
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
    final toneColor = warn ? DesignColors.warnDeep : accent;
    final tone = KitTone.solid(toneColor);
    final scheduled = p.scheduledPlanName != null && p.scheduledAt != null
        ? 'Changes to ${p.scheduledPlanName} on ${PlanStateCopy.date(p.scheduledAt!)}'
        : null;
    return Container(
      decoration: BoxDecoration(
        color: warn ? Color.alphaBlend(RepliesTone.warnSurface, DesignColors.surface) : DesignColors.surface,
        borderRadius: CardRadius.tile,
        boxShadow: warn ? ShadowTokens.elev3 : ShadowTokens.elev2,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(p.ownsActivePlan ? me.planName : 'Subscription',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeTokens.style(12, FontWeight.w600, color: TypeTokens.secondary)),
          ),
          if (p.inTrial) _pill('Trial', accent),
          if (p.isTest) ...[const SizedBox(width: 6), _pill('Test', DesignColors.textSecondary)],
        ]),
        const SizedBox(height: 2),
        Text(title,
            style: TypeTokens.style(16, FontWeight.w700,
                color: warn ? DesignColors.warnDeep : DesignColors.textStrong, letterSpacing: 0.2)),
        if (body != null)
          Text(body,
              style: TypeTokens.style(12, FontWeight.w500,
                  color: warn ? DesignColors.warnDeep : DesignColors.textGrey)),
        if (scheduled != null) ...[
          const SizedBox(height: 8),
          _note(TravelIcon.calendar, scheduled),
        ],
        if (me.carryOverDays > 0) ...[
          const SizedBox(height: 8),
          _note(TravelIcon.money, '+${me.carryOverDays} days after subscription'),
        ],
        const SizedBox(height: 12),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
          if (action != null)
            PillAction(
              label: action,
              filled: true,
              tone: tone,
              onTap: viaManage ? plans.openManageSubscription : onResubscribe,
            ),
          TextLink(
            label: 'Manage in Google Play',
            tone: tone,
            onTap: plans.openManageSubscription,
          ),
        ]),
        Text('Use the Google account you subscribed with.',
            style: TypeTokens.style(11, FontWeight.w500, color: DesignColors.textMuted)),
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
        decoration: BoxDecoration(color: DesignColors.tint(color, Alpha.tint), borderRadius: CardRadius.pill),
        child: Text(text, style: TypeTokens.style(11, FontWeight.w600, color: color)),
      );

  Widget _note(String asset, String text) => Row(children: [
        TravelIcon(asset, size: 16),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TypeTokens.style(12, FontWeight.w500, color: DesignColors.textGrey))),
      ]);
}
