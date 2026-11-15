import 'package:flutter/material.dart';
import '../design/design.dart';

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
    this.activeColor = FitnessAppTheme.nearlyBlue,
    this.icon,
    this.gradient,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final radius = DS.circular(24);
    final fg = selected ? FitnessAppTheme.white : activeColor;
    return Container(
      decoration: BoxDecoration(
        color: selected && gradient == null ? activeColor : (selected ? null : FitnessAppTheme.nearlyWhite),
        gradient: selected ? gradient : null,
        borderRadius: radius,
        border: Border.all(color: activeColor),
        boxShadow: selected && gradient != null
            ? DS.shadows([ShadowTokens.tint(activeColor, ShadowSpec.lift)])
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          splashColor: FitnessAppTheme.white.withValues(alpha: Alpha.soft),
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: Padding(
            padding: padding ?? DS.sym(v: 8, h: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: DS.s(15), color: fg),
                  SizedBox(width: DS.s(6)),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: FitnessAppTheme.body2.copyWith(
                      fontSize: DS.f(12),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.27,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
