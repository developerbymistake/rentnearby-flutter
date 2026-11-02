import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';

class TripSummaryStrip extends StatelessWidget {
  const TripSummaryStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      if (c.plan.value == null || !c.hasChoice) return const SizedBox.shrink();
      final days = c.dayCount;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: TripColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TripColors.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            _cell('$days', days == 1 ? 'day' : 'days'),
            _divider(),
            _cell(BrowseItem.inr(c.priceSoFar), 'so far'),
            _divider(),
            _cell('${c.taxisChosen} of $days', 'taxis'),
          ],
        ),
      );
    });
  }

  Widget _divider() => Container(width: 1, height: 28, color: TripColors.accent.withValues(alpha: 0.2));

  Widget _cell(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: TripColors.accentDark),
            ),
            Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
          ],
        ),
      );
}
