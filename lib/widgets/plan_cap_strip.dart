import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../controllers/plan_controller.dart';
import 'plan_badge_chip.dart';
import 'plan_subscription_card.dart';

class PlanCapStrip extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String unitPlural;
  final bool showUsage;

  const PlanCapStrip({
    super.key,
    required this.accent,
    required this.icon,
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
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  showUsage ? '${me.planName} · ${limits.used} / ${limits.listingLimit} $unitPlural' : planLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: accent, fontWeight: FontWeight.w600),
                ),
              ),
              if (!showUsage && limits.featured) ...[
                PlanBadgeChip(color: accent),
                const SizedBox(width: 6),
              ],
              if (canBuy)
                GestureDetector(
                  onTap: () => PlanStateCopy.openFor(me),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
                    child: Text(action,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
            ]),
            if (showUsage && me.play != null && status != null) ...[
              const SizedBox(height: 4),
              Text(
                status,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: me.play!.needsFix ? AppColors.warningText : AppColors.textLight),
              ),
            ],
            if (me.pausedByPlanCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${me.pausedByPlanCount} paused by plan',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.warningText),
              ),
            ],
          ],
        ),
      );
    });
  }
}
