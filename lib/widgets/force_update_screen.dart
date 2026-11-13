import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/app_version_controller.dart';
import '../design/design.dart';
import '../design/extra/ext_shared.dart';
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
        tone: ListingTone.indigo,
        asset: TravelIcon.airplane,
        title: 'Update Required',
        body: cfg?.message ?? _defaultMessage,
        extra: ctrl.installedBuild > 0 && requiredBuild > 0
            ? Text('Your build ${ctrl.installedBuild} · Required build $requiredBuild', textAlign: TextAlign.center)
            : null,
        primary: GradientButton(label: 'Update Now', onPressed: ctrl.openStore),
        secondary: checking
            ? BusyWhitePill(tone: ListingTone.indigo, height: 52, semanticsLabel: 'Check Again')
            : WhitePillButton(tone: ListingTone.indigo, label: 'Check Again', height: 52, onTap: () => ctrl.check()),
        footer: kDebugMode
            ? Text(
                'Debug build: run with --dart-define=DISABLE_UPDATE_GATE=true to bypass this screen.',
                textAlign: TextAlign.center,
                style: Ink3D.text(11, FontWeight.w400, Ink3D.hint),
              )
            : null,
      );
    });
  }
}
