import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Shared date-group section header ("TODAY" / "YESTERDAY" / "22 JUL 2026") — used by
/// NotificationsScreen and MyInquiriesScreen above their [groupByDay]-bucketed rows.
class DayHeader extends StatelessWidget {
  final String label;
  const DayHeader(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.textHint,
        ),
      ),
    );
  }
}
