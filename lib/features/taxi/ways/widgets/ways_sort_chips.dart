import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../taxi_option_sets.dart';
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
        const Text(
          TaxiWaysStrings.sortLabel,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight),
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
      child: InkWell(
        onTap: on ? null : () => onChanged(s),
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? TaxiColors.accentDark : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: on ? TaxiColors.accentDark : AppColors.divider),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (on) ...[
              const Icon(Icons.check_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: on ? Colors.white : AppColors.textMedium,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
