import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import '../design/design.dart';

class AppToast {
  /// Root-level host above every app-wide gate; the Navigator's own overlay sits beneath them.
  static final overlayKey = GlobalKey<OverlayState>();

  static const _duration = Duration(seconds: 4);

  static void success(String message) => _show(message, ToastKind.success, Alignment.topCenter);
  static void error(String message) => _show(message, ToastKind.error, Alignment.topCenter);
  static void warning(String message) => _show(message, ToastKind.warning, Alignment.topCenter);
  static void info(String message, {Alignment alignment = Alignment.topCenter, bool compact = false}) =>
      _show(message, ToastKind.info, alignment, compact: compact);

  static void noData(String title, String subtitle, {required Color accent}) {
    toastification.showCustom(
      context: Get.overlayContext,
      overlayState: overlayKey.currentState,
      alignment: Alignment.bottomCenter,
      autoCloseDuration: _duration,
      builder: (context, holder) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        child: NoDataToast3D(title: title, subtitle: subtitle, accent: accent, art: ListingArt.hotel),
      ),
    );
  }

  static void _show(String message, ToastKind kind, Alignment alignment, {bool compact = false}) {
    if (Get.overlayContext == null && overlayKey.currentState == null) return;
    final top = alignment.y < 0;
    toastification.showCustom(
      context: Get.overlayContext,
      overlayState: overlayKey.currentState,
      alignment: alignment,
      autoCloseDuration: _duration,
      builder: (context, holder) => Padding(
        padding: EdgeInsets.fromLTRB(16, top ? 8 : 0, 16, top ? 0 : 8),
        child: Toast3D(kind: kind, message: message, compact: compact),
      ),
    );
  }
}
