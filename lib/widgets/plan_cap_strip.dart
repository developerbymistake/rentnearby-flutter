import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_stay_owner.dart';
import '../controllers/plan_controller.dart';
import 'plan_badge_chip.dart';
import 'plan_subscription_card.dart';

class PlanCapStrip extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String? iconAsset;
  final String unitPlural;
  final bool showUsage;

  const PlanCapStrip({
    super.key,
    required this.accent,
    required this.icon,
    this.iconAsset,
    this.unitPlural = '',
    this.showUsage = true,
  });

  @override
  Widget build(BuildContext context) {
    final plans = Get.find<PlanController>();
    return Obx(() {
      final me = plans.myPlan.value;
      final limits = me.limits;
      final canBuy = me.paymentEnabled && me.featureKey != null;
      final action = PlanStateCopy.action(me);
      final status = PlanStateCopy.status(me);
      final planLine = status != null && (me.hasPaidPlan || me.play != null) ? '${me.planName} · $status' : me.planName;
      final tone = accent == PickKit.taxi ? ListingTone.coral : (accent == PickKit.stay ? ListingTone.forest : ListingTone.indigo);
      final paused = me.pausedByPlanCount > 0;
      final usageStatus = showUsage && me.play != null && status != null;
      final sub = paused ? '${me.pausedByPlanCount} paused by plan' : (usageStatus ? status : 'Your plan');
      return PlanStrip3D(
        tone: tone,
        art: iconAsset ?? TravelIcon.star,
        title: showUsage ? '${me.planName} · ${limits.used} / ${limits.listingLimit} $unitPlural' : planLine,
        subtitle: sub,
        subtitleColor: paused || (usageStatus && me.play!.needsFix) ? DesignColors.warnDeep : null,
        badge: !showUsage && limits.featured ? PlanBadgeChip(color: accent) : null,
        actionLabel: canBuy ? action : null,
        onAction: canBuy ? () => PlanStateCopy.openFor(me) : null,
      );
    });
  }
}
