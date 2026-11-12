import 'package:flutter/material.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart' show TripLook;
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/template/fitness_app_theme.dart';
import 'package:get/get.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_mca_n2.dart';
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
      final nights = TripStringsMcaA3.nights(p.legDayCount(legIndex));
      final line = spots > 0 ? '$range · ${TripStringsMcaA3.spots(spots)} · $nights' : '$range · $nights';
      final menu = !c.isReadOnly && !c.needsUpdate.value;
      final unavailable = c.legUnavailable(legIndex);
      return Padding(
        key: anchorKey,
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: TripLook.gradient,
                shape: BoxShape.circle,
                boxShadow: TripLook.shadowFor(FitnessAppTheme.nearlyDarkBlue),
              ),
              child: Text(
                '$legIndex',
                maxLines: 1,
                style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 14, fontWeight: FontWeight.w700, color: FitnessAppTheme.white),
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
                        fontFamily: FitnessAppTheme.fontName, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.27, color: TripLook.textDark),
                  ),
                  Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w600, color: TripLook.textLight),
                  ),
                  if (unavailable) ...[
                    Text(
                      TripStringsMcaN2.cityUnavailable,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w600, color: TripLook.error),
                    ),
                    if (menu)
                      InkWell(
                        onTap: () => TripLegMenuSheet.show(context, legIndex),
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        child: const SizedBox(
                          height: 44,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              TripStringsMcaA3.removeCity,
                              maxLines: 1,
                              style: TextStyle(
                                  fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, fontWeight: FontWeight.w700, color: TripLook.error),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (menu)
              InkWell(
                onTap: () => TripLegMenuSheet.show(context, legIndex),
                borderRadius: BorderRadius.circular(32),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.more_vert_rounded, color: TripLook.textMedium),
                ),
              ),
          ],
        ),
      );
    });
  }
}
