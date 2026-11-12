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
          child: PickChip(
            label: label,
            selected: on,
            icon: on ? Icons.check_rounded : null,
            activeColor: DesignColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            onTap: () {
              if (!on) onChanged(s);
            },
          ),
        ),
      ),
    );
  }
}
