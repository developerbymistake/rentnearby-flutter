import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../models/trip_summary_model.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../trip_strings_mca_a3.dart';

class TripSummaryLegHeader extends StatelessWidget {
  const TripSummaryLegHeader(this.leg, {super.key});

  final TripSummaryLeg leg;

  @override
  Widget build(BuildContext context) {
    final a = leg.startDate;
    final b = leg.endDate;
    final dates = a == null || b == null ? null : TripStringsMcaA3.dateSpan(a, b);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          const Icon(Iconsax.location, size: 15, color: TripColors.accentDark),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              TripStrings.joinDots([leg.cityName, dates]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMedium),
            ),
          ),
        ],
      ),
    );
  }
}
