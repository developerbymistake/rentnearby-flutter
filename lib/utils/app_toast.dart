import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

class AppToast {
  static void success(String message) => _show(message, ToastificationType.success, Alignment.topCenter);
  static void error(String message) => _show(message, ToastificationType.error, Alignment.topCenter);
  static void warning(String message) => _show(message, ToastificationType.warning, Alignment.topCenter);
  static void info(String message, {Alignment alignment = Alignment.topCenter, bool compact = false}) =>
      _show(message, ToastificationType.info, alignment, compact: compact);

  static Color _bgColor(ToastificationType type) {
    switch (type) {
      case ToastificationType.success: return const Color(0xFF1B5E20);
      case ToastificationType.error:   return const Color(0xFFB71C1C);
      case ToastificationType.warning: return const Color(0xFFE65100);
      case ToastificationType.info:    return const Color(0xFF0D47A1);
      default:                         return const Color(0xFF0D47A1);
    }
  }

  static void _show(String message, ToastificationType type, Alignment alignment, {bool compact = false}) {
    toastification.show(
      context: Get.overlayContext,
      type: type,
      style: ToastificationStyle.fillColored,
      description: Text(
        message,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      backgroundColor: _bgColor(type),
      foregroundColor: Colors.white,
      alignment: alignment,
      autoCloseDuration: const Duration(seconds: 4),
      closeButton: const ToastCloseButton(showType: CloseButtonShowType.none),
      showProgressBar: false,
      borderRadius: BorderRadius.circular(compact ? 12 : 14),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
      ],
    );
  }
}
