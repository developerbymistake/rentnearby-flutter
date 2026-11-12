import 'package:flutter/material.dart';
import '../template/fitness_app_theme.dart';
import '../tokens/alpha_tokens.dart';

class TripPillButton extends StatelessWidget {
  const TripPillButton({super.key, required this.label, required this.onTap, required this.accent, this.icon});

  final String label;
  final VoidCallback onTap;
  final Color accent;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Material(
          color: FitnessAppTheme.white,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            splashColor: accent.withValues(alpha: Alpha.soft),
            highlightColor: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: accent),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 5)],
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                        fontFamily: FitnessAppTheme.fontName,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.27,
                        color: accent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
