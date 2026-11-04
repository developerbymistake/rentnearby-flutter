import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../config/app_colors.dart';
import '../taxi_ways_strings.dart';

class JourneyChangeStop extends StatelessWidget {
  final String placeName;
  final String? meetingPlace;

  const JourneyChangeStop({super.key, required this.placeName, this.meetingPlace});

  @override
  Widget build(BuildContext context) {
    final meet = meetingPlace;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Row(children: [
        const Icon(Iconsax.arrow_swap_horizontal, size: 18, color: AppColors.warningText),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              placeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const Text(
              TaxiWaysStrings.changeCarHere,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warningText),
            ),
            Text(
              meet != null && meet != placeName ? '${TaxiWaysStrings.meetNext} · $meet' : TaxiWaysStrings.meetNext,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textMedium),
            ),
          ]),
        ),
      ]),
    );
  }
}
