import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/tab_config_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';
import '../trip_strings_a2.dart';

enum TripSupplyKind { taxi, stay }

class TripTaxiStayToggle extends StatelessWidget {
  final TripSupplyKind selected;
  final int day;
  final bool onHeader;
  final Color activeColor;

  const TripTaxiStayToggle({
    super.key,
    required this.selected,
    required this.day,
    this.onHeader = false,
    this.activeColor = TripColors.accent,
  });

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
        padding: EdgeInsets.all(onHeader ? 3 : 4),
        decoration: BoxDecoration(
          color: onHeader ? Colors.white.withValues(alpha: 0.28) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: onHeader ? null : Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            if (showTaxi) _segment(TripSupplyKind.taxi, TripStringsA2.taxi, Iconsax.car),
            if (showTaxi && showStay) const SizedBox(width: 4),
            if (showStay) _segment(TripSupplyKind.stay, TripStringsA2.stay, Iconsax.building_4),
          ],
        ),
      );
    });
  }

  Widget _segment(TripSupplyKind kind, String label, IconData icon) {
    final active = kind == selected;
    final Color fg;
    if (onHeader) {
      fg = active ? activeColor : Colors.white;
    } else {
      fg = active ? Colors.white : AppColors.textMedium;
    }
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _switchTo(kind),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: onHeader && active ? Colors.white : null,
              gradient: !onHeader && active ? TripColors.gradient : null,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: onHeader || active ? fg : AppColors.textLight),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
