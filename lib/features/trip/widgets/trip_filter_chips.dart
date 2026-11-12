import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';

class TripFilterChip {
  const TripFilterChip({required this.label, required this.selected, required this.onTap, this.icon, this.iconAsset});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? iconAsset;
}

class TripFilterChips extends StatelessWidget {
  const TripFilterChips({super.key, required this.items, this.accent = FitnessAppTheme.nearlyDarkBlue});

  final List<TripFilterChip> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 0,
      children: [for (final c in items) TripChipView(chip: c, accent: accent)],
    );
  }
}

class TripChipView extends StatelessWidget {
  const TripChipView({super.key, required this.chip, this.accent = FitnessAppTheme.nearlyDarkBlue});

  final TripFilterChip chip;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final on = chip.selected;
    final fg = on ? FitnessAppTheme.white : (accent.computeLuminance() < 0.6 ? accent : FitnessAppTheme.darkText);
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: chip.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.fastOutSlowIn,
              constraints: const BoxConstraints(minHeight: 34),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: on ? accent : FitnessAppTheme.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: accent.withValues(alpha: on ? 1 : 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (chip.iconAsset != null) ...[
                    TravelIcon(chip.iconAsset!, size: 16),
                    const SizedBox(width: 5),
                  ] else if (chip.icon != null) ...[
                    Icon(chip.icon, size: 14, color: fg),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      chip.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.27, color: fg),
                    ),
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
