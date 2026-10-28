import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../controllers/app_version_controller.dart';

/// Pushed by [AppVersionController]; only pops with a [SoftUpdateChoice].
class SoftUpdateDialog extends StatelessWidget {
  const SoftUpdateDialog({super.key});

  // A second tap during the pop transition would otherwise pop the route underneath.
  static void _choose(BuildContext context, SoftUpdateChoice choice) {
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AppVersionController.to;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Obx(() {
          final cfg = ctrl.config.value;
          final versionName = cfg?.latestVersionName ?? '';
          final body = cfg?.message ??
              (versionName.isNotEmpty
                  ? 'Bakhli $versionName is available with improvements and fixes.'
                  : 'A new version of Bakhli is available with improvements and fixes.');
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.system_update_rounded, size: 30, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'Update Available',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _choose(context, SoftUpdateChoice.later),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMedium,
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Later',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _choose(context, SoftUpdateChoice.update),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Update',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}
