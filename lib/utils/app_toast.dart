import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

class AppToast {
  static void success(String message) => _show(message, ToastificationType.success);
  static void error(String message) => _show(message, ToastificationType.error);
  static void warning(String message) => _show(message, ToastificationType.warning);
  static void info(String message) => _show(message, ToastificationType.info);

  static Color _bgColor(ToastificationType type) {
    switch (type) {
      case ToastificationType.success: return const Color(0xFF1B5E20);
      case ToastificationType.error:   return const Color(0xFFB71C1C);
      case ToastificationType.warning: return const Color(0xFFE65100);
      case ToastificationType.info:    return const Color(0xFF0D47A1);
    }
  }

  static void _show(String message, ToastificationType type) {
    toastification.show(
      context: Get.overlayContext,
      type: type,
      style: ToastificationStyle.fillColored,
      description: Text(
        message,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      backgroundColor: _bgColor(type),
      foregroundColor: Colors.white,
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 4),
      closeButtonShowType: CloseButtonShowType.none,
      showProgressBar: false,
      borderRadius: BorderRadius.circular(14),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
      ],
    );
  }
}
