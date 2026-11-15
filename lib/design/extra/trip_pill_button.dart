import 'package:flutter/material.dart';
import '../template/fitness_app_theme.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/design_scale.dart';

class TripPillButton extends StatelessWidget {
  const TripPillButton({super.key, required this.label, required this.onTap, required this.accent, this.icon});

  final String label;
  final VoidCallback onTap;
  final Color accent;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: DS.s(44)),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Material(
          color: FitnessAppTheme.white,
          borderRadius: DS.circular(24),
          child: InkWell(
            onTap: onTap,
            splashColor: accent.withValues(alpha: Alpha.soft),
            highlightColor: Colors.transparent,
            borderRadius: DS.circular(24),
            child: Ink(
              padding: DS.sym(h: 12, v: 7),
              decoration: BoxDecoration(
                borderRadius: DS.circular(24),
                border: Border.all(color: accent),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, Gap.h(5)],
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                        fontFamily: FitnessAppTheme.fontName,
                        fontSize: DS.f(12),
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
