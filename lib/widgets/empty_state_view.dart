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
      padding: DS.insets(l: 32, t: 48, r: 32),
      child: TemplateStagger(
        children: [
          GateBadge(
            size: 84,
            asset: iconAsset,
            glyph: icon,
            gradient: palette.gradient,
          ),
          Gap.v(16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: FitnessAppTheme.title.copyWith(fontSize: DS.f(16)),
          ),
          Gap.v(4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: FitnessAppTheme.caption.copyWith(fontSize: DS.f(12)),
          ),
          if (onRetry != null) ...[
            Gap.v(16),
            SizedBox(
              width: DS.s(180),
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
