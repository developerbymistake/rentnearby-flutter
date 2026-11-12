import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/app_version_controller.dart';
import '../design/design.dart';
import 'gradient_button.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  static const _defaultMessage =
      'A new version of Bakhli is required to continue. Please update to keep using the app.';

  @override
  Widget build(BuildContext context) {
    final ctrl = AppVersionController.to;
    return Obx(() {
      final cfg = ctrl.config.value;
      final checking = ctrl.isChecking.value;
      final requiredBuild = cfg?.minBuild ?? 0;
      return GateStatusPage(
        asset: TravelIcon.airplane,
        title: 'Update Required',
        body: cfg?.message ?? _defaultMessage,
        extra: ctrl.installedBuild > 0 && requiredBuild > 0
            ? Text(
                'Your build ${ctrl.installedBuild} · Required build $requiredBuild',
                textAlign: TextAlign.center,
                style: FitnessAppTheme.caption,
              )
            : null,
        primary: GradientButton(label: 'Update Now', onPressed: ctrl.openStore),
        secondary: TextButton(
          onPressed: checking ? null : () => ctrl.check(),
          child: checking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: FitnessAppTheme.nearlyDarkBlue),
                )
              : Text(
                  'Check Again',
                  style: FitnessAppTheme.body2.copyWith(
                    fontWeight: FontWeight.w600,
                    color: FitnessAppTheme.nearlyDarkBlue,
                  ),
                ),
        ),
        footer: kDebugMode
            ? Text(
                'Debug build: run with --dart-define=DISABLE_UPDATE_GATE=true to bypass this screen.',
                textAlign: TextAlign.center,
                style: FitnessAppTheme.caption.copyWith(fontSize: 11, color: FitnessAppTheme.deactivatedText),
              )
            : null,
      );
    });
  }
}
