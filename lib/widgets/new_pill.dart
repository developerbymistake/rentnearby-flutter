import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Shared "NEW" pill — used by NotificationsScreen (unread) and MyInquiriesScreen (recently
/// created/updated), matching every other pill in those two screens (tinted background +
/// solid-color text, not a solid fill).
class NewPill extends StatelessWidget {
  const NewPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: const Text(
        'NEW',
        style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: AppColors.accent),
      ),
    );
  }
}
