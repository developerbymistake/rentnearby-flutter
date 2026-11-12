import 'package:flutter/material.dart';
import '../design/design.dart';

class NewPill extends StatelessWidget {
  final Color color;
  const NewPill({super.key, this.color = FitnessAppTheme.nearlyBlue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(color: color.withValues(alpha: Alpha.v10), borderRadius: BorderRadius.circular(8)),
      child: Text(
        'NEW',
        style: FitnessAppTheme.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: color),
      ),
    );
  }
}
