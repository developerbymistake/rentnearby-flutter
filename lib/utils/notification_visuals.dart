import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';

/// Backend-string -> Color/IconData mapper for NotificationModel.type, mirroring
/// InquiryStatus's exact shape (switch-on-raw-backend-string, neutral fallback rather than
/// crashing on an unrecognized/future value). The 4 cases below are the only real values
/// NotificationModel.type carries today — every producer of the backend's NotificationEvent
/// table that GET /notifications serves (chat/report/broadcast use separate delivery channels,
/// never this inbox).
abstract final class NotificationVisuals {
  static Color color(String type) => switch (type) {
        'LeadAssigned' => AppColors.primaryLight,
        'EscalationResolved' => AppColors.success,
        'LeadUnassigned' => AppColors.textLight,
        'InquiryAgentChanged' => AppColors.warning,
        _ => AppColors.textLight,
      };

  static IconData icon(String type) => switch (type) {
        'LeadAssigned' => Iconsax.briefcase,
        'EscalationResolved' => Iconsax.tick_circle,
        'LeadUnassigned' => Iconsax.user_remove,
        'InquiryAgentChanged' => Iconsax.refresh,
        _ => Iconsax.info_circle,
      };
}
