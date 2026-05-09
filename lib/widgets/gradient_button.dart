import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final double height;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: onPressed == null ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: onPressed == null ? null : AppColors.primaryGradient,
            color: onPressed == null ? AppColors.textHint : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: onPressed == null
                ? []
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
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
