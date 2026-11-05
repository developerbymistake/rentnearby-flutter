import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';
import '../trip_strings_mca_a3.dart';
import 'trip_leg_menu_sheet.dart';

class TripLegHeader extends StatelessWidget {
  const TripLegHeader({super.key, required this.legIndex, this.anchorKey});

  final int legIndex;
  final GlobalKey? anchorKey;

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final p = c.plan.value;
      c.trip.value;
      final leg = p?.legAt(legIndex);
      if (p == null || leg == null) return SizedBox.shrink(key: anchorKey);
      final a = p.legStart(legIndex);
      final b = p.legEnd(legIndex);
      final spots = p.legSpotCount(legIndex);
      final range = TripStringsMcaA3.dayRangeWithDates(a, b, c.dateOf(a), c.dateOf(b));
      final line = spots > 0 ? '$range · ${TripStringsMcaA3.spots(spots)}' : range;
      final menu = !c.isReadOnly && !c.needsUpdate.value;
      return Padding(
        key: anchorKey,
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(gradient: TripColors.gradient, shape: BoxShape.circle),
              child: Text(
                '$legIndex',
                maxLines: 1,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    leg.cityName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
            if (menu)
              IconButton(
                onPressed: () => TripLegMenuSheet.show(context, legIndex),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMedium),
              ),
          ],
        ),
      );
    });
  }
}
