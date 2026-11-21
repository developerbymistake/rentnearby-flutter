import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_error_types.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/money/money_note_math.dart';
import '../../owner_core/sheets/owner_confirm.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../strings/taxi_calendar_strings.dart';
import '../taxi_driver_deps.dart';
import 'taxi_bookings_tab.dart';
import 'taxi_calendar_controller.dart';
import 'taxi_calendar_widgets.dart';
import 'taxi_trip_text.dart';

class TaxiBalanceDueScreen extends StatefulWidget {
  const TaxiBalanceDueScreen({super.key, this.args = const {}, this.controller});

  final Map<String, dynamic> args;
  final TaxiCalendarController? controller;

  @override
  State<TaxiBalanceDueScreen> createState() => _TaxiBalanceDueScreenState();
}

class _TaxiBalanceDueScreenState extends State<TaxiBalanceDueScreen> {
  static const int paidShown = 2;

  late final TaxiCalendarController _c;
  late final bool _owned;
  final _busy = <String>{}.obs;
  final _allPaid = false.obs;

  @override
  void initState() {
    super.initState();
    final given = widget.controller;
    _owned = given == null;
    _c = given ?? TaxiCalendarController.acquire();
    _open();
  }

  Future<void> _open() async {
    await _c.open(TaxiCalendarNav.monthOf(widget.args) ?? _c.month.value);
    if (!mounted) return;
    _c.loadSummary().ignore();
  }

  @override
  void dispose() {
    if (_owned) TaxiCalendarController.release();
    super.dispose();
  }

  Future<void> _markPaid(CalendarEntry e) async {
    if (_busy.contains(e.id)) return;
    final ok = await OwnerConfirm.ask(
      context,
      title: TaxiCalendarStrings.markPaidAskTitle,
      body: TaxiCalendarStrings.markPaidAskBody(TaxiTripText.title(e)),
      confirm: TaxiCalendarStrings.markPaid,
      cancel: TaxiCalendarStrings.markPaidAskCancel,
      tone: ListingTone.coral,
      art: ListingArt.moneyBag,
    );
    if (!ok || !mounted || _busy.contains(e.id)) return;
    _busy.add(e.id);
    try {
      final r = await _c.markPaid(e);
      if (!mounted) return;
      switch (r) {
        case OwnerOk():
          return;
        case OwnerRefused(:final statusCode) when statusCode == 429:
          AppToast.error(OwnerSharedStrings.tooManyTries);
        case OwnerRefused() when OwnerRefusal.stale(r):
          return;
        default:
          AppToast.error(OwnerSharedStrings.noConnection);
      }
    } finally {
      _busy.remove(e.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaxiCal.page,
      body: Column(
        children: [
          Obx(() {
            final s = _c.summary.value.valueOrNull;
            final toCollect = s?.toCollect ?? TaxiCalendarController.sumToCollect(_c.view.value.monthRows);
            return TaxiCalPageHeader(
              title: TaxiCalendarStrings.balanceDue,
              subtitle: TaxiCalendarStrings.balanceDueSub(_c.month.value, toCollect),
              plusPill: true,
            );
          }),
          Expanded(
            child: RefreshIndicator(
              color: TaxiCal.accent,
              onRefresh: _open,
              child: Obx(() {
                final parts = _parts();
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: DS.insets(l: 16, t: 14, r: 16, b: 24),
                  itemCount: parts.length,
                  itemBuilder: (context, i) => parts[i](context),
                );
              }),
            ),
          ),
          TaxiBottomActions(children: [
            PrimaryButton(label: TaxiCalendarStrings.viewCalendar, tone: TaxiCal.kit, onPressed: TaxiCalendarNav.viewCalendar),
          ]),
        ],
      ),
    );
  }

  List<WidgetBuilder> _parts() {
    final load = _c.load.value;
    final data = load.valueOrNull;
    final out = <WidgetBuilder>[];
    if (data == null) {
      out.add((_) => load is OwnerLoadLoading<CalendarMonth>
          ? const OwnerSkeletonList()
          : StateCard.error(title: OwnerSharedStrings.couldNotLoad, kit: TaxiCal.kit, actionLabel: OwnerSharedStrings.tryAgain, onAction: _open));
      return out;
    }
    final view = _c.view.value;
    final summary = _c.summary.value;
    if (load is OwnerLoadData<CalendarMonth> && load.stale) out.add((_) => const OwnerStaleLine());
    if (_c.staleLine.value) {
      out.add((_) => Padding(
            padding: DS.insets(b: 8),
            child: Text(OwnerSharedStrings.staleEdit, style: Ink3D.text(12, FontWeight.w600, DesignColors.error, letterSpacing: 0)),
          ));
    }
    if (_c.summaryLocked || summary is OwnerLoadLocked<MoneySummary>) {
      out.add((_) => TaxiMoneyCard(month: _c.month.value, locked: true));
      return out;
    }
    final s = summary.valueOrNull;
    out.add((_) => Container(
          padding: DS.all(12),
          decoration: TaxiCal.card(),
          child: TaxiMoneyTiles(
            booked: s?.booked ?? TaxiCalendarController.sumBooked(view.monthRows),
            received: s?.received ?? TaxiCalendarController.sumReceived(view.monthRows),
            toCollect: s?.toCollect ?? TaxiCalendarController.sumToCollect(view.monthRows),
          ),
        ));
    out.add((_) => Padding(padding: DS.insets(t: 16), child: TaxiSectionLabel(text: TaxiCalendarStrings.stillToCollect, count: view.balanceRows.length)));
    if (view.balanceRows.isEmpty) {
      out.add((_) => Padding(
            padding: DS.sym(v: 14),
            child: Text(TaxiCalendarStrings.nothingToCollect, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w600, Ink3D.grey, letterSpacing: 0)),
          ));
    }
    _addRows(out, view.balanceRows, collect: true);
    if (view.paidRows.isNotEmpty) {
      final all = _allPaid.value;
      final shown = all ? view.paidRows : view.paidRows.take(paidShown).toList();
      out.add((_) => Padding(padding: DS.insets(t: 6), child: TaxiSectionLabel(text: TaxiCalendarStrings.paidInFullHead, count: view.paidRows.length)));
      _addRows(out, shown, collect: false);
      final rest = view.paidRows.length - shown.length;
      if (rest > 0) {
        out.add((_) => SecondaryButton(label: TaxiCalendarStrings.showMorePaid(rest), tone: TaxiCal.kit, onPressed: () => _allPaid.value = true));
      }
    }
    return out;
  }

  void _addRows(List<WidgetBuilder> out, List<CalendarEntry> rows, {required bool collect}) {
    for (var i = 0; i < rows.length; i++) {
      final e = rows[i];
      final first = i == 0;
      final last = i == rows.length - 1;
      out.add((_) => TaxiCardSegment(
            first: first,
            last: last,
            child: TaxiTripRow(
              entry: e,
              line: collect ? TaxiTripText.collectLine(e) : TaxiTripText.paidLine(e),
              chipInline: !collect,
              trailing: collect ? _collectTrailing(e) : (e.finalAmount == null ? null : TaxiAmount(amount: e.finalAmount!)),
              onTap: () => TaxiDriverDeps.openEntry(e.id),
            ),
          ));
    }
  }

  Widget _collectTrailing(CalendarEntry e) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TaxiAmount(amount: MoneyNoteMath.balance(e.money) ?? 0),
          Gap.v(6),
          Obx(() => TaxiSmallOutline(
                label: TaxiCalendarStrings.markPaid,
                onTap: _busy.contains(e.id) ? null : () => _markPaid(e),
                semantics: '${TaxiCalendarStrings.markPaid} ${TaxiTripText.title(e)}',
              )),
        ],
      );
}

