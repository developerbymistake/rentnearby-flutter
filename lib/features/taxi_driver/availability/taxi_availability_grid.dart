import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../owner_core/calendar/month_grid_data.dart';
import '../../owner_core/look/owner_look.dart';
import '../calendar/taxi_calendar_widgets.dart';
import '../strings/taxi_availability_strings.dart';
import 'taxi_availability_models.dart';

class TaxiAvailDayBox extends StatelessWidget {
  const TaxiAvailDayBox({super.key, required this.cell, required this.state, this.onTap});

  final DayCell cell;
  final TaxiAvailDay state;
  final ValueChanged<DayCell>? onTap;

  static String semanticsOf(DayCell c, TaxiAvailDay s) {
    final base = TaxiAvailabilityStrings.dayLabel(c.date);
    return switch (s) {
      TaxiAvailDay.off => '$base, ${TaxiAvailabilityStrings.legendOff}',
      TaxiAvailDay.booked => '$base, ${TaxiAvailabilityStrings.legendBooked}',
      _ => base,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!cell.inMonth) return SizedBox(height: DS.s(42));
    final radius = DS.circular(10);
    final off = state == TaxiAvailDay.off;
    final fill = switch (state) {
      TaxiAvailDay.past => OwnerLook.pastDay,
      TaxiAvailDay.booked => Color.alphaBlend(TaxiCal.greenFill, DesignColors.surface),
      TaxiAvailDay.off => null,
      TaxiAvailDay.free => DesignColors.surface,
    };
    final ink = switch (state) {
      TaxiAvailDay.past => OwnerLook.pastText,
      TaxiAvailDay.booked => TaxiCal.greenText,
      TaxiAvailDay.off => DesignColors.onPrimary,
      TaxiAvailDay.free => Ink3D.title,
    };
    final today = cell.isToday;
    final numberInk = today && !off ? TaxiCal.accent : ink;
    final dot = DS.s(5);
    Widget box = Container(
      height: DS.s(42),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: fill,
        gradient: off ? TaxiCal.hero : null,
        border: today ? Border.all(color: TaxiCal.ownDot, width: DS.s(2)) : null,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${cell.date.day}', maxLines: 1, style: Ink3D.text(12.5, today ? FontWeight.w700 : FontWeight.w600, numberInk, letterSpacing: 0)),
            SizedBox(height: DS.s(2)),
            SizedBox(
              height: dot,
              child: state == TaxiAvailDay.booked
                  ? Container(width: dot, height: dot, decoration: const BoxDecoration(color: TaxiCal.appDot, shape: BoxShape.circle))
                  : null,
            ),
          ],
        ),
      ),
    );
    final tap = onTap;
    final tappable = state != TaxiAvailDay.past && tap != null;
    if (tappable) box = InkWell(borderRadius: radius, onTap: () => tap(cell), child: box);
    return Semantics(button: tappable, enabled: tappable, label: semanticsOf(cell, state), excludeSemantics: true, child: box);
  }
}

class TaxiAvailLegend extends StatelessWidget {
  const TaxiAvailLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget mark({Gradient? gradient, Color? color, Color? line}) => Container(
          width: DS.s(11),
          height: DS.s(11),
          decoration: BoxDecoration(
            gradient: gradient,
            color: color,
            borderRadius: DS.circular(4),
            border: line == null ? null : Border.all(color: line, width: DS.s(1)),
          ),
        );
    Widget item(Widget m, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          m,
          Gap.h(5),
          Flexible(child: Text(text, style: Ink3D.text(10.5, FontWeight.w600, Ink3D.sub, letterSpacing: 0))),
        ]);
    return Wrap(
      spacing: DS.gh(14),
      runSpacing: DS.gv(4),
      children: [
        item(mark(gradient: TaxiCal.hero), TaxiAvailabilityStrings.legendOff),
        item(mark(color: Color.alphaBlend(TaxiCal.greenFill, DesignColors.surface), line: TaxiCal.appDot), TaxiAvailabilityStrings.legendBooked),
      ],
    );
  }
}
