import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/module_palette.dart';
import 'gradient_button.dart';

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  final ModulePalette palette;
  final String retryLabel;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
    this.palette = ModulePalette.rooms,
    this.retryLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textHint),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMedium),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: GradientButton(
                label: retryLabel,
                height: 42,
                gradient: palette.gradient,
                shadowColor: palette.accent,
                onPressed: onRetry,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
