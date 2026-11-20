import 'package:flutter/material.dart';

class DaySpentChip extends StatelessWidget {
  const DaySpentChip({super.key, required this.tripId, required this.day});

  final String tripId;
  final int day;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
