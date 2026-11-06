import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_wizard_controller.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';

class TripBackToStepBar extends StatelessWidget {
  final String fromStep;

  const TripBackToStepBar({super.key, required this.fromStep});

  static void backToPlan() => Get.until((route) => route.settings.name == AppRoutes.tripPlan || route.isFirst);

  static void backToStep() => Get.until((route) =>
      route.settings.name == AppRoutes.tripStep || route.settings.name == AppRoutes.tripPlan || route.isFirst);

  static void back(String? fromStep) {
    if (fromStep == null) {
      backToPlan();
      return;
    }
    backToStep();
    final tripId = Get.isRegistered<TripPlanController>() ? TripPlanController.to.trip.value?.id : null;
    if (tripId != null && Get.currentRoute == AppRoutes.tripStep) TripWizardController.onTop(tripId)?.openKey(fromStep);
  }

  static String backLabel(String? fromStep) => fromStep != null ? TripStrings.backToStep : TripStrings.backToPlan;

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final steps = c.wizardSteps;
      final i = steps.indexWhere((s) => s.key.id == fromStep);
      final text = i < 0 ? TripStrings.backToStep : TripStrings.stepOf(i + 1, steps.length, steps[i].title);
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Iconsax.task_square, size: 16, color: TripColors.accentDark),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
            ),
            TextButton(
              onPressed: () => back(fromStep),
              style: TextButton.styleFrom(minimumSize: const Size(44, 40), padding: const EdgeInsets.symmetric(horizontal: 10)),
              child: const Text(TripStrings.backToStep,
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TripColors.accentDark)),
            ),
          ],
        ),
      );
    });
  }
}
