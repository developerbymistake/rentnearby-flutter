import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../trip_strings_a4.dart';
import '../utils/trip_format.dart';

enum _DropChoice { cancel, restDay, remove }

class TripEditSpotSheet extends StatelessWidget {
  final String spotId;

  const TripEditSpotSheet(this.spotId, {super.key});

  static Future<void> show(BuildContext context, String spotId) async {
    final c = TripPlanController.to;
    if (c.isReadOnly) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => TripEditSpotSheet(spotId),
    );
  }

  static List<TripDay> _afterMove(TripPlan p, String id, int toDay) {
    final fromDay = p.dayOfSpot(id);
    final spot = p.spotById(id);
    if (fromDay == null || spot == null) return p.days;
    return [
      for (final d in p.days)
        if (d.day == fromDay)
          d.copyWith(spots: d.spots.where((s) => s.id != id).toList())
        else if (d.day == toDay)
          d.copyWith(spots: [...d.spots, spot])
        else
          d,
    ];
  }

  static List<TripDay> _afterRemove(TripPlan p, String id) =>
      [for (final d in p.days) d.copyWith(spots: d.spots.where((s) => s.id != id).toList())];

  static Future<_DropChoice> _confirmDrop(BuildContext context, List<TripDay> next) async {
    final dropped = TripPlanController.to.editImpact(next).droppedDaysWithBookings;
    if (dropped.isEmpty) return _DropChoice.remove;
    final choice = await showDialog<_DropChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          TripStringsA4.removesDays(dropped),
          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 17),
        ),
        content: const Text(
          TripStringsA4.removesDaysBody,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 4,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DropChoice.cancel),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(
              TripStringsA4.keepAsIs,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textLight),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DropChoice.restDay),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(
              TripStringsA4.keepRestDay,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: TripColors.accentDark),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DropChoice.remove),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(
              TripStringsA4.remove,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return choice ?? _DropChoice.cancel;
  }

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
            for (final d in plan.daysOf(plan.legIndexOf(currentDay))) ...[
              _dayOption(
                context,
                day: d.day,
                current: d.day == currentDay,
                total: d.day == currentDay ? c.dayLoadMinutes(d.day) : c.moveLoadMinutes(spotId, d.day),
                limit: c.dayLimitMinutes,
                onTap: () async {
                  if (d.day == currentDay) {
                    Navigator.pop(context);
                    return;
                  }
                  final choice = await _confirmDrop(context, _afterMove(plan, spotId, d.day));
                  if (choice == _DropChoice.cancel || !context.mounted) return;
                  Navigator.pop(context);
                  c.moveSpot(spotId, d.day, keepEmptyDays: choice == _DropChoice.restDay);
                },
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final choice = await _confirmDrop(context, _afterRemove(plan, spotId));
                if (choice == _DropChoice.cancel || !context.mounted) return;
                Navigator.pop(context);
                c.removeSpot(spotId, keepEmptyDays: choice == _DropChoice.restDay);
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
