import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Shared "NEW" pill — used by NotificationsScreen (unread).
/// matching the other notification pills (tinted background +
/// solid-color text, not a solid fill).
class NewPill extends StatelessWidget {
  final Color color;
  const NewPill({super.key, this.color = AppColors.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
      child: Text(
        'NEW',
        style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: color),
      ),
    );
  }
}
