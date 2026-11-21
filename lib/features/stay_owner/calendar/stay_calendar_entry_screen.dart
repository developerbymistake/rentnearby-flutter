import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/money_format.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_args.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/money/edit_amounts_sheet.dart';
import '../../owner_core/money/money_note_math.dart';
import '../../owner_core/money/money_notes_fields.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/sheets/owner_confirm.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../stay_owner_deps.dart';
import '../strings/stay_calendar_strings.dart';
import '../widgets/stay_widgets.dart';
import 'models/stay_calendar_models.dart';
import 'stay_calendar_controller.dart';
import 'stay_entry_rows.dart';
import 'stay_entry_sheet.dart';
import 'widgets/stay_calendar_widgets.dart';

sealed class StayEntryView {
  const StayEntryView();
}

class StayEntryViewEntry extends StayEntryView {
  const StayEntryViewEntry(this.entry);
  final CalendarEntry entry;
}

class StayEntryViewBlock extends StayEntryView {
  const StayEntryViewBlock(this.block, this.meter);
  final CalendarBlock block;
  final Meter? meter;
}

class StayCalendarEntryScreen extends StatefulWidget {
  const StayCalendarEntryScreen({super.key, this.args = const {}, this.controller});

  final Map<String, dynamic> args;
  final StayCalendarController? controller;

  @override
  State<StayCalendarEntryScreen> createState() => _StayCalendarEntryScreenState();
}

class _StayCalendarEntryScreenState extends State<StayCalendarEntryScreen> {
  static const String tag = 'stay-calendar-entry';
  late final StayCalendarController c;
  bool _owns = false;
  final LatestOnly _latest = LatestOnly();
  OwnerLoad<StayEntryView> _load = const OwnerLoadLoading();

  String? get _id => OwnerArgs.text(widget.args, 'id');
  bool get _isBlock => OwnerArgs.text(widget.args, 'kind') == 'block';

  @override
  void initState() {
    super.initState();
    final given = widget.controller ?? StayCalendarController.maybe;
    if (given != null) {
      c = given;
    } else {
      _owns = true;
      c = Get.put(StayCalendarController(), tag: tag);
    }
    _fetch();
  }

  @override
  void dispose() {
    _latest.cancel();
    if (_owns && Get.isRegistered<StayCalendarController>(tag: tag)) Get.delete<StayCalendarController>(tag: tag, force: true);
    super.dispose();
  }

  Future<void> _fetch() async {
    final id = _id;
    if (id == null) {
      setState(() => _load = const OwnerLoadError());
      return;
    }
    final seq = _latest.next();
    if (_isBlock) {
      final r = await c.blockApi.list();
      if (!mounted || !_latest.isLatest(seq)) return;
      final mapped = switch (r) {
        OwnerOk<StayBlockList>(:final value) => _blockView(value, id),
        _ => OwnerLoads.from<StayEntryView>(_cast(r)),
      };
      setState(() => _load = mapped);
      return;
    }
    final r = await c.api.entry(id);
    if (!mounted || !_latest.isLatest(seq)) return;
    setState(() {
      _load = switch (r) {
        OwnerOk<CalendarEntry>(:final value) => value.valid ? OwnerLoadData(StayEntryViewEntry(value)) : const OwnerLoadError(),
        _ => OwnerLoads.from<StayEntryView>(_cast(r)),
      };
    });
  }

  static OwnerResult<StayEntryView> _cast(OwnerResult<dynamic> r) => switch (r) {
        OwnerRefused() => r.cast<StayEntryView>(),
        OwnerOffline() => OwnerOffline<StayEntryView>(),
        OwnerFailed(:final message) => OwnerFailed<StayEntryView>(message: message),
        OwnerOk() => OwnerFailed<StayEntryView>(message: ''),
      };

  OwnerLoad<StayEntryView> _blockView(StayBlockList list, String id) {
    for (final b in list.items) {
      if (b.id == id) return OwnerLoadData(StayEntryViewBlock(b, Meter.find(list.meters, StayMeterKeys.blocks) ?? c.meter(StayMeterKeys.blocks)));
    }
    return const OwnerLoadError();
  }

  @override
  Widget build(BuildContext context) {
    final view = _load.valueOrNull;
    final entry = view is StayEntryViewEntry ? view.entry : null;
    final block = view is StayEntryViewBlock ? view.block : null;
    final title = block != null || _isBlock ? StayCalendarStrings.blockedDaysTitle : StayCalendarStrings.bookingTitle;
    final sub = block != null || _isBlock
        ? StayCalendarStrings.blockedDaysSub
        : entry == null
            ? null
            : entry.isAuto
                ? (entry.cancelled ? StayCalendarStrings.fromTheAppCancelled : StayCalendarStrings.fromTheApp)
                : StayCalendarStrings.addedByYou;
    return Scaffold(
      backgroundColor: OwnerLook.stay.page,
      body: Column(
        children: [
          StayCalHeader(title: title, subtitle: sub),
          Expanded(
            child: OwnerStateView<StayEntryView>(
              load: _load,
              look: OwnerLook.stay,
              words: const OwnerStateWords(),
              onRetry: _fetch,
              data: (context, v, stale) => RefreshIndicator(
                onRefresh: _fetch,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: DS.s(24)),
                  children: [
                    if (stale) const OwnerStaleLine(),
                    ...switch (v) {
                      StayEntryViewEntry(:final entry) => _entryBody(entry),
                      StayEntryViewBlock(:final block, :final meter) => _blockBody(block, meter),
                    },
                  ],
                ),
              ),
            ),
          ),
          if (entry != null) _entryBar(entry),
          if (block != null) _blockBar(block),
        ],
      ),
    );
  }

  List<Widget> _entryBody(CalendarEntry e) {
    final from = e.dateFrom ?? c.today;
    final to = e.dateTo ?? from;
    final nights = StayEntryText.nights(e);
    final deletesOn = OwnerDates.addDays(to, 90);
    final room = e.roomNames;
    final money = e.money;
    final hasMoney = e.finalAmount != null || e.receivedSoFar != null || e.paidInFull;
    final balance = MoneyNoteMath.balance(money);
    final chip = e.chip;
    final top = Container(
      margin: DS.insets(l: 18, t: 16, r: 18),
      padding: DS.insets(l: 14, t: 14, r: 14, b: 6),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: StayLook.cardRadius(34), boxShadow: DS.shadows(ShadowTokens.elev1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(child: Art3D(asset: e.isAuto ? ListingArt.calendar : ListingArt.memo, size: 44)),
              Gap.h(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(StayCalendarStrings.rangeDash(from, to), style: Ink3D.text(22, FontWeight.w800, Ink3D.title, letterSpacing: 0)),
                    Text('${StayEntryText.label(e)} · ${StayCalendarStrings.nights(nights)}', style: Ink3D.text(11.5, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                  ],
                ),
              ),
            ],
          ),
          Gap.v(8),
          Wrap(spacing: DS.gh(6), runSpacing: DS.gv(4), children: [
            StayKindChip.of(e),
            if (e.isAuto && !e.cancelled) const StayKindChip(label: StayCalendarStrings.confirmed, kind: StayTileKind.own),
            if (e.cancelled) StayKindChip.cancelled,
            if (!e.isAuto) StaySoftChip(label: StayCalendarStrings.deletesOn(deletesOn), bg: StayLook.rowLine, fg: Ink3D.sub),
          ]),
          Gap.v(6),
          if (e.isAuto) ...[
            if (!e.cancelled) ...[
              StayKv(label: StayCalendarStrings.checkIn, value: StayCalendarStrings.weekdayDate(from)),
              StayKv(label: StayCalendarStrings.checkOut, value: StayCalendarStrings.weekdayDate(to)),
            ],
            if (e.guests != null) StayKv(label: StayCalendarStrings.guests, value: StayCalendarStrings.guestsCount(e.guests ?? 0)),
            if (room != null && room.isNotEmpty) StayKv(label: StayCalendarStrings.room, value: room),
            if (e.guests == null && e.roomNames == null && (e.detail ?? '').isNotEmpty) StayKv(label: StayCalendarStrings.detail, value: e.detail ?? ''),
            if (e.listedTotal != null) StayKv(label: StayCalendarStrings.listedWhenAsked, value: Money.exact(e.listedTotal ?? 0)),
            if (e.cancelled && e.cancelledBy != null && e.cancelledOn != null)
              StayKv(label: StayCalendarStrings.cancelled, value: StayCalendarStrings.cancelledBy(e.cancelledBy ?? '', e.cancelledOn ?? from)),
          ] else ...[
            StayKv(label: StayCalendarStrings.from, value: StayCalendarStrings.weekdayDate(from)),
            StayKv(label: StayCalendarStrings.to, value: StayCalendarStrings.weekdayDate(to)),
            if ((e.note ?? '').isNotEmpty) StayKv(label: StayCalendarStrings.note, value: e.note ?? ''),
          ],
          Padding(
            padding: DS.insets(t: 12, b: 8),
            child: Row(children: [
              Expanded(child: Text(StayCalendarStrings.moneyNotes, style: Ink3D.text(12.5, FontWeight.w800, Ink3D.title, letterSpacing: 0))),
              StaySoftChip(label: StayCalendarStrings.onlyYouSee, bg: StayLook.tealSoft, fg: StayLook.tealDeep.text),
            ]),
          ),
          Container(
            padding: DS.sym(h: 12, v: 2),
            margin: DS.insets(b: 10),
            decoration: BoxDecoration(color: DesignColors.surfaceAlt, borderRadius: DS.circular(12)),
            child: Column(children: [
              StayKv(label: StayCalendarStrings.finalAmount, value: e.finalAmount == null ? StayCalendarStrings.dash : Money.exact(e.finalAmount ?? 0), divider: false),
              StayKv(label: StayCalendarStrings.receivedSoFar, value: hasMoney ? Money.exact(MoneyNoteMath.received(money)) : StayCalendarStrings.dash),
              StayKv(label: StayCalendarStrings.balanceToCollect, value: balance == null || e.cancelled ? StayCalendarStrings.dash : Money.exact(balance)),
              StayKv(
                label: StayCalendarStrings.status,
                value: '',
                trailing: BalanceChip.textOf(chip, e.chipAmount) == null ? Text(StayCalendarStrings.dash, style: Ink3D.text(12, FontWeight.w700, Ink3D.title)) : BalanceChip(chip: chip, amount: e.chipAmount),
              ),
            ]),
          ),
        ],
      ),
    );
    final kept = e.cancelled && e.received > 0;
    return [
      top,
      if (e.isAuto)
        StayNote(
          art: ListingArt.pushpin,
          text: kept ? StayCalendarStrings.cancelledKept(Money.exact(e.received)) : StayCalendarStrings.appNote,
        )
      else
        const StaySmallLine(text: StayCalendarStrings.manualPrivacy),
      StaySmallLine(
        art: ListingArt.alarmClock,
        text: e.cancelled ? StayCalendarStrings.removedOn(deletesOn) : StayCalendarStrings.removed90,
      ),
    ];
  }

  Widget _entryBar(CalendarEntry e) {
    if (e.isAuto) {
      return StayCalBar(
        primary: StayCalendarStrings.openEnquiry,
        secondary: StayCalendarStrings.editAmounts,
        onPrimary: () {
          final src = e.sourceId;
          if (src == null || e.sourceAvailable == false) {
            AppToast.info(StayCalendarStrings.enquiryGone);
            return;
          }
          StayOwnerDeps.openEnquiry(src);
        },
        onSecondary: () => _editAmounts(e),
      );
    }
    return StayCalBar(
      primary: StayCalendarStrings.editBooking,
      secondary: StayCalendarStrings.delete,
      secondaryDanger: true,
      onPrimary: () async {
        await StayEntrySheet.edit(context, c, e);
        if (mounted) _fetch();
      },
      onSecondary: () => _delete(e),
    );
  }

  Future<void> _editAmounts(CalendarEntry e) async {
    final saved = await EditAmountsSheet.show(
      context,
      look: OwnerLook.stay,
      words: const EditAmountsWords(title: StayCalendarStrings.editAmounts, finalHint: StayCalendarStrings.wholeStay, save: StayCalendarStrings.save),
      initial: e.money,
      save: (n) => c.saveMoney(e, finalAmount: n.finalAmount, receivedSoFar: n.paidInFull ? null : n.receivedSoFar, paidInFull: n.paidInFull),
    );
    if (mounted && (saved || c.staleLine.value)) _fetch();
  }

  Future<void> _delete(CalendarEntry e) async {
    final ok = await OwnerConfirm.ask(
      context,
      title: StayCalendarStrings.deleteTitle,
      confirm: StayCalendarStrings.delete,
      cancel: StayCalendarStrings.cancel,
      destructive: true,
      tone: ListingTone.forest,
    );
    if (!ok || !mounted) return;
    final r = await c.delete(e.id);
    if (!mounted) return;
    if (r is OwnerOk<void>) {
      Navigator.of(context).maybePop();
    } else {
      AppToast.error(r is OwnerRefused<void> ? (r.message ?? OwnerSharedStrings.noConnection) : OwnerSharedStrings.noConnection);
    }
  }

  List<Widget> _blockBody(CalendarBlock b, Meter? meter) {
    final from = b.dateFrom ?? c.today;
    final to = b.dateTo ?? from;
    final nights = OwnerDates.daysBetween(from, to) + 1;
    return [
      Container(
        margin: DS.insets(l: 18, t: 16, r: 18),
        padding: DS.insets(l: 14, t: 14, r: 14, b: 6),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: StayLook.cardRadius(34), boxShadow: DS.shadows(ShadowTokens.elev1)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              ExcludeSemantics(child: Art3D(asset: ListingArt.locked, size: 40)),
              Gap.h(12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(StayCalendarStrings.rangeDash(from, to), style: Ink3D.text(22, FontWeight.w800, Ink3D.title, letterSpacing: 0)),
                  Text(StayCalendarStrings.nights(nights), style: Ink3D.text(11.5, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                ]),
              ),
            ]),
            Gap.v(8),
            const Align(alignment: Alignment.centerLeft, child: StayKindChip.blocked),
            Gap.v(6),
            if ((b.reason ?? '').isNotEmpty) StayKv(label: StayCalendarStrings.reason, value: b.reason ?? ''),
            const StayKv(label: StayCalendarStrings.guestsSee, value: StayCalendarStrings.fullOnYourDates),
            if (meter != null)
              StayKv(
                label: PlanGate.canUpgrade ? StayCalendarStrings.blocksOnFree : StayCalendarStrings.blocksMeter,
                value: StayCalendarStrings.meterCount(meter.used, meter.limit),
              ),
          ],
        ),
      ),
      const StayNote(text: StayCalendarStrings.blockDetailNote),
      const StaySmallLine(art: ListingArt.alarmClock, text: StayCalendarStrings.blockRemoved90),
    ];
  }

  Widget _blockBar(CalendarBlock b) => StayCalBar(
        primary: StayCalendarStrings.edit,
        secondary: StayCalendarStrings.removeBlock,
        secondaryDanger: true,
        onPrimary: () async {
          await StayEntrySheet.editBlock(context, c, b);
          if (mounted) _fetch();
        },
        onSecondary: () async {
          final ok = await OwnerConfirm.ask(
            context,
            title: StayCalendarStrings.removeBlockTitle,
            confirm: StayCalendarStrings.remove,
            cancel: StayCalendarStrings.cancel,
            destructive: true,
            tone: ListingTone.forest,
          );
          if (!ok || !mounted) return;
          final r = await c.removeBlock(b.id);
          if (!mounted) return;
          if (r is OwnerOk<void>) {
            Navigator.of(context).maybePop();
          } else {
            AppToast.error(OwnerSharedStrings.noConnection);
          }
        },
      );
}
