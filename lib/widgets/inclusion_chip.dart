import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../utils/service_icons.dart';

/// Icon + label badge chip for one ServicePackage Inclusion (e.g. "Hotel
/// Stay", "Meals Included") — used in a Wrap on the Package List cards.
class InclusionChip extends StatelessWidget {
  final String iconName;
  final String label;

  const InclusionChip({super.key, required this.iconName, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(serviceIconFor(iconName), size: 12, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
