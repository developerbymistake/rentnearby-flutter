import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../look/owner_look.dart';
import 'month_grid_data.dart';

class MonthGrid extends StatelessWidget {
  const MonthGrid({super.key, required this.cells, required this.weekdays, this.selected, this.onTap});

  final List<DayCell> cells;
  final List<String> weekdays;
  final DateTime? selected;
  final ValueChanged<DayCell>? onTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var r = 0; r < cells.length ~/ 7; r++) {
      final week = cells.sublist(r * 7, r * 7 + 7);
      if (r >= 4 && week.every((c) => !c.inMonth)) continue;
      rows.add(Padding(
        padding: EdgeInsets.only(top: DS.gv(6)),
        child: Row(
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) SizedBox(width: DS.gh(6)),
              Expanded(child: _DayBox(cell: week[i], selected: _isSelected(week[i]), onTap: onTap)),
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
            for (final w in weekdays)
              Expanded(
                child: Text(w,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: Ink3D.text(11, FontWeight.w600, Ink3D.grey, letterSpacing: 0)),
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

class _DayBox extends StatelessWidget {
  const _DayBox({required this.cell, required this.selected, this.onTap});

  final DayCell cell;
  final bool selected;
  final ValueChanged<DayCell>? onTap;

  @override
  Widget build(BuildContext context) {
    if (!cell.inMonth) return SizedBox(height: DS.s(40));
    final muted = cell.isPast || cell.outsideWindow;
    final textColor = selected
        ? DesignColors.onPrimary
        : cell.blocked
            ? OwnerLook.hatchText
            : muted
                ? OwnerLook.pastText
                : cell.isToday
                    ? DesignColors.primary
                    : Ink3D.title;
    final radius = DS.circular(12);
    Widget box = Container(
      height: DS.s(40),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: selected ? null : (muted ? OwnerLook.pastDay : (cell.blocked ? OwnerLook.hatch : DesignColors.surface)),
        gradient: selected ? ListingTone.indigo.gradient : null,
        border: cell.isToday && !selected ? Border.all(color: OwnerLook.todayRing, width: DS.s(2.5)) : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${cell.date.day}',
                    maxLines: 1,
                    style: Ink3D.text(13, cell.isToday ? FontWeight.w700 : FontWeight.w600, textColor, letterSpacing: 0)),
                SizedBox(height: DS.s(2)),
                _Dots(cell: cell),
              ],
            ),
          ),
          if (cell.specialPrice)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: DS.s(4),
                decoration: BoxDecoration(
                  color: OwnerLook.specialBand.withValues(alpha: muted ? Alpha.v55 : Alpha.full),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(DS.radius(12))),
                ),
              ),
            ),
        ],
      ),
    );
    if (cell.tappable && onTap != null) {
      box = InkWell(borderRadius: radius, onTap: () => onTap!(cell), child: box);
    }
    return Semantics(button: cell.tappable, label: '${cell.date.day}', child: box);
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.cell});

  final DayCell cell;

  @override
  Widget build(BuildContext context) {
    final dots = <Color>[
      if (cell.ownCount > 0) OwnerLook.ownDot,
      if (cell.appCount > 0) OwnerLook.appDot,
      if (cell.onlyCancelled) OwnerLook.cancelled,
      if (cell.blocked && !cell.hasEntries) OwnerLook.blockedDot,
    ];
    final size = DS.s(6);
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
