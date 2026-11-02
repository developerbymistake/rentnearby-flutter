import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_shadows.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';

class TripBackToPlanBar extends StatelessWidget {
  final String text;
  final String action;

  const TripBackToPlanBar({super.key, required this.text, this.action = TripStrings.backToPlan});

  static void backToPlan() => Get.until((route) => route.settings.name == AppRoutes.tripPlan || route.isFirst);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, AppInsets.bottomViewPadding(context) + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AppShadows.premium(TripColors.accent, alpha: 0.12, blur: 16, offset: const Offset(0, -4)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.tick_circle, size: 20, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: backToPlan,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: TripColors.gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                action,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
