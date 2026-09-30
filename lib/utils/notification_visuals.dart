import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';

/// Backend-string -> Color/IconData mapper for NotificationModel.type; add a case per new type.
abstract final class NotificationVisuals {
  static Color color(String type) => AppColors.textLight;

  static IconData icon(String type) => Iconsax.info_circle;
}
