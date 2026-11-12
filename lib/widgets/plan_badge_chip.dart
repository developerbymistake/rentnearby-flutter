import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';

class PlanBadgeChip extends StatelessWidget {
  final Color color;
  final String label;
  final bool compact;

  const PlanBadgeChip({super.key, required this.color, this.label = 'Featured', this.compact = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 9, vertical: compact ? 1 : 3),
      decoration: BoxDecoration(color: color, borderRadius: CardRadius.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TravelIcon(TravelIcon.star, size: compact ? 10 : 13),
          const SizedBox(width: 2),
          Text(
            label,
            style: TypeTokens.style(compact ? 10 : 11, FontWeight.w700,
                color: DesignColors.surface, letterSpacing: 0.2, chip: compact),
          ),
        ],
      ),
    );
  }
}
