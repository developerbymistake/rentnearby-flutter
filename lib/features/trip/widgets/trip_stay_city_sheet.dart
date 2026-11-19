import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:flutter/material.dart';
import '../controllers/trip_plan_controller.dart';
import '../screens/trip_overview_screen.dart';
import '../trip_strings_overview.dart';
import '../trip_strings_v2_find.dart';
import 'trip_sheet_frame.dart';

class TripStayCitySheet {
  static Future<int?> pick(BuildContext context) => TripSheetFrame.show<int>(context, const _CityBody());
}

class _CityBody extends StatelessWidget {
  const _CityBody();

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    final p = c.plan.value;
    final n = p?.legCount ?? 0;
    return TripSheetFrame(
      tone: ListingTone.forest,
      title: TripStringsOverview.stayCityTitle,
      children: [
        for (var k = 1; k <= n; k++)
          InkWell(
            key: ValueKey('stay_city_$k'),
            onTap: () => Navigator.pop(context, k),
            borderRadius: DS.circular(12),
            child: ResultRow3D(
              art: ListingArt.stay,
              title: p!.cityNameOf(p.legStart(k)),
              subtitle: TripStringsV2Find.nightsText(p.legDayCount(k)),
              label: TripOverviewStay.of(c.stayEnquiriesOf(k)).chip,
              ok: TripOverviewStay.of(c.stayEnquiriesOf(k)).added,
              divider: k < n,
            ),
          ),
      ],
    );
  }
}
