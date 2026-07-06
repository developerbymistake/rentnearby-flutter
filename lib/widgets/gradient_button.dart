import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final double height;
  final Gradient gradient;
  final Color shadowColor;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.height = 52,
    this.gradient = AppColors.primaryGradient,
    this.shadowColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    // Loading = gradient + spinner (active appearance)
    // Disabled (onPressed null, not loading) = grey + text (muted appearance)
    final disabled = onPressed == null && !isLoading;
    return AnimatedOpacity(
      opacity: disabled ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: isLoading ? null : onPressed,
        child: Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: disabled ? null : gradient,
            color: disabled ? AppColors.textHint : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: shadowColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
