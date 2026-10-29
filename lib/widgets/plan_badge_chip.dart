import 'package:flutter/material.dart';

class PlanBadgeChip extends StatelessWidget {
  final Color color;
  final String label;
  final bool compact;

  const PlanBadgeChip({super.key, required this.color, this.label = 'Featured', this.compact = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 9, vertical: compact ? 1 : 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: compact ? 10 : 13, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
