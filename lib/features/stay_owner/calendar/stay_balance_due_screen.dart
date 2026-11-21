import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/money_format.dart';
import '../../owner_core/calendar/calendar_api.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_args.dart';
import '../../owner_core/data/owner_error_types.dart';
import '../../owner_core/data/owner_page.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/money/money_note_math.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/sheets/owner_confirm.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../strings/stay_calendar_strings.dart';
import '../widgets/stay_widgets.dart';
import 'stay_calendar_screen.dart';
import 'stay_entry_rows.dart';
import 'widgets/stay_calendar_widgets.dart';

class StayBalanceDueScreen extends StatefulWidget {
  const StayBalanceDueScreen({super.key, this.args = const {}, this.api, this.clock});

  final Map<String, dynamic> args;
  final CalendarApi? api;
  final DateTime Function()? clock;

  @override
  State<StayBalanceDueScreen> createState() => _StayBalanceDueScreenState();
}

class _StayBalanceDueScreenState extends State<StayBalanceDueScreen> {
  late final CalendarApi api;
  late final DateTime month;
  final LatestOnly _latest = LatestOnly();
  OwnerLoad<MoneySummary> _summary = const OwnerLoadLoading();
  OwnerLoad<bool> _list = const OwnerLoadLoading();
  final List<CalendarEntry> _due = [];
  final List<CalendarEntry> _paid = [];
  final Set<String> _busy = {};
  String? _cursor;
  bool _more = false;
  String? _staleLine;

  @override
  void initState() {
    super.initState();
    api = widget.api ?? const CalendarApi(CalendarApi.stayPrefix);
    final today = OwnerDates.only((widget.clock ?? DateTime.now)());
    month = OwnerDates.month(OwnerArgs.text(widget.args, 'month')) ?? OwnerDates.firstOfMonth(today);
    _fetch();
  }

  @override
  void dispose() {
    _latest.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final id = _latest.next();
    final results = await Future.wait([
      api.summary(month),
      api.balanceDue(month),
      api.month(month, OwnerDates.lastOfMonth(month)),
    ]);
    if (!mounted || !_latest.isLatest(id)) return;
    final s = results[0] as OwnerResult<MoneySummary>;
    final d = results[1] as OwnerResult<OwnerPage<CalendarEntry>>;
    final m = results[2] as OwnerResult<CalendarMonth>;
    setState(() {
      _summary = OwnerLoads.from<MoneySummary>(s, saved: _summary.valueOrNull);
      if (d is OwnerOk<OwnerPage<CalendarEntry>>) {
        _due
          ..clear()
          ..addAll(d.value.items.where((e) => e.valid && e.chip == MoneyChip.toCollect));
        _cursor = d.value.nextCursor;
        _list = const OwnerLoadData(true);
      } else if (d is OwnerRefused<OwnerPage<CalendarEntry>>) {
        _list = OwnerLoads.from<bool>(d.cast<bool>());
      } else {
        _list = _due.isEmpty ? (d is OwnerOffline ? const OwnerLoadOffline() : const OwnerLoadError()) : const OwnerLoadData(true, stale: true);
      }
      if (m is OwnerOk<CalendarMonth>) {
        _paid
          ..clear()
          ..addAll(m.value.entries.where((e) =>
              !e.cancelled && e.finalAmount != null && e.chip == MoneyChip.paidInFull && e.dateFrom != null && e.dateFrom?.month == month.month));
        _paid.sort((a, b) => (b.dateFrom ?? month).compareTo(a.dateFrom ?? month));
      }
    });
  }

  Future<void> _loadMore() async {
    final c = _cursor;
    if (c == null || _more) return;
    setState(() => _more = true);
    final r = await api.balanceDue(month, cursor: c);
    if (!mounted) return;
    setState(() {
      _more = false;
      if (r is OwnerOk<OwnerPage<CalendarEntry>>) {
        final merged = OwnerPage.appendNew(_due, r.value.items.where((e) => e.valid).toList(), (e) => e.id);
        _due
          ..clear()
          ..addAll(merged);
        _cursor = r.value.nextCursor;
      }
    });
  }

  Future<void> _markPaid(CalendarEntry e) async {
    if (_busy.contains(e.id)) return;
    final ok = await OwnerConfirm.ask(
      context,
      title: StayCalendarStrings.markPaidTitle,
      confirm: StayCalendarStrings.yes,
      cancel: StayCalendarStrings.cancel,
      tone: ListingTone.forest,
    );
    if (!ok || !mounted) return;
    setState(() => _busy.add(e.id));
    final r = await api.money(e.id, finalAmount: e.finalAmount, receivedSoFar: e.receivedSoFar, paidInFull: true, version: e.version);
    if (!mounted) return;
    setState(() {
      _busy.remove(e.id);
      if (r is OwnerOk<EntryWriteResult>) {
        _due.removeWhere((x) => x.id == e.id);
        final updated = r.value.entry ?? e;
        _paid.insert(0, updated);
        final s = _summary.valueOrNull;
        if (s != null) {
          final bal = e.chipAmount;
          _summary = OwnerLoadData(MoneySummary(month: s.month, booked: s.booked, received: s.received + bal, toCollect: s.toCollect - bal, top: s.top));
        }
      }
    });
    if (r is OwnerRefused<EntryWriteResult> && r.type == OwnerErrorTypes.staleEdit) {
      setState(() => _staleLine = OwnerSharedStrings.staleEdit);
      await _fetch();
    } else if (r is! OwnerOk<EntryWriteResult>) {
      AppToast.error(r is OwnerRefused<EntryWriteResult> && r.rateLimited ? OwnerSharedStrings.tooManyTries : OwnerSharedStrings.noConnection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary.valueOrNull;
    final sub = s == null ? OwnerSharedStrings.monthTitle(month) : StayCalendarStrings.balanceDueSub(month, s.toCollect);
    final locked = _list is OwnerLoadLocked<bool> || _summary is OwnerLoadLocked<MoneySummary>;
    return Scaffold(
      backgroundColor: OwnerLook.stay.page,
      body: Column(
        children: [
          StayCalHeader(title: StayCalendarStrings.balanceDue, subtitle: sub, trailing: PlanGate.paymentOn && !PlanGate.canUpgrade ? const StayPlusTag() : null),
          Expanded(child: locked ? _locked() : _body()),
          StayCalBar(primary: StayCalendarStrings.viewCalendar, onPrimary: () => Get.toNamed(AppRoutes.stayCalendar)),
        ],
      ),
    );
  }

  Widget _locked() => Padding(
        padding: DS.all(18),
        child: PlanGate.canUpgrade ? const StayLockedSummary() : const SizedBox.shrink(),
      );

  Widget _body() {
    return OwnerStateView<bool>(
      load: _list,
      look: OwnerLook.stay,
      words: const OwnerStateWords(),
      onRetry: _fetch,
      data: (context, _, stale) {
        final rows = <_Row>[
          if (_due.isNotEmpty) _Row.header(StayCalendarStrings.stillToCollect, _due.length),
          for (var i = 0; i < _due.length; i++) _Row.due(_due[i], i == 0, i == _due.length - 1),
          if (_paid.isNotEmpty) _Row.header(StayCalendarStrings.paidGroup, _paid.length),
          for (var i = 0; i < _paid.length; i++) _Row.paid(_paid[i], i == 0, i == _paid.length - 1),
        ];
        return RefreshIndicator(
          onRefresh: _fetch,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (stale) const SliverToBoxAdapter(child: OwnerStaleLine()),
              if (_staleLine != null) SliverToBoxAdapter(child: OwnerStaleLine(text: _staleLine ?? '')),
              SliverToBoxAdapter(
                child: Container(
                  margin: DS.insets(l: 18, t: 14, r: 18),
                  padding: DS.all(12),
                  decoration: BoxDecoration(color: DesignColors.surface, borderRadius: StayLook.cardRadius(34), boxShadow: DS.shadows(ShadowTokens.elev1)),
                  child: StayMoneyTiles(summary: _summary.valueOrNull),
                ),
              ),
              SliverList.builder(itemCount: rows.length, itemBuilder: (context, i) => _build(rows[i])),
              if (_cursor != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: DS.insets(l: 18, t: 12, r: 18),
                    child: _more ? const Center(child: CircularProgressIndicator()) : StayPill(label: StayCalendarStrings.showMore, kind: StayPillKind.outline, expand: true, onTap: _loadMore),
                  ),
                ),
              const SliverToBoxAdapter(child: StaySmallLine(text: StayCalendarStrings.ownListNote)),
              SliverToBoxAdapter(child: Gap.v(24)),
            ],
          ),
        );
      },
    );
  }

  Widget _build(_Row r) {
    final h = r.header;
    if (h != null) return StayGroupHeader(title: h, count: r.count);
    final e = r.entry;
    if (e == null) return const SizedBox.shrink();
    final f = e.dateFrom ?? month;
    final sub = r.paid || e.finalAmount == null ? StayEntryText.upcomingSub(e) : '${StayEntryText.range(e)} · ${StayCalendarStrings.ofAmount(e.finalAmount ?? 0)}';
    final amount = r.paid ? (e.finalAmount ?? 0) : e.chipAmount;
    return StayCardSegment(
      first: r.first,
      last: r.last,
      child: StayEntryRow(
        tileTop: '${f.day}',
        tileBottom: StayCalendarStrings.shortUpper(f),
        kind: StayTileLook.of(e),
        title: StayEntryText.label(e),
        sub: sub,
        chips: [StayKindChip.of(e), if (r.paid) StaySoftChip(label: StayCalendarStrings.paidInFull, bg: StayLook.greenSoft, fg: StayLook.greenText)],
        semantics: StayEntryText.spoken(e),
        onTap: () => StayEntryRows.open(e),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Money.exact(amount), style: Ink3D.text(13, FontWeight.w800, Ink3D.title, letterSpacing: 0)),
            if (!r.paid) ...[
              Gap.v(4),
              StayPill(label: StayCalendarStrings.markPaid, kind: StayPillKind.outline, busy: _busy.contains(e.id), onTap: () => _markPaid(e)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row {
  const _Row._({this.header, this.count, this.entry, this.first = false, this.last = false, this.paid = false});

  factory _Row.header(String title, int count) => _Row._(header: title, count: count);
  factory _Row.due(CalendarEntry e, bool first, bool last) => _Row._(entry: e, first: first, last: last);
  factory _Row.paid(CalendarEntry e, bool first, bool last) => _Row._(entry: e, first: first, last: last, paid: true);

  final String? header;
  final int? count;
  final CalendarEntry? entry;
  final bool first;
  final bool last;
  final bool paid;
}
