import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings_v2_find.dart';

class TripBackToPlanBar extends StatelessWidget {
  const TripBackToPlanBar({super.key, this.label = TripStringsV2Find.backToPlan});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Iconsax.task_square, size: 16, color: TripColors.accentDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
          ),
          TextButton(
            onPressed: TripNavigation.backToPlan,
            style: TextButton.styleFrom(minimumSize: const Size(44, 40), padding: const EdgeInsets.symmetric(horizontal: 10)),
            child: const Text(TripStringsV2Find.backToPlan,
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TripColors.accentDark)),
          ),
        ],
      ),
    );
  }
}
