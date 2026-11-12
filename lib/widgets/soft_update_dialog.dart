import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/app_version_controller.dart';
import '../design/design.dart';

class SoftUpdateDialog extends StatelessWidget {
  const SoftUpdateDialog({super.key});

  static void _choose(BuildContext context, SoftUpdateChoice choice) {
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AppVersionController.to;
    return Obx(() {
      final cfg = ctrl.config.value;
      final versionName = cfg?.latestVersionName ?? '';
      final body = cfg?.message ??
          (versionName.isNotEmpty
              ? 'Bakhli $versionName is available with improvements and fixes.'
              : 'A new version of Bakhli is available with improvements and fixes.');
      return GateDialog(
        asset: TravelIcon.airplane,
        title: 'Update Available',
        body: body,
        horizontalActions: true,
        actions: [
          GateOutlineButton(label: 'Later', height: 48, onPressed: () => _choose(context, SoftUpdateChoice.later)),
          GateButton(label: 'Update', height: 48, onPressed: () => _choose(context, SoftUpdateChoice.update)),
        ],
      );
    });
  }
}
