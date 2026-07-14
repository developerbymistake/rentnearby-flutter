import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../controllers/location_controller.dart';
import 'location_switch_sheet.dart';

/// Same widget as explore_screen.dart's private `_buildLocationPill()` —
/// kept as a standalone shared widget rather than refactoring Explore to use
/// it, so the already-shipped Explore screens stay untouched.
class LocationPill extends StatelessWidget {
  const LocationPill({super.key});

  @override
  Widget build(BuildContext context) {
    final locationCtrl = Get.find<LocationController>();
    return Obx(() {
      final district = locationCtrl.effectiveDistrict;
      if (district == null) return const SizedBox();
      final cityName = locationCtrl.browsingCity.value?.name ??
          locationCtrl.autoCity.value?.name ??
          'Current';

      return GestureDetector(
        onTap: () => LocationSwitchSheet.show(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(children: [
            const Icon(Icons.public_rounded, color: AppColors.primary, size: 15),
            const SizedBox(width: 7),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: district.name),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.chevron_right_rounded,
                          size: 14, color: AppColors.primary.withValues(alpha: 0.6)),
                    ),
                  ),
                  TextSpan(text: cityName),
                ]),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary, size: 16),
          ]),
        ),
      );
    });
  }
}
