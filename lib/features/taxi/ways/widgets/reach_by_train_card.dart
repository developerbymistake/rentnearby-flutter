import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../config/app_colors.dart';
import '../taxi_ways_strings.dart';

class ReachByTrainCard extends StatelessWidget {
  final String placeName;

  const ReachByTrainCard({super.key, required this.placeName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Iconsax.routing_2, size: 20, color: AppColors.warningText),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(TaxiWaysStrings.reachBy(placeName),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warningText)),
            const SizedBox(height: 2),
            Text(TaxiWaysStrings.reachBody,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium)),
          ]),
        ),
      ]),
    );
  }
}
