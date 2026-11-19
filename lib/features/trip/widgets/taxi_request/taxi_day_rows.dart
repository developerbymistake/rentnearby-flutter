import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';

import '../../models/taxi_request_models.dart';
import '../../models/trip_plan_model.dart';
import '../../trip_strings_taxi_request.dart';
import '../../utils/trip_clock.dart';
import 'taxi_request_look.dart';
import 'taxi_switch.dart';

class TaxiRequestDayRow {
  const TaxiRequestDayRow({required this.day, required this.leg, required this.city, required this.places, this.km, this.past = false});

  final int day;
  final int leg;
  final String city;
  final List<String> places;
  final int? km;
  final bool past;

  static List<TaxiRequestDayRow> fromPlan(TripPlan plan, {List<TaxiDayStat> stats = const [], DateTime? today}) {
    final kmByDay = {for (final s in stats) s.day: s.km};
    final start = plan.settings.startDate;
    final now = today ?? TripClock.today();
    return [
      for (final d in plan.days)
        TaxiRequestDayRow(
          day: d.day,
          leg: d.leg,
          city: _city(plan, d.leg),
          places: [for (final s in d.spots) s.name],
          km: kmByDay[d.day],
          past: start != null && TripClock.daysBetween(start, now) >= d.day,
        ),
    ];
  }

  static String _city(TripPlan plan, int leg) {
    for (final l in plan.legs) {
      if (l.index == leg) return l.cityName;
    }
    return plan.cityName;
  }
}

class TaxiDayRows extends StatelessWidget {
  const TaxiDayRows({super.key, required this.rows, required this.selected, required this.onToggle});

  static Set<int> pastOf(List<TaxiRequestDayRow> rows) => {for (final r in rows) if (r.past) r.day};

  final List<TaxiRequestDayRow> rows;
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final groups = <List<TaxiRequestDayRow>>[];
    for (final r in rows) {
      if (groups.isNotEmpty && groups.last.first.leg == r.leg) {
        groups.last.add(r);
      } else {
        groups.add([r]);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var g = 0; g < groups.length; g++) ...[
          Gap.v(20),
          Row(
            children: [
              Expanded(
                child: Text(groups[g].first.city, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, Ink3D.body, letterSpacing: 0)),
              ),
              Text(TripStringsTaxiRequest.groupDays(groups[g].length), style: Ink3D.text(13, FontWeight.w500, TripLook.mutedText, letterSpacing: 0)),
            ],
          ),
          for (final r in groups[g]) ...[
            Gap.v(12),
            _DayRow(row: r, on: !r.past && selected.contains(r.day), onToggle: r.past ? null : () => onToggle(r.day)),
          ],
        ],
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.row, required this.on, required this.onToggle});

  final TaxiRequestDayRow row;
  final bool on;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    final sub = Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, height: 1.5, letterSpacing: 0);
    return Opacity(
      opacity: row.past ? 0.55 : 1,
      child: Container(
        key: ValueKey('taxi_day_${row.day}'),
        padding: DS.sym(h: 14, v: 12),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.br(TripCustomizeLook.errorRadius),
          boxShadow: DS.shadows(TaxiRequestLook.dayRow),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: DS.s(28),
              height: DS.s(28),
              margin: EdgeInsets.only(top: DS.s(2)),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tone.g2, shape: BoxShape.circle),
              child: Text('${row.day}', style: Ink3D.text(12.5, FontWeight.w700, DesignColors.textInverse, letterSpacing: 0)),
            ),
            Gap.h(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TripStringsTaxiRequest.dayTitle(row.day, row.city),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0),
                  ),
                  if (row.places.isNotEmpty) Text(row.places.join(', '), maxLines: 3, overflow: TextOverflow.ellipsis, style: sub),
                  if (row.past)
                    Text(TripStringsTaxiRequest.dayPassed, key: ValueKey('taxi_day_past_${row.day}'), style: Ink3D.text(12.5, FontWeight.w600, Ink3D.sub))
                  else if (row.km != null)
                    Text(TripStringsTaxiRequest.aboutKm(row.km!), style: sub),
                ],
              ),
            ),
            Gap.h(12),
            TaxiSwitch(
              key: ValueKey('taxi_day_switch_${row.day}'),
              value: on,
              semanticsLabel: TripStringsTaxiRequest.dayTitle(row.day, row.city),
              onChanged: onToggle == null ? null : (_) => onToggle!(),
            ),
          ],
        ),
      ),
    );
  }
}
