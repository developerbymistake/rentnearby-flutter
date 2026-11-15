import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:get/get.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
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
        padding: EdgeInsets.only(top: DS.gv(6), bottom: DS.gv(8)),
        child: Row(
          children: [
            Container(
              width: DS.s(2),
              height: DS.s(16),
              decoration: BoxDecoration(color: TripLook.accentLight.withValues(alpha: Alpha.half), borderRadius: DS.circular(4)),
            ),
            Gap.h(8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: FitnessAppTheme.fontName, fontSize: DS.f(14), fontWeight: FontWeight.w500, letterSpacing: 0.5, color: TripLook.textLight),
              ),
            ),
          ],
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
        padding: DS.insets(l: 14, t: 14, r: 14, b: 4),
        decoration: TripLook.card(radius: TripLook.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(TripStringsV2Easy.title,
                          style: TextStyle(
                              fontFamily: FitnessAppTheme.fontName, fontSize: DS.f(16), fontWeight: FontWeight.w700, letterSpacing: 0.18, color: TripLook.textDark)),
                      Text(
                        TripEasyRules.allResolved(rows)
                            ? TripStringsV2Easy.optional
                            : (multi ? TripStringsV2Easy.groupedLine : TripStringsV2Easy.cardLine),
                        style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: DS.f(12), color: TripLook.textLight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Gap.v(10),
            ...children,
            if (c.trip.value?.id != null)
              InkWell(
                onTap: () => TripNavigation.openSummary(c.trip.value!.id),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: SizedBox(
                  height: DS.s(44),
                  child: Center(
                    child: Text(TripStringsV2Easy.viewSummary,
                        style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontWeight: FontWeight.w700, color: FitnessAppTheme.nearlyDarkBlue)),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}
