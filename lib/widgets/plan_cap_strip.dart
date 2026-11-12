import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
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
      final tone = KitTone.solid(accent);
      return Container(
        margin: const EdgeInsets.fromLTRB(KitMetrics.gutter, 12, KitMetrics.gutter, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: CardRadius.tile,
          boxShadow: ShadowTokens.elev1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: DesignColors.tint(accent, Alpha.tint)),
                child: Image.asset(iconAsset ?? TravelIcon.star),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  showUsage ? '${me.planName} · ${limits.used} / ${limits.listingLimit} $unitPlural' : planLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeTokens.style(12, FontWeight.w600, color: DesignColors.textStrong, letterSpacing: 0.2),
                ),
              ),
              if (!showUsage && limits.featured) ...[
                PlanBadgeChip(color: accent),
                const SizedBox(width: 6),
              ],
              if (canBuy) PillAction(label: action, filled: true, tone: tone, height: 32, onTap: () => PlanStateCopy.openFor(me)),
            ]),
            if (showUsage && me.play != null && status != null) ...[
              const SizedBox(height: 4),
              Text(
                status,
                style: TypeTokens.style(11, FontWeight.w500,
                    color: me.play!.needsFix ? DesignColors.warnDeep : TypeTokens.secondary),
              ),
            ],
            if (me.pausedByPlanCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${me.pausedByPlanCount} paused by plan',
                style: TypeTokens.style(11, FontWeight.w500, color: DesignColors.warnDeep),
              ),
            ],
          ],
        ),
      );
    });
  }
}
