import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../calendar/taxi_calendar_widgets.dart';
import '../strings/taxi_availability_strings.dart';
import '../strings/taxi_calendar_strings.dart';
import '../strings/taxi_home_strings.dart';
import 'taxi_availability_models.dart';

class TaxiDaysOffList extends StatelessWidget {
  const TaxiDaysOffList({super.key, required this.rows, required this.onTap});

  final List<TaxiDayOff> rows;
  final ValueChanged<TaxiDayOff> onTap;

  static List<WidgetBuilder> items({required List<TaxiDayOff> rows, required ValueChanged<TaxiDayOff> onTap}) {
    if (rows.isEmpty) return [(_) => const TaxiNoDaysOffLine()];
    return [
      (_) => const TaxiTitleRow(title: TaxiAvailabilityStrings.yourDaysOff),
      for (final r in rows) (_) => TaxiDayOffRow(key: ValueKey(r.key), day: r, onTap: () => onTap(r)),
    ];
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [for (final b in items(rows: rows, onTap: onTap)) b(context)],
      );
}

class TaxiNoDaysOffLine extends StatelessWidget {
  const TaxiNoDaysOffLine({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(t: 12),
        child: Text(TaxiAvailabilityStrings.noDaysOff, style: Ink3D.text(12, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
      );
}

class TaxiDayOffRow extends StatelessWidget {
  const TaxiDayOffRow({super.key, required this.day, required this.onTap});

  final TaxiDayOff day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reason = day.reason;
    final radius = DS.circular(16);
    return Padding(
      padding: EdgeInsets.only(bottom: DS.gv(6)),
      child: DecoratedBox(
        decoration: TaxiCal.card(hero: false),
        child: Material(
          type: MaterialType.transparency,
          child: Semantics(
            button: true,
            label: '${TaxiAvailabilityStrings.dayLabel(day.date)}, ${reason ?? TaxiAvailabilityStrings.noReason}',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: Padding(
                padding: DS.sym(h: 12, v: 9),
                child: Row(
                  children: [
                    TaxiDateTile(top: '${day.date.day}', bottom: TaxiCalendarStrings.tileMonth(day.date)),
                    Gap.h(12),
                    Expanded(
                      child: Text(
                        reason ?? TaxiAvailabilityStrings.noReason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Ink3D.text(12.5, FontWeight.w400, reason == null ? Ink3D.hint : Ink3D.title, height: 1.35, letterSpacing: 0),
                      ),
                    ),
                    Gap.h(8),
                    Text(TaxiHomeStrings.chevron, style: Ink3D.text(22, FontWeight.w400, TaxiCal.accent, letterSpacing: 0)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
