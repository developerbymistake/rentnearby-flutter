import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../taxi_option_sets.dart';
import '../ways/taxi_ways_strings.dart';

class TaxiPopularRoutesNudge extends StatelessWidget {
  final VoidCallback onTap;

  const TaxiPopularRoutesNudge({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: TaxiColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(children: [
                const Icon(Iconsax.routing_2, size: 18, color: TaxiColors.accentDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(TaxiWaysStrings.nudgeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: TaxiColors.accentDark)),
                    Text(TaxiWaysStrings.nudgeBody,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium)),
                  ]),
                ),
                const Icon(Iconsax.arrow_right_3, size: 16, color: TaxiColors.accentDark),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
