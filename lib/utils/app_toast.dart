import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

class AppToast {
  static void success(String message) => _show(message, ToastificationType.success);
  static void error(String message) => _show(message, ToastificationType.error);
  static void warning(String message) => _show(message, ToastificationType.warning);
  static void info(String message) => _show(message, ToastificationType.info);

  static void _show(String message, ToastificationType type) {
    toastification.show(
      context: Get.overlayContext,
      type: type,
      style: ToastificationStyle.flatColored,
      description: Text(
        message,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
      ),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 4),
      closeButtonShowType: CloseButtonShowType.none,
      showProgressBar: false,
      borderRadius: BorderRadius.circular(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
