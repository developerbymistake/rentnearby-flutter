import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/plan_controller.dart';
import 'plan_subscription_card.dart';

class PlanLimitReachedSheet {
  static void show(
    BuildContext context, {
    required int limit,
    required String unitSingular,
    required String unitPlural,
    required Color accent,
    bool liveLimit = false,
    VoidCallback? onManage,
    VoidCallback? onSwap,
  }) {
    final plans = Get.find<PlanController>();
    final unit = limit == 1 ? unitSingular : unitPlural;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.lock_outline_rounded, size: 30, color: AppColors.warning),
              ),
              const SizedBox(height: 16),
              Text(
                liveLimit ? 'Live limit reached' : 'Limit reached',
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              Text(
                liveLimit
                    ? 'Your plan keeps $limit $unit live. Pause one or upgrade.'
                    : 'Your plan allows $limit $unit. Delete one or upgrade.',
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Obx(() {
                final canUpgrade = plans.paymentEnabled && plans.hasPlanFeature;
                final me = plans.myPlan.value;
                final fix = PlanStateCopy.blocksPurchase(me);
                return Column(
                  children: [
                    if (canUpgrade)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            if (fix) {
                              plans.openManageSubscription();
                            } else {
                              Get.toNamed(AppRoutes.plansBilling);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(fix ? 'Fix payment' : (me.hasPaidPlan ? 'Upgrade' : 'Subscribe'),
                              style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                        ),
                      ),
                    if (onSwap != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onSwap();
                          },
                          style: _outlined(accent),
                          child: const Text('Swap live listing',
                              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                    if (onManage != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onManage();
                          },
                          style: _outlined(accent),
                          child: const Text('Manage listings',
                              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  static ButtonStyle _outlined(Color accent) => OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent),
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}
