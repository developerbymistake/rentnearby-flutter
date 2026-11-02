import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/tab_config_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';

enum TripSupplyKind { taxi, stay }

class TripTaxiStayToggle extends StatelessWidget {
  final TripSupplyKind selected;
  final int day;

  const TripTaxiStayToggle({super.key, required this.selected, required this.day});

  void _switchTo(TripSupplyKind kind) {
    if (kind == selected) return;
    Get.offNamed(kind == TripSupplyKind.taxi ? AppRoutes.tripTaxi : AppRoutes.tripStay, arguments: {'day': day});
  }

  @override
  Widget build(BuildContext context) {
    final plan = TripPlanController.to;
    return Obx(() {
      TabConfigController.to.version.value;
      final showTaxi = selected == TripSupplyKind.taxi || plan.showTaxiOption;
      final showStay = selected == TripSupplyKind.stay || plan.showStayOption;
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            if (showTaxi) _segment(TripSupplyKind.taxi, 'Taxi', Iconsax.car),
            if (showTaxi && showStay) const SizedBox(width: 4),
            if (showStay) _segment(TripSupplyKind.stay, 'Stay', Iconsax.building_4),
          ],
        ),
      );
    });
  }

  Widget _segment(TripSupplyKind kind, String label, IconData icon) {
    final active = kind == selected;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _switchTo(kind),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            gradient: active ? TripColors.gradient : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : AppColors.textLight),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.textMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
