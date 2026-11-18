import 'package:bakhli/design/design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/taxi_request_models.dart';
import '../../models/trip_plan_model.dart';
import '../../trip_strings_taxi_request.dart';

class TaxiRequestDayRow {
  const TaxiRequestDayRow({required this.day, required this.leg, required this.city, required this.places, this.km});

  final int day;
  final int leg;
  final String city;
  final List<String> places;
  final int? km;

  static List<TaxiRequestDayRow> fromPlan(TripPlan plan, {List<TaxiDayStat> stats = const []}) {
    final kmByDay = {for (final s in stats) s.day: s.km};
    return [
      for (final d in plan.days)
        TaxiRequestDayRow(
          day: d.day,
          leg: d.leg,
          city: _city(plan, d.leg),
          places: [for (final s in d.spots) s.name],
          km: kmByDay[d.day],
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
          if (g > 0) Gap.v(14),
          Row(
            children: [
              Expanded(
                child: Text(groups[g].first.city, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, Ink3D.title)),
              ),
              Text(TripStringsTaxiRequest.groupDays(groups[g].length), style: Ink3D.text(13, FontWeight.w400, Ink3D.sub)),
            ],
          ),
          for (final r in groups[g]) ...[
            Gap.v(10),
            _DayRow(row: r, on: selected.contains(r.day), onToggle: () => onToggle(r.day)),
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
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    return Container(
      key: ValueKey('taxi_day_${row.day}'),
      padding: DS.sym(h: 12, v: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(16), boxShadow: DS.shadows(Ink3D.softShadow)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: DS.s(26),
            height: DS.s(26),
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: tone.gradient, shape: BoxShape.circle),
            child: Text('${row.day}', style: Ink3D.text(12, FontWeight.w700, DesignColors.textInverse)),
          ),
          Gap.h(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TripStringsTaxiRequest.dayTitle(row.day, row.city),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(14, FontWeight.w700, Ink3D.title),
                ),
                if (row.places.isNotEmpty)
                  Text(row.places.join(', '), maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub)),
                if (row.km != null) Text(TripStringsTaxiRequest.aboutKm(row.km!), style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub)),
              ],
            ),
          ),
          Gap.h(8),
          Semantics(
            toggled: on,
            label: TripStringsTaxiRequest.dayTitle(row.day, row.city),
            child: CupertinoSwitch(
              key: ValueKey('taxi_day_switch_${row.day}'),
              value: on,
              onChanged: (_) => onToggle(),
              activeTrackColor: tone.g2,
              inactiveTrackColor: DesignColors.switchTrackOff,
              thumbColor: DesignColors.switchThumbOff,
            ),
          ),
        ],
      ),
    );
  }
}
