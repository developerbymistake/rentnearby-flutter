import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';
import '../trip_strings_a2.dart';
import '../utils/trip_format.dart';
import 'trip_filter_chips.dart';

class TripRouteStrip extends StatelessWidget {
  final int day;
  final String? text;
  final ValueChanged<int> onDayChanged;
  final bool showRoute;
  final bool nights;
  final Color accent;

  const TripRouteStrip({
    super.key,
    required this.day,
    required this.onDayChanged,
    this.text,
    this.showRoute = true,
    this.nights = false,
    this.accent = TripColors.accent,
  });

  static String routeLine(TripPlanController c, int day) {
    final stops = c.plan.value?.dayAt(day)?.spots.length ?? 0;
    return [
      '$stops ${stops == 1 ? 'stop' : 'stops'}',
      TripFormat.km(c.dayKm(day)),
      TripFormat.duration(c.dayTotalMinutes(day)),
    ].join(' · ');
  }

  String _chipLabel(TripPlanController c, int d) {
    final base = nights ? TripStringsA2.nightChip(d) : TripStringsA2.dayChip(d);
    final date = c.dateOf(d);
    return date == null ? base : '$base · ${TripFormat.dayMonth(date)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      c.result.value;
      c.plan.value;
      final count = c.dayCount;
      final line = showRoute ? (text ?? 'Day $day route · ${routeLine(c, day)}') : null;
      if (count <= 1 && line == null) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 1)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: count,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final d = i + 1;
                  return TripChipView(
                    accent: accent,
                    chip: TripFilterChip(
                      label: _chipLabel(c, d),
                      selected: d == day,
                      onTap: () {
                        if (d != day) onDayChanged(d);
                      },
                    ),
                  );
                },
              ),
            ),
          if (line != null) ...[
            if (count > 1) const SizedBox(height: 2),
            Row(
              children: [
                Icon(Iconsax.routing_2, size: 14, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textLight),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    });
  }
}
