import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../controllers/app_version_controller.dart';
import 'gradient_button.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  static const _defaultMessage =
      'A new version of Bakhli is required to continue. Please update to keep using the app.';

  @override
  Widget build(BuildContext context) {
    final ctrl = AppVersionController.to;
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Obx(() {
                final cfg = ctrl.config.value;
                final checking = ctrl.isChecking.value;
                final requiredBuild = cfg?.minBuild ?? 0;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      width: 100, height: 100,
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 46),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Update Required',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      cfg?.message ?? _defaultMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: AppColors.textMedium,
                        height: 1.6,
                      ),
                    ),
                    if (ctrl.installedBuild > 0 && requiredBuild > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Your build ${ctrl.installedBuild} · Required build $requiredBuild',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    GradientButton(
                      label: 'Update Now',
                      onPressed: ctrl.openStore,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: checking ? null : () => ctrl.check(),
                      child: checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Text(
                              'Check Again',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Debug build: run with --dart-define=DISABLE_UPDATE_GATE=true to bypass this screen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
