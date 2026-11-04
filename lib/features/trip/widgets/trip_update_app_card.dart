import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_shadows.dart';
import '../../../controllers/app_version_controller.dart';
import '../../../widgets/gradient_button.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../trip_strings_a4.dart';

class TripUpdateAppCard extends StatelessWidget {
  const TripUpdateAppCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, AppInsets.bottomViewPadding(context) + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: AppShadows.premium(TripColors.accent, alpha: 0.14, blur: 16, offset: const Offset(0, -4)),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Iconsax.refresh_circle, size: 20, color: TripColors.accentDark),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TripStrings.updateAppTitle,
                          style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                        SizedBox(height: 2),
                        Text(
                          TripStrings.updateAppBody,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GradientButton(
                label: TripStringsA4.openPlayStore,
                height: 48,
                gradient: TripColors.gradient,
                shadowColor: TripColors.accent,
                onPressed: () => AppVersionController.to.openStore(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
