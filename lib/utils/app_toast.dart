import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import '../config/app_colors.dart';

class AppToast {
  static void success(String message) => _show(message, ToastificationType.success, Alignment.topCenter);
  static void error(String message) => _show(message, ToastificationType.error, Alignment.topCenter);
  static void warning(String message) => _show(message, ToastificationType.warning, Alignment.topCenter);
  static void info(String message, {Alignment alignment = Alignment.topCenter, bool compact = false}) =>
      _show(message, ToastificationType.info, alignment, compact: compact);

  // App-branded accent per severity, not toastification's own generic defaults — info in
  // particular uses AppColors.primary (the app's real navy) instead of an unrelated blue, so a
  // toast never reads as a different app's default styling dropped into ours.
  static Color _accentColor(ToastificationType type) {
    switch (type) {
      case ToastificationType.success: return AppColors.success;
      case ToastificationType.error: return AppColors.error;
      case ToastificationType.warning: return AppColors.warning;
      case ToastificationType.info: return AppColors.primary;
      default: return AppColors.primary;
    }
  }

  static IconData _iconFor(ToastificationType type) {
    switch (type) {
      case ToastificationType.success: return Icons.check_circle_rounded;
      case ToastificationType.error: return Icons.error_rounded;
      case ToastificationType.warning: return Icons.warning_rounded;
      case ToastificationType.info: return Icons.info_rounded;
      default: return Icons.info_rounded;
    }
  }

  static void _show(String message, ToastificationType type, Alignment alignment, {bool compact = false}) {
    final accent = _accentColor(type);
    toastification.show(
      context: Get.overlayContext,
      type: type,
      // White card + colored accent (icon/text/border) — matches the filter panel/View List/
      // owner-card language the rest of the app already uses, instead of toastification's
      // built-in saturated fill-color block.
      style: ToastificationStyle.flatColored,
      icon: Icon(_iconFor(type), color: accent, size: compact ? 18 : 20),
      description: Text(
        message,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: accent,
      borderSide: BorderSide(color: accent.withValues(alpha: 0.35), width: 1.4),
      alignment: alignment,
      autoCloseDuration: const Duration(seconds: 4),
      closeButton: const ToastCloseButton(showType: CloseButtonShowType.none),
      showProgressBar: false,
      borderRadius: BorderRadius.circular(compact ? 12 : 14),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      boxShadow: [
        BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4)),
      ],
    );
  }
}
