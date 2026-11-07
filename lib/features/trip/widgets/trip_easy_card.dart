import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings_v2_easy.dart';
import '../utils/trip_easy_rules.dart';
import 'trip_easy_row.dart';

class TripEasyCard extends StatelessWidget {
  const TripEasyCard({super.key});

  static String groupOf(TripPlan p, TripEasyRowInfo r) => switch (r.kind) {
        TripEasyRowKind.stay => p.legAt(r.legIndex ?? 1)?.cityName ?? p.cityName,
        TripEasyRowKind.between => TripEasyRules.betweenName(p, r.legIndex ?? 2),
        _ => TripStringsV2Easy.wholeTrip,
      };

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMedium),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final failed = c.supplyCheckFailed.length;
      final p = c.plan.value;
      if (p == null) return const SizedBox.shrink();
      final rows = c.easyRows;
      final multi = p.isMultiCity;
      final children = <Widget>[];
      String? last;
      for (final r in rows) {
        if (multi && r.kind != TripEasyRowKind.gettingThere) {
          final g = groupOf(p, r);
          if (g != last) {
            children.add(_heading(g));
            last = g;
          }
        }
        children.add(TripEasyRow(r, key: ValueKey('${r.key.id}-$failed')));
      }
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
        decoration: BoxDecoration(
          color: TripColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TripColors.accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(TripStringsV2Easy.title,
                          style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      Text(
                        TripEasyRules.allResolved(rows)
                            ? TripStringsV2Easy.optional
                            : (multi ? TripStringsV2Easy.groupedLine : TripStringsV2Easy.cardLine),
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
            if (c.trip.value?.id != null)
              TextButton(
                onPressed: () => TripNavigation.openSummary(c.trip.value!.id),
                style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                child: const Text(TripStringsV2Easy.viewSummary,
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark)),
              ),
          ],
        ),
      );
    });
  }
}
