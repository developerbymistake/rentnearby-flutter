import 'package:bakhli/design/extra/chat_kit.dart';
import 'package:bakhli/design/extra/ext_notifications.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/driver_ready_controller.dart';
import '../strings/driver_ready_strings.dart';

class DriverReadyStrip extends StatelessWidget {
  const DriverReadyStrip({super.key, this.controller, this.onOpen});

  final DriverReadyController? controller;
  final VoidCallback? onOpen;

  static const String route = '/taxi-ready';

  @override
  Widget build(BuildContext context) {
    final ctrl = controller ?? DriverReadyController.to;
    return Obx(() {
      final show = ctrl.missedRings ||
          (ctrl.device.value != null ? ctrl.needsFix : ctrl.hasFailed(DriverReadyAction.report) && !ctrl.isBusy(DriverReadyAction.report));
      if (!show) return const SizedBox.shrink();
      return NotificationBannerCard3D(
        art: NotificationLook.bell,
        title: DriverReadyStrings.stripTitle,
        body: ctrl.missedRings ? DriverReadyStrings.stripMissedBody : DriverReadyStrings.stripBody,
        actionLabel: DriverReadyStrings.stripAction,
        onAction: onOpen ?? () => Get.toNamed(route),
      );
    });
  }
}
