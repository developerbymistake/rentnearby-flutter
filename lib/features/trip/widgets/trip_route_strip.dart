import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';
import '../utils/trip_format.dart';
import 'trip_day_chips.dart';

class TripRouteStrip extends StatelessWidget {
  final int day;
  final String? text;
  final ValueChanged<int> onDayChanged;

  const TripRouteStrip({super.key, required this.day, required this.onDayChanged, this.text});

  static String routeLine(TripPlanController c, int day) {
    final stops = c.plan.value?.dayAt(day)?.spots.length ?? 0;
    return [
      '$stops ${stops == 1 ? 'stop' : 'stops'}',
      TripFormat.km(c.dayKm(day)),
      TripFormat.duration(c.dayTotalMinutes(day)),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      c.result.value;
      final line = text ?? 'Day $day route · ${routeLine(c, day)}';
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: TripColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TripColors.accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Iconsax.routing_2, size: 15, color: TripColors.accentDark),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
                  ),
                ),
              ],
            ),
            if (c.dayCount > 1) ...[
              const SizedBox(height: 10),
              TripDayChips(dayCount: c.dayCount, selected: day, onChanged: onDayChanged),
            ],
          ],
        ),
      );
    });
  }
}
