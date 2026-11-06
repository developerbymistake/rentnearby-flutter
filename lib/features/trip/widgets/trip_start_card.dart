import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings_wizard.dart';

class TripStartCard extends StatelessWidget {
  final int? day;
  final bool showMap;

  const TripStartCard({super.key, this.day, this.showMap = false});

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      c.plan.value;
      c.enquiryList.length;
      c.trip.value;
      final d = day;
      final s = d == null ? c.comingBackStart : c.startOf(d);
      final note = s.changedNote;
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: TripColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TripColors.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: TripColors.accent.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Icon(d == null ? Iconsax.home_2 : Iconsax.flag, size: 16, color: TripColors.accentDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    d == null ? TripStringsWizard.leaveFrom : TripStringsWizard.dayStartsHere(d),
                    maxLines: 1,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.textLight),
                  ),
                  Text(
                    s.heading,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  if (s.line.isNotEmpty)
                    Text(
                      s.line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium),
                    ),
                  if (s.routeNote != null)
                    Text(
                      s.routeNote!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
                    ),
                  if (note != null && note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.warningText),
                      ),
                    ),
                ],
              ),
            ),
            if (showMap && d != null)
              TextButton(
                onPressed: () => TripNavigation.openMap(day: d, tripId: c.trip.value?.id),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text(
                  TripStringsWizard.seeRoute,
                  maxLines: 1,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: TripColors.accentDark),
                ),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      );
    });
  }
}
