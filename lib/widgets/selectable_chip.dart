import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Same visual/animation as the type-filter chips in explore_screen.dart /
/// explore_plots_screen.dart (AnimatedContainer, 200ms, rounded-10, solid
/// [activeColor] + white text when selected). Shared so the Rooms/Plots
/// toggle and the filter sheet's type chips stay pixel-identical.
///
/// [icon] and [gradient] are optional, backward-compatible additions for
/// contexts that want a richer/more elevated selected state (e.g. Home's
/// hero toggle) — when [gradient] is set, it replaces the flat [activeColor]
/// fill and adds a matching shadow on selection; existing callers that don't
/// pass either keep the original flat look untouched.
///
/// [padding] is also optional/backward-compatible — dense grids (room/plot
/// type chips) keep the default compact padding, while a single-row context
/// like a sort-option button can pass a taller value so it reads as a real
/// button instead of a cramped label.
class SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;
  final IconData? icon;
  final Gradient? gradient;
  final EdgeInsetsGeometry? padding;

  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.activeColor = AppColors.primary,
    this.icon,
    this.gradient,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: padding ?? const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: BoxDecoration(
          color: selected && gradient == null ? activeColor : (selected ? null : Colors.white),
          gradient: selected ? gradient : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? activeColor : AppColors.divider,
            width: 1.5,
          ),
          boxShadow: selected && gradient != null
              ? [BoxShadow(color: activeColor.withValues(alpha: 0.32), blurRadius: 12, offset: const Offset(0, 5))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? Colors.white : AppColors.textHint),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
