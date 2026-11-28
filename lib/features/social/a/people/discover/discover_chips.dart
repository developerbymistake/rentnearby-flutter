import 'package:flutter/material.dart';

import '../../../../../design/design.dart';
import '../../../b/widgets/social_widgets_b.dart';
import '../../../shared/social_models.dart';
import '../../social_strings_a.dart';

/// For you / Same trip / Near you (lock for Free) / Mutual / Interests.
class DiscoverChipsRow extends StatelessWidget {
  const DiscoverChipsRow({super.key, required this.selected, required this.nearLocked, required this.onSelect});

  final String selected;
  final bool nearLocked;
  final ValueChanged<String> onSelect;

  static Key keyOf(String chip) => ValueKey('discover_chip_$chip');

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: DS.gapInsets(l: 18, t: 16, r: 18, b: 4),
        child: Row(
          children: [
            for (var i = 0; i < DiscoverChips.all.length; i++) ...[
              if (i > 0) Gap.h(8),
              KeyedSubtree(
                key: keyOf(DiscoverChips.all[i]),
                child: SocialPickChip(
                  label: SocialStringsA.chipLabel(DiscoverChips.all[i]),
                  selected: DiscoverChips.all[i] == selected,
                  trailing: DiscoverChips.all[i] == DiscoverChips.near && nearLocked ? Icons.lock_rounded : null,
                  onTap: () => onSelect(DiscoverChips.all[i]),
                ),
              ),
            ],
          ],
        ),
      );
}
