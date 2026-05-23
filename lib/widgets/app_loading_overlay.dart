import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Wraps [child] with a full-screen dimmed overlay + spinner card whenever
/// [isLoading] is true. Use with Obx() at the call site when driven by an
/// RxBool, or pass a plain bool from a StatefulWidget.
///
/// Example:
///   Obx(() => AppLoadingOverlay(
///     isLoading: _ctrl.isDeleting.value,
///     message: 'Deleting...',
///     child: myScreenContent,
///   ))
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
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
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
