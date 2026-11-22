import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/money_format.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_error_types.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/money/edit_amounts_sheet.dart';
import '../../owner_core/money/money_note_math.dart';
import '../../owner_core/sheets/owner_confirm.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../strings/taxi_calendar_strings.dart';
import '../taxi_driver_deps.dart';
import 'taxi_calendar_controller.dart';
import 'taxi_calendar_widgets.dart';
import 'taxi_trip_sheet.dart';
import 'taxi_trip_text.dart';

// D-07: a trip whose last day is before today is read-only except money notes and Delete.
abstract final class TaxiTripEnded {
  static bool of(CalendarEntry e, DateTime today) {
    final last = e.lastDay;
    return last != null && OwnerDates.only(last).isBefore(OwnerDates.only(today));
  }
}

class TaxiCalendarEntryScreen extends StatefulWidget {
  const TaxiCalendarEntryScreen({super.key, this.args = const {}, this.controller});

  final Map<String, dynamic> args;
  final TaxiCalendarController? controller;

  @override
  State<TaxiCalendarEntryScreen> createState() => _TaxiCalendarEntryScreenState();
}

class _TaxiCalendarEntryScreenState extends State<TaxiCalendarEntryScreen> {
  late final TaxiCalendarController _c;
  late final bool _owned;
  final LatestOnly _latest = LatestOnly();
  OwnerLoad<CalendarEntry> _load = const OwnerLoadLoading();
  bool _gone = false;

  String? get _id {
    final v = widget.args['id'];
    return v is String && v.isNotEmpty ? v : null;
  }

  @override
  void initState() {
    super.initState();
    final given = widget.controller;
    _owned = given == null;
    _c = given ?? TaxiCalendarController.acquire();
    _fetch();
  }

  @override
  void dispose() {
    _latest.cancel();
    if (_owned) TaxiCalendarController.release();
    super.dispose();
  }

  CalendarEntry? _cached(String id) {
    final data = _c.current;
    if (data == null) return null;
    for (final e in data.entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> _fetch() async {
    final id = _id;
    if (id == null) {
      setState(() => _load = const OwnerLoadError());
      return;
    }
    final cached = _cached(id);
    if (cached != null && _load is OwnerLoadLoading<CalendarEntry>) setState(() => _load = OwnerLoadData(cached));
    final req = _latest.next();
    final r = await _c.entry(id);
    if (!mounted || !_latest.isLatest(req)) return;
    setState(() {
      _gone = r is OwnerRefused<CalendarEntry> && r.statusCode == 404;
      _load = OwnerLoads.from<CalendarEntry>(r, saved: _load.valueOrNull ?? cached);
    });
  }

  Future<void> _editAmounts(CalendarEntry e) async {
    final saved = await EditAmountsSheet.show(
      context,
      look: TaxiCal.look,
      words: EditAmountsWords(
        title: _hasMoney(e) ? TaxiCalendarStrings.editAmounts : TaxiCalendarStrings.addAmounts,
        finalHint: TaxiCalendarStrings.finalHint,
        save: TaxiCalendarStrings.saveTrip,
      ),
      initial: e.money,
      save: (n) => _c.saveMoney(e, finalAmount: n.finalAmount, receivedSoFar: n.paidInFull ? null : n.receivedSoFar, paidInFull: n.paidInFull),
    );
    if (!mounted) return;
    if (_c.staleLine.value) AppToast.info(OwnerSharedStrings.staleEdit);
    if (saved || _c.staleLine.value) await _fetch();
  }

  Future<void> _edit(CalendarEntry e) async {
    final saved = await TaxiTripSheet.show(context, controller: _c, editing: e);
    if (saved && mounted) await _fetch();
  }

  Future<void> _delete(CalendarEntry e) async {
    final ok = await OwnerConfirm.ask(
      context,
      title: TaxiCalendarStrings.deleteTitle,
      body: TaxiCalendarStrings.deleteBody,
      confirm: TaxiCalendarStrings.delete,
      cancel: TaxiCalendarStrings.keep,
      destructive: true,
      art: ListingArt.warning,
      tone: ListingTone.coral,
    );
    if (!ok || !mounted) return;
    final r = await _c.delete(e.id);
    if (!mounted) return;
    final gone = r is OwnerRefused<void> && r.statusCode == 404;
    if (r is OwnerOk<void> || gone) {
      Navigator.of(context).maybePop();
      return;
    }
    if (r is OwnerRefused<void> && r.type == OwnerErrorTypes.entryNotManual) {
      AppToast.error(r.message ?? OwnerSharedStrings.noConnection);
      return;
    }
    AppToast.error(r is OwnerRefused<void> && r.statusCode == 429 ? OwnerSharedStrings.tooManyTries : OwnerSharedStrings.noConnection);
  }

  void _openBooking(CalendarEntry e) {
    final source = e.sourceId;
    if (e.sourceAvailable == false || source == null) {
      AppToast.info(TaxiCalendarStrings.bookingGone);
      return;
    }
    TaxiDriverDeps.openBooking(source);
  }

  static bool _hasMoney(CalendarEntry e) => e.finalAmount != null || e.receivedSoFar != null || e.paidInFull;

  @override
  Widget build(BuildContext context) {
    final e = _load.valueOrNull;
    final manual = e?.isManual ?? false;
    return Scaffold(
      backgroundColor: TaxiCal.page,
      body: Column(
        children: [
          TaxiCalPageHeader(
            title: manual ? TaxiCalendarStrings.trip : TaxiCalendarStrings.booking,
            subtitle: e == null
                ? null
                : manual
                    ? OwnerSharedStrings.addedByYou
                    : (e.cancelled ? TaxiCalendarStrings.fromTheAppCancelled : TaxiCalendarStrings.fromTheApp),
          ),
          Expanded(
            child: OwnerStateView<CalendarEntry>(
              load: _gone ? const OwnerLoadError() : _load,
              look: TaxiCal.look,
              words: OwnerStateWords(errorTitle: _gone ? TaxiCalendarStrings.bookingGone : OwnerSharedStrings.couldNotLoad),
              onRetry: _gone ? null : _fetch,
              data: (context, entry, stale) => RefreshIndicator(
                color: TaxiCal.accent,
                onRefresh: _fetch,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: DS.insets(l: 16, t: 16, r: 16, b: 24),
                  child: TaxiEntryBody(entry: entry, stale: stale),
                ),
              ),
            ),
          ),
          if (e != null)
            TaxiBottomActions(
              children: manual
                  ? [
                      if (TaxiTripEnded.of(e, _c.serverToday))
                        SecondaryButton(
                          label: _hasMoney(e) ? TaxiCalendarStrings.editAmounts : TaxiCalendarStrings.addAmounts,
                          tone: TaxiCal.kit,
                          onPressed: () => _editAmounts(e),
                        )
                      else
                        SecondaryButton(label: TaxiCalendarStrings.edit, tone: TaxiCal.kit, onPressed: () => _edit(e)),
                      SecondaryButton(label: TaxiCalendarStrings.delete, tone: TaxiCal.kit, onPressed: () => _delete(e)),
                    ]
                  : [
                      PrimaryButton(label: TaxiCalendarStrings.openBooking, tone: TaxiCal.kit, onPressed: () => _openBooking(e)),
                      SecondaryButton(
                        label: _hasMoney(e) ? TaxiCalendarStrings.editAmounts : TaxiCalendarStrings.addAmounts,
                        tone: TaxiCal.kit,
                        onPressed: () => _editAmounts(e),
                      ),
                    ],
            ),
        ],
      ),
    );
  }
}

class TaxiEntryBody extends StatelessWidget {
  const TaxiEntryBody({super.key, required this.entry, this.stale = false});

  final CalendarEntry entry;
  final bool stale;

  static String places(List<String> p) {
    if (p.length <= 3) return p.join(', ');
    return '${p.take(3).join(', ')} +${p.length - 3}';
  }

  static ({String title, String sub}) head(CalendarEntry e) {
    final a = e.dateFrom;
    if (a == null) return (title: TaxiTripText.title(e), sub: '');
    if (e.isManual) {
      final t = TaxiTripText.time(e);
      return (title: t == null ? OwnerSharedStrings.dayMonth(a) : '${OwnerSharedStrings.dayMonth(a)} · $t', sub: TaxiTripText.route(e));
    }
    final days = TaxiTripText.days(e);
    if (days > 1) return (title: TaxiTripText.dateSpan(e), sub: TaxiCalendarStrings.daysAllDay(days));
    if (e.cancelled) return (title: OwnerSharedStrings.dayMonth(a), sub: TaxiCalendarStrings.allDayOf(TaxiTripText.title(e)));
    return (title: TaxiCalendarStrings.dayAllDay(a), sub: TaxiTripText.title(e));
  }

  String _money(int? v) => v == null ? TaxiCalendarStrings.dash : Money.exact(v);

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final h = head(e);
    final received = e.paidInFull ? e.finalAmount : e.receivedSoFar;
    final balance = e.cancelled ? null : MoneyNoteMath.balance(e.money);
    final chip = TaxiTripText.chip(e);
    final cancelledBy = e.cancelledBy == 'Traveller' && e.cancelledOn != null && e.label.isNotEmpty ? e.label.split(' ').first : null;
    final last = e.lastDay;
    final rows = <Widget>[
      if (e.isAuto) TaxiKv(label: TaxiCalendarStrings.traveller, value: TaxiTripText.traveller(e)),
      if (e.isAuto && e.cancelled && cancelledBy != null) TaxiKv(label: TaxiCalendarStrings.cancelledRow, value: TaxiCalendarStrings.cancelledBy(cancelledBy, e.cancelledOn!)),
      if (e.isAuto && (e.fromPlace ?? '').isNotEmpty) TaxiKv(label: TaxiCalendarStrings.pickup, value: e.fromPlace),
      if (e.isAuto && (e.toPlace ?? '').isNotEmpty) TaxiKv(label: TaxiCalendarStrings.drop, value: e.toPlace),
      if (e.isAuto && e.guests != null) TaxiKv(label: TaxiCalendarStrings.travellers, value: TaxiCalendarStrings.travellersCount(e.guests!)),
      if (e.isAuto && e.seats != null) TaxiKv(label: TaxiCalendarStrings.car, value: TaxiCalendarStrings.seater(e.seats!)),
      if (e.isAuto && e.places.isNotEmpty) TaxiKv(label: TaxiCalendarStrings.places, value: places(e.places)),
      if (e.isAuto && e.guests == null && e.seats == null && e.places.isEmpty && (e.detail ?? '').isNotEmpty)
        TaxiKv(label: TaxiCalendarStrings.car, value: e.detail),
      if (e.isManual) TaxiKv(label: TaxiCalendarStrings.label, value: e.label),
      if (e.isManual && (e.note ?? '').isNotEmpty) TaxiKv(label: TaxiCalendarStrings.note, value: e.note),
    ];
    final money = <Widget>[
      TaxiKv(label: OwnerSharedStrings.finalAmount, value: _money(e.finalAmount), divider: false),
      TaxiKv(label: OwnerSharedStrings.receivedSoFar, value: _money(received)),
      TaxiKv(label: OwnerSharedStrings.balanceToCollect, value: _money(balance)),
      if (chip != MoneyChip.none) TaxiKv(label: OwnerSharedStrings.status, trailing: TaxiChip(entry: e, markCancelled: false)),
    ];
    final hasMoney = e.finalAmount != null || e.receivedSoFar != null || e.paidInFull;
    final note = e.isManual
        ? null
        : e.cancelled
            ? (last == null ? null : TaxiCalendarStrings.cancelledNote(OwnerDates.addDays(last, 90)))
            : hasMoney
                ? TaxiCalendarStrings.confirmedNote
                : TaxiCalendarStrings.emptyMoneyNote;
    final foot = e.isManual || e.cancelled || last == null
        ? null
        : (TaxiTripText.days(e) > 1 ? TaxiCalendarStrings.removedAfter(last) : OwnerSharedStrings.removedAfter90);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stale) const OwnerStaleLine(),
        Container(
          padding: DS.all(14),
          decoration: TaxiCal.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Art3D(asset: ListingArt.taxi, size: 44),
                  Gap.h(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(h.title, style: Ink3D.text(22, FontWeight.w700, Ink3D.title, height: 1.15, letterSpacing: 0)),
                        ),
                        if (h.sub.isNotEmpty) Text(h.sub, style: Ink3D.text(12, FontWeight.w600, Ink3D.body, letterSpacing: 0)),
                      ],
                    ),
                  ),
                ],
              ),
              Gap.v(8),
              Wrap(
                spacing: DS.gh(6),
                children: [
                  TaxiBadge(kind: TaxiBadge.of(e)),
                  if (e.isAuto) TaxiBadge(kind: e.cancelled ? TaxiBadgeKind.cancelled : TaxiBadgeKind.confirmed),
                ],
              ),
              Gap.v(6),
              ...rows,
              Gap.v(10),
              Row(
                children: [
                  Expanded(child: Text(OwnerSharedStrings.moneyNotes, style: Ink3D.text(13, FontWeight.w700, Ink3D.title, letterSpacing: 0))),
                  Container(
                    padding: DS.sym(h: 8, v: 3),
                    decoration: BoxDecoration(color: TaxiCal.tealFill, borderRadius: DS.circular(10)),
                    child: Text(OwnerSharedStrings.onlyYouSee, style: Ink3D.text(10.5, FontWeight.w700, TaxiCal.tealText, letterSpacing: 0)),
                  ),
                ],
              ),
              Gap.v(8),
              Container(
                padding: DS.sym(h: 12, v: 2),
                decoration: BoxDecoration(color: TaxiCal.softFill, borderRadius: DS.circular(12)),
                child: Column(children: money),
              ),
            ],
          ),
        ),
        if (note != null) ...[Gap.v(14), TaxiNoteCard(text: note)],
        if (foot != null) ...[Gap.v(6), TaxiFootLine(text: foot)],
      ],
    );
  }
}
