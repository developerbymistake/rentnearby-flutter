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
      spacing: DS.gh(8),
      runSpacing: DS.gv(6),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          TaxiWaysStrings.sortLabel,
          style: FitnessAppTheme.caption.copyWith(fontSize: DS.f(12), fontWeight: FontWeight.w600, color: DesignColors.textSecondary),
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
        constraints: BoxConstraints(minHeight: DS.s(44)),
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
          padding: DS.sym(h: 14, v: 10),
          decoration: BoxDecoration(
            gradient: on ? p.gradient : null,
            color: on ? null : DesignColors.chipBackground,
            borderRadius: DS.br(CardRadius.pill),
            boxShadow: on ? DS.shadows(ShadowTokens.glow(p.g2)) : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (on) Padding(padding: EdgeInsets.only(right: DS.s(6)), child: Icon(Icons.check_rounded, size: DS.s(18), color: DesignColors.textInverse)),
              Flexible(child: Text(label, style: Ink3D.text(14, FontWeight.w600, on ? DesignColors.textInverse : DesignColors.textPrimary, letterSpacing: 0))),
            ],
          ),
        ),
      ),
    );
  }
}
