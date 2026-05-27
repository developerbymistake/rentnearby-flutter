import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Wraps [child] with a full-screen dimmed overlay + spinner card whenever
/// [isLoading] is true. Use with Obx() at the call site when driven by an
/// RxBool, or pass a plain bool from a StatefulWidget.
///
/// For screens that already use a Stack (e.g. photo upload screens), use the
/// [AppLoadingOverlay.stackChild] factory to get a Positioned.fill overlay
/// that can be inserted directly into an existing Stack's children list.
///
/// Example (wrapper):
///   Obx(() => AppLoadingOverlay(
///     isLoading: _ctrl.isDeleting.value,
///     message: 'Deleting...',
///     child: myScreenContent,
///   ))
///
/// Example (Stack child):
///   Stack(children: [
///     Scaffold(...),
///     if (_isFinalizing) AppLoadingOverlay.stackChild(message: 'Saving...'),
///   ])
class AppLoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String message;
  final Color indicatorColor;

  const AppLoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message = 'Loading...',
    this.indicatorColor = AppColors.primary,
  });

  /// Returns a [Positioned.fill] overlay for use inside an existing [Stack].
  /// The caller controls visibility via an `if` condition in the Stack's
  /// children list — this widget is always visible when present.
  static Widget stackChild({
    String message = 'Loading...',
    Color indicatorColor = AppColors.primary,
  }) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2.5, color: indicatorColor),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: indicatorColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
