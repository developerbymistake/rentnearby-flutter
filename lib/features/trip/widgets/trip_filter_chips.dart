import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../trip_colors.dart';

class TripFilterChip {
  const TripFilterChip({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
}

class TripFilterChips extends StatelessWidget {
  const TripFilterChips({super.key, required this.items, this.accent = TripColors.accent});

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
  const TripChipView({super.key, required this.chip, this.accent = TripColors.accent});

  final TripFilterChip chip;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final on = chip.selected;
    final fg = on ? Colors.white : AppColors.textMedium;
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 34),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: on ? accent : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: on ? accent : AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (chip.icon != null) ...[
                    Icon(chip.icon, size: 14, color: fg),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      chip.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: fg),
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
