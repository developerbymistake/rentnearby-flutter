import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import '../design/design.dart';

import 'package:bakhli/design/tokens/shadow_tokens.dart';
class AppToast {
  /// Root-level host above every app-wide gate; the Navigator's own overlay sits beneath them.
  static final overlayKey = GlobalKey<OverlayState>();

  static void success(String message) => _show(message, ToastificationType.success, Alignment.topCenter);
  static void error(String message) => _show(message, ToastificationType.error, Alignment.topCenter);
  static void warning(String message) => _show(message, ToastificationType.warning, Alignment.topCenter);
  static void info(String message, {Alignment alignment = Alignment.topCenter, bool compact = false}) =>
      _show(message, ToastificationType.info, alignment, compact: compact);

  static void noData(String title, String subtitle, {required Color accent}) {
    toastification.showCustom(
      context: Get.overlayContext,
      overlayState: overlayKey.currentState,
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 4),
      builder: (context, holder) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: UtilTokens.toastSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: UtilTokens.toastBorder),
            boxShadow: [ShadowTokens.tint(accent, ShadowSpec.elev2Spec)],
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: accent.withValues(alpha: Alpha.v10), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.search_off_rounded, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w700, color: UtilTokens.toastTitle, decoration: TextDecoration.none)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName, fontSize: 11, fontWeight: FontWeight.w400, color: UtilTokens.toastSubtitle, decoration: TextDecoration.none)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // App-branded accent per severity, not toastification's own generic defaults — info in
  // particular uses the brand primary token instead of an unrelated blue, so a
  // toast never reads as a different app's default styling dropped into ours.
  static Color _accentColor(ToastificationType type) {
    switch (type) {
      case ToastificationType.success: return UtilTokens.toastSuccess;
      case ToastificationType.error: return UtilTokens.toastError;
      case ToastificationType.warning: return UtilTokens.toastWarning;
      case ToastificationType.info: return UtilTokens.toastInfo;
      default: return UtilTokens.toastInfo;
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
    if (Get.overlayContext == null && overlayKey.currentState == null) return;
    final accent = _accentColor(type);
    toastification.show(
      context: Get.overlayContext,
      overlayState: overlayKey.currentState,
      type: type,
      // White card + colored accent (icon/text/border) — matches the filter panel/View List/
      // owner-card language the rest of the app already uses, instead of toastification's
      // built-in saturated fill-color block.
      style: ToastificationStyle.flatColored,
      icon: Icon(_iconFor(type), color: accent, size: compact ? 18 : 20),
      description: Text(
        message,
        style: TextStyle(
          fontFamily: FitnessAppTheme.fontName,
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
      backgroundColor: UtilTokens.toastSurface,
      foregroundColor: accent,
      borderSide: BorderSide(color: accent.withValues(alpha: Alpha.scrim), width: 1.4),
      alignment: alignment,
      autoCloseDuration: const Duration(seconds: 4),
      closeButton: const ToastCloseButton(showType: CloseButtonShowType.none),
      showProgressBar: false,
      borderRadius: BorderRadius.circular(compact ? 12 : 14),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      boxShadow: DesignShadows.card,
    );
  }
}
