import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../models/taxi_ways_models.dart';
import '../taxi_ways_strings.dart';

class WaysSortChips extends StatelessWidget {
  final WaysSort value;
  final ValueChanged<WaysSort> onChanged;

  const WaysSortChips({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          TaxiWaysStrings.sortLabel,
          style: FitnessAppTheme.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: DesignColors.textSecondary),
        ),
        _chip(TaxiWaysStrings.fewestCars, WaysSort.fewestCars),
        _chip(TaxiWaysStrings.lowestPrice, WaysSort.lowestPrice),
      ],
    );
  }

  Widget _chip(String label, WaysSort s) {
    final on = value == s;
    return Semantics(
      selected: on,
      button: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: _SortPill(label: label, on: on, onTap: () {
            if (!on) onChanged(s);
          }),
        ),
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  const _SortPill({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = ListingPalette.coral;
    return PressScale(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: on ? p.gradient : null,
            color: on ? null : DesignColors.chipBackground,
            borderRadius: CardRadius.pill,
            boxShadow: on ? ShadowTokens.glow(p.g2) : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (on) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.check_rounded, size: 18, color: DesignColors.textInverse)),
              Flexible(child: Text(label, style: Ink3D.text(14, FontWeight.w600, on ? DesignColors.textInverse : DesignColors.textPrimary, letterSpacing: 0))),
            ],
          ),
        ),
      ),
    );
  }
}
