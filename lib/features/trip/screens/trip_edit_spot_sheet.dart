import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../utils/trip_format.dart';

class TripEditSpotSheet extends StatelessWidget {
  final String spotId;

  const TripEditSpotSheet(this.spotId, {super.key});

  static Future<void> show(BuildContext context, String spotId) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => TripEditSpotSheet(spotId),
      );

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    final plan = c.plan.value;
    final spot = plan?.spotById(spotId);
    final currentDay = plan?.dayOfSpot(spotId);
    if (plan == null || spot == null || currentDay == null) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, AppInsets.bottomViewPadding(context) + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(
              'Move ${spot.name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
            const SizedBox(height: 12),
            for (final d in plan.days) ...[
              _dayOption(
                context,
                day: d.day,
                current: d.day == currentDay,
                total: d.day == currentDay ? c.dayTotalMinutes(d.day) : c.dayTotalMinutes(d.day) + spot.visitMinutes,
                limit: c.dayLimitMinutes,
                onTap: () {
                  Navigator.pop(context);
                  if (d.day != currentDay) c.moveSpot(spotId, d.day);
                },
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.pop(context);
                c.removeSpot(spotId);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  children: [
                    Icon(Iconsax.trash, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text(
                      'Remove from trip',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayOption(
    BuildContext context, {
    required int day,
    required bool current,
    required int total,
    required int limit,
    required VoidCallback onTap,
  }) {
    final tooLong = total > limit;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: current ? TripColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: current ? TripColors.accent : AppColors.divider, width: current ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: TripColors.dayColor(day), shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              'Day $day',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: current ? FontWeight.w700 : FontWeight.w600,
                color: current ? TripColors.accentDark : AppColors.textDark,
              ),
            ),
            const Spacer(),
            if (tooLong)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.errorSurface, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  '${TripFormat.duration(total)}, ${TripStrings.tooLong}',
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
