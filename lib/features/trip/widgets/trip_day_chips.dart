import 'package:flutter/material.dart';
import '../../../widgets/selectable_chip.dart';
import '../trip_colors.dart';

class TripDayChips extends StatelessWidget {
  static const int all = 0;

  final int dayCount;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool includeAll;

  const TripDayChips({
    super.key,
    required this.dayCount,
    required this.selected,
    required this.onChanged,
    this.includeAll = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var d = 1; d <= dayCount; d++) ...[
            if (d > 1) const SizedBox(width: 8),
            SelectableChip(
              label: 'Day $d',
              selected: selected == d,
              activeColor: TripColors.dayColor(d),
              onTap: () => onChanged(d),
            ),
          ],
          if (includeAll) ...[
            const SizedBox(width: 8),
            SelectableChip(
              label: 'All',
              selected: selected == all,
              activeColor: TripColors.accentDark,
              onTap: () => onChanged(all),
            ),
          ],
        ],
      ),
    );
  }
}
