import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:get/get.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_mca_n2.dart';
import 'trip_leg_menu_sheet.dart';

const _more = 'More';

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
      final line = spots > 0 ? '$range\n${TripStringsMcaA3.spots(spots)} · $nights' : '$range\n$nights';
      final menu = !c.isReadOnly && !c.needsUpdate.value;
      final unavailable = c.legUnavailable(legIndex);
      final tone = ListingTone.indigo;
      return Column(
        key: anchorKey,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WideCard(
            tone: tone,
            kind: WideKind.slim,
            art: ListingArt.mountain,
            title: leg.cityName,
            subtitle: line,
            trailingWidth: 48,
            trailing: menu
                ? Tooltip(
                    message: _more,
                    excludeFromSemantics: true,
                    child: Tap3D(
                      onTap: () => TripLegMenuSheet.show(context, legIndex),
                      label: _more,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(color: DesignColors.surface, shape: BoxShape.circle, boxShadow: Ink3D.whiteBtn),
                            child: Icon(Icons.more_vert_rounded, color: tone.text),
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          if (unavailable)
            Banner3D(
              kind: BannerKind.bad,
              art: ListingArt.mountain,
              title: TripStringsMcaN2.cityUnavailable,
              actionLabel: menu ? TripStringsMcaA3.removeCity : null,
              onAction: menu ? () => TripLegMenuSheet.show(context, legIndex) : null,
              margin: const EdgeInsets.fromLTRB(18, 0, 18, 6),
            ),
        ],
      );
    });
  }
}
