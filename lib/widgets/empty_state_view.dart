import 'package:flutter/material.dart';
import '../config/module_palette.dart';
import '../design/design.dart';
import 'gradient_button.dart';

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  final ModulePalette palette;
  final String retryLabel;
  final String? iconAsset;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
    this.palette = templateModulePalette,
    this.retryLabel = 'Retry',
    this.iconAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
      child: TemplateStagger(
        children: [
          GateBadge(
            size: 84,
            asset: iconAsset,
            glyph: icon,
            gradient: palette.gradient,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: FitnessAppTheme.title,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: FitnessAppTheme.caption,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 180,
              child: GradientButton(
                label: retryLabel,
                height: 44,
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
