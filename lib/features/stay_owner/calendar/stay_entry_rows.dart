import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../../utils/money_format.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/money/money_notes_fields.dart';
import '../../owner_core/pricing/special_price_math.dart';
import '../stay_owner_deps.dart';
import '../strings/stay_calendar_strings.dart';
import '../strings/stay_special_price_strings.dart';
import '../widgets/stay_widgets.dart';
import 'models/stay_calendar_models.dart';
import 'widgets/stay_calendar_widgets.dart';

abstract final class StayEntryText {
  static int nights(CalendarEntry e) {
    final f = e.dateFrom;
    final t = e.dateTo;
    if (f == null || t == null) return 0;
    final n = OwnerDates.daysBetween(f, t);
    return n < 0 ? 0 : n;
  }

  static int blockDays(CalendarBlock b) {
    final f = b.dateFrom;
    final t = b.dateTo;
    if (f == null || t == null) return 0;
    return OwnerDates.daysBetween(f, t) + 1;
  }

  static String roomPart(String? detail) {
    if (detail == null || detail.isEmpty) return '';
    final i = detail.indexOf(' · ');
    return i < 0 ? detail : detail.substring(0, i);
  }

  static String label(CalendarEntry e) => e.travellerRemoved ? StayCalendarStrings.travellerRemoved : e.label;

  static String range(CalendarEntry e) {
    final f = e.dateFrom;
    return f == null ? '' : StayCalendarStrings.rangeDash(f, e.dateTo);
  }

  static String upcomingSub(CalendarEntry e, {bool nightsForManual = true}) {
    final r = range(e);
    if (e.isAuto) {
      final room = e.roomNames ?? roomPart(e.detail);
      return room.isEmpty ? r : '$r · $room';
    }
    if (!nightsForManual) return r;
    final n = nights(e);
    return n <= 0 ? r : '$r · ${StayCalendarStrings.nights(n)}';
  }

  static String amountSub(CalendarEntry e) {
    final r = range(e);
    final f = e.finalAmount;
    return f == null ? r : '$r · ${Money.exact(f)}';
  }

  static String spoken(CalendarEntry e) {
    final f = e.dateFrom;
    final t = e.dateTo ?? f;
    final parts = <String>[label(e)];
    if (f != null && t != null) parts.add('${StayCalendarStrings.spokenDate(f)} to ${StayCalendarStrings.spokenDate(t)}');
    final room = e.isAuto ? (e.roomNames ?? roomPart(e.detail)) : '';
    if (room.isNotEmpty) parts.add(room);
    parts.add(e.isAuto ? StayCalendarStrings.fromApp : StayCalendarStrings.addedByYou);
    if (e.cancelled) parts.add(StayCalendarStrings.cancelled);
    return parts.join(', ');
  }
}

abstract final class StayEntryRows {
  static void open(CalendarEntry e) => StayOwnerDeps.openEntry(e.id);

  static void openBlock(CalendarBlock b) => Get.toNamed(AppRoutes.stayCalendarEntry, arguments: {'id': b.id, 'kind': 'block'});

  static List<Widget> chips(CalendarEntry e) => [
        StayKindChip.of(e),
        if (e.cancelled) StayKindChip.cancelled,
      ];

  static Widget? money(CalendarEntry e) {
    final text = BalanceChip.textOf(e.chip, e.chipAmount);
    return text == null ? null : BalanceChip(chip: e.chip, amount: e.chipAmount);
  }

  static Widget upcoming(CalendarEntry e) {
    final f = e.dateFrom ?? DateTime(2000);
    return StayEntryRow(
      tileTop: '${f.day}',
      tileBottom: StayCalendarStrings.shortUpper(f),
      kind: StayTileLook.of(e),
      title: StayEntryText.label(e),
      sub: StayEntryText.upcomingSub(e, nightsForManual: false),
      chips: chips(e),
      trailing: e.cancelled ? money(e) : null,
      dim: e.cancelled,
      semantics: StayEntryText.spoken(e),
      onTap: () => open(e),
    );
  }

  static Widget home(CalendarEntry e) {
    final f = e.dateFrom ?? DateTime(2000);
    return StayEntryRow(
      tileTop: '${f.day}',
      tileBottom: StayCalendarStrings.shortUpper(f),
      kind: StayTileLook.of(e),
      title: StayEntryText.label(e),
      sub: StayEntryText.upcomingSub(e),
      chips: chips(e),
      dim: e.cancelled,
      semantics: StayEntryText.spoken(e),
      onTap: () => open(e),
    );
  }

  static Widget month(CalendarEntry e) {
    final f = e.dateFrom ?? DateTime(2000);
    return StayEntryRow(
      tileTop: '${f.day}',
      tileBottom: StayCalendarStrings.shortUpper(f),
      kind: StayTileLook.of(e),
      title: StayEntryText.label(e),
      sub: StayEntryText.amountSub(e),
      chips: chips(e),
      trailing: money(e),
      semantics: StayEntryText.spoken(e),
      onTap: () => open(e),
    );
  }

  static Widget own(CalendarEntry e) {
    final f = e.dateFrom ?? DateTime(2000);
    return StayEntryRow(
      tileTop: '${f.day}',
      tileBottom: StayCalendarStrings.shortUpper(f),
      kind: StayTileKind.own,
      title: e.label,
      sub: StayEntryText.upcomingSub(e),
      chips: chips(e),
      trailing: money(e),
      semantics: StayEntryText.spoken(e),
      onTap: () => open(e),
    );
  }

  static Widget past(CalendarEntry e) {
    final f = e.dateFrom ?? DateTime(2000);
    return StayEntryRow(
      tileTop: '${f.day}',
      tileBottom: StayCalendarStrings.shortUpper(f),
      kind: StayTileLook.of(e),
      title: StayEntryText.label(e),
      sub: StayEntryText.upcomingSub(e),
      chips: [...chips(e), ?money(e)],
      dim: e.cancelled,
      semantics: StayEntryText.spoken(e),
      onTap: () => open(e),
    );
  }

  static Widget block(CalendarBlock b, {bool past = false}) {
    final f = b.dateFrom ?? DateTime(2000);
    final t = b.dateTo ?? f;
    final days = StayEntryText.blockDays(b);
    final range = StayCalendarStrings.rangeDash(f, t);
    final reason = b.reason ?? StayCalendarStrings.legendBlocked;
    return StayEntryRow(
      tileTop: '${f.day}',
      tileBottom: StayCalendarStrings.shortUpper(f),
      kind: StayTileKind.blocked,
      title: reason,
      sub: past ? '$range · ${StayCalendarStrings.onlyYouSaw}' : (days >= 1 ? '$range · ${StayCalendarStrings.days(days)}' : range),
      chips: const [StayKindChip.blocked],
      semantics: '$reason, ${StayCalendarStrings.spokenDate(f)} to ${StayCalendarStrings.spokenDate(t)}, ${StayCalendarStrings.legendBlocked}',
      onTap: () => openBlock(b),
    );
  }

  static Widget blockPlain(CalendarBlock b) {
    final f = b.dateFrom ?? DateTime(2000);
    final t = b.dateTo ?? f;
    return StayEntryRow(
      tileTop: '${f.day}',
      tileBottom: StayCalendarStrings.shortUpper(f),
      kind: StayTileKind.blocked,
      title: b.reason ?? StayCalendarStrings.legendBlocked,
      sub: StayCalendarStrings.rangeDash(f, t),
      chips: const [StayKindChip.blocked],
      onTap: () => openBlock(b),
    );
  }

  static Widget due(CalendarEntry e, {bool divider = false}) {
    final body = Padding(
      padding: DS.sym(v: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(StayEntryText.label(e), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                Text('${StayEntryText.range(e)} · ${e.isAuto ? StayCalendarStrings.fromApp : StayCalendarStrings.addedByYou}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
              ],
            ),
          ),
          Gap.h(8),
          ?money(e),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: StayEntryText.spoken(e),
      child: InkWell(
        onTap: () => open(e),
        child: Container(
          decoration: divider ? BoxDecoration(border: Border(top: BorderSide(color: StayLook.rowLine, width: DS.s(1)))) : null,
          child: body,
        ),
      ),
    );
  }

  static Widget rule(SpecialPriceBand r) {
    final f = r.dateFrom ?? DateTime(2000);
    final t = r.dateTo ?? f;
    final name = r.label ?? StaySpecialPriceStrings.yourDates;
    final lower = r.direction == PriceDirection.lower;
    final known = r.direction != PriceDirection.unknown;
    final range = StaySpecialPriceStrings.rangeTo(f, t);
    final chip = r.pausedByPlan
        ? StaySoftChip(label: StaySpecialPriceStrings.pausedOnFree, bg: StayLook.rowLine, fg: Ink3D.grey)
        : StaySoftChip(label: r.isPaused ? StaySpecialPriceStrings.paused : StaySpecialPriceStrings.live, bg: StayLook.greenSoft, fg: StayLook.greenText);
    return Semantics(
      button: true,
      label: name,
      child: InkWell(
        onTap: () => StayOwnerDeps.openSpecialPrice(),
        child: Padding(
          padding: DS.sym(h: 14, v: 12),
          child: Row(
            children: [
              ExcludeSemantics(child: Art3D(asset: r.label == null ? ListingArt.calendar : ListingArt.star, size: 30)),
              Gap.h(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                    Text(known ? StaySpecialPriceStrings.ruleLine(range, r.percent, lower) : range,
                        style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                  ],
                ),
              ),
              Gap.h(8),
              chip,
            ],
          ),
        ),
      ),
    );
  }

  static String priceLine(SpecialPriceBand r, List<StayPriceRoom> rooms) {
    if (r.direction == PriceDirection.unknown) return '';
    final lower = r.direction == PriceDirection.lower;
    return rooms
        .take(2)
        .map((room) => StaySpecialPriceStrings.priceStep(room.shortName, room.basePrice, SpecialPriceMath.adjust(room.basePrice, lower, r.percent)))
        .join(' · ');
  }
}
