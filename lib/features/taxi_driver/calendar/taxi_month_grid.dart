import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/calendar/month_grid_data.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../strings/taxi_availability_strings.dart';
import '../strings/taxi_calendar_strings.dart';
import 'taxi_calendar_widgets.dart';

class TaxiMonthGrid extends StatelessWidget {
  const TaxiMonthGrid({super.key, required this.cells, this.selected, this.onTap, this.offDays = const {}});

  final List<DayCell> cells;
  final DateTime? selected;
  final ValueChanged<DayCell>? onTap;
  final Set<String> offDays;

  bool _off(DayCell c) => c.inMonth && !c.isPast && !c.outsideWindow && offDays.contains(OwnerDates.dayText(c.date));

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var r = 0; r < cells.length ~/ 7; r++) {
      final week = cells.sublist(r * 7, r * 7 + 7);
      if (week.every((c) => !c.inMonth)) continue;
      rows.add(Padding(
        padding: EdgeInsets.only(top: DS.gv(6)),
        child: Row(
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) SizedBox(width: DS.gh(6)),
              Expanded(
                child: TaxiDayBox(cell: week[i], selected: _isSelected(week[i]), onTap: onTap, off: _off(week[i])),
              ),
            ],
          ],
        ),
      ));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final w in OwnerSharedStrings.weekdays)
              Expanded(
                child: Text(w, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.clip, style: Ink3D.text(10.5, FontWeight.w600, Ink3D.grey, letterSpacing: 0)),
              ),
          ],
        ),
        ...rows,
      ],
    );
  }

  bool _isSelected(DayCell c) {
    final s = selected;
    return s != null && c.inMonth && c.date.year == s.year && c.date.month == s.month && c.date.day == s.day;
  }
}

class TaxiDayBox extends StatelessWidget {
  const TaxiDayBox({super.key, required this.cell, required this.selected, this.onTap, this.off = false});

  final DayCell cell;
  final bool selected;
  final ValueChanged<DayCell>? onTap;
  final bool off;

  static String semanticsOf(DayCell c, {bool off = false}) {
    final parts = <String>['${c.date.day} ${OwnerSharedStrings.months[c.date.month - 1]}'];
    if (off) parts.add(TaxiAvailabilityStrings.legendOff);
    if (c.appCount > 0) parts.add('${c.appCount} ${TaxiCalendarStrings.legendFromApp}');
    if (c.ownCount > 0) parts.add('${c.ownCount} ${TaxiCalendarStrings.legendAddedByYou}');
    if (c.festivalName != null) parts.add(c.festivalName!);
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    if (!cell.inMonth) return SizedBox(height: DS.s(42));
    final muted = cell.isPast || cell.outsideWindow;
    final bar = !off && cell.bar != BarPart.none && cell.appCount > 0;
    final fill = off || selected
        ? TaxiCal.tileFill
        : bar
            ? Color.alphaBlend(TaxiCal.greenFill, DesignColors.surface)
            : muted
                ? OwnerLook.pastDay
                : DesignColors.surface;
    final textColor = off ? TaxiCal.accent : (muted && !bar ? OwnerLook.pastText : (bar ? TaxiCal.greenText : Ink3D.title));
    final radius = DS.circular(10);
    final ring = cell.isToday || selected;
    Widget box = Container(
      height: DS.s(42),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: fill,
        border: ring ? Border.all(color: TaxiCal.ownDot, width: DS.s(2)) : (off ? Border.all(color: TaxiCal.ownDot, width: DS.s(1.5)) : null),
      ),
      child: Stack(
        children: [
          if (cell.festivalName != null)
            Positioned(
              left: DS.s(8),
              right: DS.s(8),
              top: DS.s(4),
              child: Container(height: DS.s(2), decoration: BoxDecoration(color: TaxiCal.festival, borderRadius: DS.circular(1))),
            ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${cell.date.day}',
                    maxLines: 1, style: Ink3D.text(12.5, cell.isToday ? FontWeight.w700 : FontWeight.w600, cell.isToday ? TaxiCal.accent : textColor, letterSpacing: 0)),
                SizedBox(height: DS.s(2)),
                _Dots(cell: cell, bar: bar),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap != null) box = InkWell(borderRadius: radius, onTap: () => onTap!(cell), child: box);
    return Semantics(button: onTap != null, label: semanticsOf(cell, off: off), excludeSemantics: true, child: box);
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.cell, required this.bar});

  final DayCell cell;
  final bool bar;

  @override
  Widget build(BuildContext context) {
    final dots = <Color>[
      if (cell.ownCount > 0) TaxiCal.ownDot,
      if (cell.appCount > 0 && !bar) TaxiCal.appDot,
      if (cell.onlyCancelled) OwnerLook.cancelled,
    ];
    final size = DS.s(5);
    return SizedBox(
      height: size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < dots.length; i++) ...[
            if (i > 0) SizedBox(width: DS.s(3)),
            Container(width: size, height: size, decoration: BoxDecoration(color: dots[i], shape: BoxShape.circle)),
          ],
        ],
      ),
    );
  }
}

class TaxiLegend extends StatelessWidget {
  const TaxiLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c) => Container(width: DS.s(6), height: DS.s(6), decoration: BoxDecoration(color: c, shape: BoxShape.circle));
    Widget item(Widget mark, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          mark,
          Gap.h(5),
          Text(text, style: Ink3D.text(10.5, FontWeight.w600, Ink3D.sub, letterSpacing: 0)),
        ]);
    return Wrap(
      spacing: DS.gh(14),
      runSpacing: DS.gv(4),
      children: [
        item(dot(TaxiCal.appDot), TaxiCalendarStrings.legendFromApp),
        item(dot(TaxiCal.ownDot), TaxiCalendarStrings.legendAddedByYou),
        item(
          Container(
            width: DS.s(11),
            height: DS.s(11),
            decoration: BoxDecoration(
              color: TaxiCal.tileFill,
              borderRadius: DS.circular(4),
              border: Border.all(color: TaxiCal.ownDot, width: DS.s(1.5)),
            ),
          ),
          TaxiAvailabilityStrings.legendOff,
        ),
        item(Container(width: DS.s(12), height: DS.s(2), color: TaxiCal.festival), TaxiCalendarStrings.legendFestival),
      ],
    );
  }
}

class TaxiMonthChips extends StatelessWidget {
  const TaxiMonthChips({super.key, required this.month, required this.window, required this.today, required this.onMonth});

  final DateTime month;
  final CalendarWindow window;
  final DateTime today;
  final ValueChanged<DateTime> onMonth;

  @override
  Widget build(BuildContext context) {
    final months = window.months(today);
    if (months.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: DS.s(40),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: months.length,
        itemBuilder: (context, i) {
          final m = months[i];
          final on = m.year == month.year && m.month == month.month;
          final name = OwnerSharedStrings.monthsShort[m.month - 1];
          return Padding(
            padding: EdgeInsets.only(right: DS.gh(8)),
            child: Semantics(
              button: true,
              selected: on,
              label: OwnerSharedStrings.months[m.month - 1],
              excludeSemantics: true,
              child: InkWell(
                onTap: () => onMonth(m),
                borderRadius: DS.circular(18),
                child: Container(
                  alignment: Alignment.center,
                  padding: DS.sym(h: 14),
                  decoration: BoxDecoration(
                    gradient: on ? TaxiCal.hero : null,
                    color: on ? null : DesignColors.surface,
                    borderRadius: DS.circular(18),
                    boxShadow: DS.shadows(ShadowTokens.elev1),
                  ),
                  child: Text(name, style: Ink3D.text(12, FontWeight.w700, on ? DesignColors.onPrimary : Ink3D.title, letterSpacing: 0)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TaxiMonthPager extends StatelessWidget {
  const TaxiMonthPager({super.key, required this.month, required this.window, required this.today, required this.onMonth});

  final DateTime month;
  final CalendarWindow window;
  final DateTime today;
  final ValueChanged<DateTime> onMonth;

  Widget _arrow(IconData icon, String label, VoidCallback? onTap) => Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: DS.s(40),
            height: DS.s(40),
            decoration: BoxDecoration(color: DesignColors.surface, shape: BoxShape.circle, boxShadow: DS.shadows(Ink3D.whiteBtn)),
            child: Icon(icon, size: DS.s(24), color: onTap == null ? Ink3D.hint : TaxiCal.accent),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final months = window.months(today);
    final current = OwnerDates.firstOfMonth(month);
    final index = months.indexWhere((m) => m.year == current.year && m.month == current.month);
    final canBack = index > 0;
    final canNext = index >= 0 && index < months.length - 1;
    final locked = !canNext && window.locked && PlanGate.canUpgrade;
    return Padding(
      padding: DS.sym(v: 6),
      child: Row(
        children: [
          _arrow(Icons.chevron_left_rounded, TaxiCalendarStrings.previousMonth, canBack ? () => onMonth(months[index - 1]) : null),
          Expanded(
            child: Text(OwnerSharedStrings.monthTitle(current),
                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
          ),
          if (locked) ...[
            Semantics(
              button: true,
              label: TaxiCalendarStrings.nextMonthPlus,
              excludeSemantics: true,
              child: InkWell(
                key: GateKeys.softArrow,
                onTap: PlanGate.seePlus,
                borderRadius: DS.circular(14),
                child: Container(
                  padding: DS.sym(h: 12, v: 5),
                  decoration: BoxDecoration(
                    color: DesignColors.surface,
                    borderRadius: DS.circular(14),
                    border: Border.all(color: TaxiCal.ownDot, width: DS.s(1.2)),
                  ),
                  child: Text(OwnerSharedStrings.plus, style: Ink3D.text(11, FontWeight.w700, TaxiCal.accent, letterSpacing: 0)),
                ),
              ),
            ),
            Gap.h(8),
          ],
          _arrow(Icons.chevron_right_rounded, TaxiCalendarStrings.nextMonth, canNext ? () => onMonth(months[index + 1]) : (locked ? PlanGate.seePlus : null)),
        ],
      ),
    );
  }
}
