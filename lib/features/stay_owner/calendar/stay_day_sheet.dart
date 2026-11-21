import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/pricing/special_price_math.dart';
import '../../owner_core/sheets/owner_sheet.dart';
import '../stay_owner_deps.dart';
import '../strings/stay_calendar_strings.dart';
import '../strings/stay_special_price_strings.dart';
import '../widgets/stay_widgets.dart';
import 'models/stay_calendar_models.dart';
import 'stay_calendar_controller.dart';
import 'stay_entry_rows.dart';
import 'widgets/stay_calendar_widgets.dart';

abstract final class StayDaySheet {
  static Future<void> show(
    BuildContext context,
    StayCalendarController c,
    DateTime day, {
    required ValueChanged<DateTime> onAdd,
    required ValueChanged<DateTime> onBlock,
  }) async {
    final d = OwnerDates.only(day);
    final entries = c.dayEntries(d);
    final block = c.blockOn(d);
    final rule = c.ruleOn(d);
    final festival = c.festivalOn(d);
    final count = entries.length;
    final sub = festival != null ? StayCalendarStrings.festivalDay(festival.name, count) : (count == 0 ? null : StayCalendarStrings.bookingsOnDay(count));
    final canAdd = !d.isBefore(OwnerDates.addDays(c.today, -7)) && c.window.allowsManual(d);
    final canBlock = !d.isBefore(c.today);
    final rooms = c.priceRooms.toList();
    await OwnerSheet.show<void>(
      context,
      look: OwnerLook.stay,
      title: StayCalendarStrings.dayTitle(d),
      subtitle: sub,
      child: (ctx) => StayDayBody(
        day: d,
        entries: entries,
        block: block,
        rule: rule,
        festivalName: festival?.name,
        firstRoom: rooms.isEmpty ? null : rooms.first,
      ),
      footer: (ctx) => Row(
        children: [
          Expanded(
            child: PrimaryButton(
              label: StayCalendarStrings.addOnDay,
              tone: StayCalKit.green,
              compact: true,
              onPressed: canAdd
                  ? () {
                      Navigator.of(ctx).pop();
                      onAdd(d);
                    }
                  : null,
            ),
          ),
          Gap.h(10),
          Expanded(
            child: StayPill(
              label: StayCalendarStrings.blockThisDay,
              kind: canBlock ? StayPillKind.outline : StayPillKind.off,
              expand: true,
              onTap: canBlock
                  ? () {
                      Navigator.of(ctx).pop();
                      onBlock(d);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
    c.selectDay(null);
  }
}

class StayDayBody extends StatelessWidget {
  const StayDayBody({super.key, required this.day, required this.entries, this.block, this.rule, this.festivalName, this.firstRoom});

  final DateTime day;
  final List<CalendarEntry> entries;
  final CalendarBlock? block;
  final SpecialPriceBand? rule;
  final String? festivalName;
  final StayPriceRoom? firstRoom;

  @override
  Widget build(BuildContext context) {
    final b = block;
    final rows = entries.length + (b == null ? 0 : 1);
    final maxH = MediaQuery.sizeOf(context).height * 0.42;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rule != null) _RuleRow(day: day, rule: rule!, festivalName: festivalName, firstRoom: firstRoom),
        if (rows > 0)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: ListView.builder(
              shrinkWrap: true,
              padding: DS.insets(t: rule == null ? 4 : 10),
              itemCount: rows,
              itemBuilder: (context, i) {
                if (b != null && i == entries.length) return _DayCard(child: StayEntryRows.block(b));
                return _DayCard(child: _DayEntry(day: day, entry: entries[i]));
              },
            ),
          ),
        if (rule == null) ...[
          Gap.v(10),
          const _BaseBand(),
          Gap.v(10),
          StayPill(
            label: StayCalendarStrings.setPriceForDays,
            kind: StayPillKind.outline,
            expand: true,
            onTap: () {
              Navigator.of(context).pop();
              StayOwnerDeps.openSpecialPrice(dateFrom: OwnerDates.dayText(day), dateTo: OwnerDates.dayText(day));
            },
          ),
        ],
        Gap.v(8),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(bottom: DS.gv(10)),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.circular(14),
          border: Border.all(color: DesignColors.border, width: DS.s(1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _DayEntry extends StatelessWidget {
  const _DayEntry({required this.day, required this.entry});

  final DateTime day;
  final CalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final from = e.dateFrom;
    final to = e.dateTo;
    final isIn = from != null && OwnerDates.sameDay(from, day);
    final isOut = to != null && OwnerDates.sameDay(to, day);
    final range = StayEntryText.range(e);
    final room = e.isAuto ? (e.roomNames ?? StayEntryText.roomPart(e.detail)) : '';
    final nights = StayEntryText.nights(e);
    final tail = room.isNotEmpty ? ' · $room' : (!e.isAuto && !isIn && !isOut && nights > 0 ? ' · ${StayCalendarStrings.nights(nights)}' : '');
    final prefix = isIn ? '${StayCalendarStrings.checkIn} · ' : (isOut ? '${StayCalendarStrings.checkOut} · ' : '');
    final tileFrom = from ?? day;
    final bottom = isIn ? StayCalendarStrings.tileIn : (isOut ? StayCalendarStrings.tileOut : StayCalendarStrings.shortUpper(tileFrom));
    final top = isIn || isOut ? '${day.day}' : '${tileFrom.day}';
    return Padding(
      padding: DS.insets(t: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StayEntryRow(
            tileTop: top,
            tileBottom: bottom,
            kind: StayTileLook.of(e),
            title: StayEntryText.label(e),
            sub: '$prefix$range$tail',
            chips: [
              StayKindChip.of(e),
              if (e.cancelled) StayKindChip.cancelled,
              ?StayEntryRows.money(e),
            ],
            dim: e.cancelled,
            semantics: StayEntryText.spoken(e),
            trailing: StayPill(label: StayCalendarStrings.open, kind: StayPillKind.outline, onTap: () => StayEntryRows.open(e)),
            onTap: () => StayEntryRows.open(e),
          ),
        ],
      ),
    );
  }
}

class _BaseBand extends StatelessWidget {
  const _BaseBand();

  @override
  Widget build(BuildContext context) => Container(
        padding: DS.sym(h: 12, v: 10),
        decoration: BoxDecoration(
          color: StayLook.amberSoft,
          borderRadius: DS.circular(12),
          border: Border.all(color: OwnerLook.amberSoft, width: DS.s(1)),
        ),
        child: Row(
          children: [
            ExcludeSemantics(child: Art3D(asset: ListingArt.calendar, size: 26)),
            Gap.h(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(StayCalendarStrings.basePriceTitle, style: Ink3D.text(11.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                  Text(StayCalendarStrings.noSpecialPrice, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.day, required this.rule, this.festivalName, this.firstRoom});

  final DateTime day;
  final SpecialPriceBand rule;
  final String? festivalName;
  final StayPriceRoom? firstRoom;

  @override
  Widget build(BuildContext context) {
    final from = rule.dateFrom ?? day;
    final to = rule.dateTo ?? day;
    final lower = rule.direction == PriceDirection.lower;
    final label = rule.label ?? StayCalendarStrings.yourDates;
    final name = festivalName ?? label;
    final room = firstRoom;
    final line = room == null
        ? StayCalendarStrings.festivalRowTitle(label, from, to)
        : StayCalendarStrings.rulePriceLine(label, from, to, room.shortName, SpecialPriceMath.adjust(room.basePrice, lower, rule.percent));
    return Container(
      padding: DS.sym(h: 12, v: 10),
      decoration: BoxDecoration(
        color: StayLook.amberSoft,
        borderRadius: DS.circular(12),
        border: Border.all(color: OwnerLook.amberSoft, width: DS.s(1)),
      ),
      child: Row(
        children: [
          ExcludeSemantics(child: Art3D(asset: ListingArt.diyaLamp, size: 28)),
          Gap.h(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(StayCalendarStrings.rulePriceTitle(name, rule.percent, lower), style: Ink3D.text(12, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                Text(line, style: Ink3D.text(10.5, FontWeight.w500, StayLook.amberText, letterSpacing: 0)),
              ],
            ),
          ),
          Gap.h(8),
          Semantics(
            label: StaySpecialPriceStrings.a11yEdit(label),
            button: true,
            excludeSemantics: true,
            child: StayPill(
              label: StayCalendarStrings.edit,
              kind: StayPillKind.outline,
              onTap: () {
                Navigator.of(context).pop();
                StayOwnerDeps.openSpecialPrice(dateFrom: OwnerDates.dayText(from), dateTo: OwnerDates.dayText(to));
              },
            ),
          ),
        ],
      ),
    );
  }
}
