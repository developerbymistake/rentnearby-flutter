import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

enum NotificationKind { approved, rejected, takedown, other }

/// Backend-string -> Color/IconData mapper for NotificationModel; add a case per new type.
abstract final class NotificationVisuals {
  static NotificationKind kind(String type, String title) {
    final t = type.toLowerCase();
    if (t.contains('approved')) return NotificationKind.approved;
    if (t.contains('rejected')) {
      return title.toLowerCase().contains('taken down') ? NotificationKind.takedown : NotificationKind.rejected;
    }
    return NotificationKind.other;
  }

  static Color color(String type, String title) => switch (kind(type, title)) {
        NotificationKind.approved => AppColors.success,
        NotificationKind.rejected => AppColors.error,
        NotificationKind.takedown => AppColors.reportAlert,
        NotificationKind.other => AppColors.textLight,
      };

  static IconData icon(String type, String title) => switch (kind(type, title)) {
        NotificationKind.approved => Icons.check_circle_rounded,
        NotificationKind.rejected => Icons.cancel_rounded,
        NotificationKind.takedown => Icons.flag_rounded,
        NotificationKind.other => Iconsax.info_circle,
      };

  /// 'ROOM' / 'PLOT' from the route the notification opens; null when it points elsewhere.
  static String? listingKind(String? actionRoute) => switch (actionRoute) {
        AppRoutes.myPlots => 'PLOT',
        AppRoutes.myListings => 'ROOM',
        _ => null,
      };
}
