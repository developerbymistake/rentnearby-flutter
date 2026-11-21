import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../strings/taxi_calendar_strings.dart';
import '../taxi_driver_deps.dart';
import 'models/taxi_calendar_models.dart';
import 'taxi_bookings_tab.dart';
import 'taxi_calendar_controller.dart';
import 'taxi_calendar_widgets.dart';
import 'taxi_month_grid.dart';
import 'taxi_reminder_row.dart';
import 'taxi_trip_sheet.dart';
import 'taxi_trip_text.dart';

class TaxiMoneySummaryScreen extends StatefulWidget {
  const TaxiMoneySummaryScreen({super.key, this.args = const {}, this.controller});

  final Map<String, dynamic> args;
  final TaxiCalendarController? controller;

  @override
  State<TaxiMoneySummaryScreen> createState() => _TaxiMoneySummaryScreenState();
}

class _TaxiMoneySummaryScreenState extends State<TaxiMoneySummaryScreen> {
  static const int shortList = 4;

  late final TaxiCalendarController _c;
  late final bool _owned;

  @override
  void initState() {
    super.initState();
    final given = widget.controller;
    _owned = given == null;
    _c = given ?? TaxiCalendarController.acquire();
    _open(TaxiCalendarNav.monthOf(widget.args) ?? _c.month.value);
  }

  Future<void> _open(DateTime m) async {
    await _c.open(m);
    if (!mounted) return;
    _c.loadSummary().ignore();
  }

  @override
  void dispose() {
    if (_owned) TaxiCalendarController.release();
    super.dispose();
  }

  void _balanceDue() => Get.toNamed(AppRoutes.taxiBalanceDue, arguments: TaxiCalendarNav.monthArgs(_c.month.value));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaxiCal.page,
      body: Column(
        children: [
          Obx(() => TaxiTabHeader(
                title: TaxiCalendarStrings.bookings,
                subtitle: OwnerSharedStrings.monthTitle(_c.month.value),
                trailing: const [TaxiPlusPill(onWhite: false)],
                icons: false,
              )),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: RefreshIndicator(
                color: TaxiCal.accent,
                onRefresh: () => _open(_c.month.value),
                child: Obx(() {
                  final parts = _parts();
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: DS.insets(l: 16, t: 4, r: 16, b: 24),
                    itemCount: parts.length,
                    itemBuilder: (context, i) => parts[i](context),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<WidgetBuilder> _parts() {
    final load = _c.load.value;
    final data = load.valueOrNull;
    final view = _c.view.value;
    final summary = _c.summary.value;
    final out = <WidgetBuilder>[];
    if (data == null) {
      out.add((_) => load is OwnerLoadLoading<CalendarMonth>
          ? const OwnerSkeletonList()
          : StateCard.error(title: OwnerSharedStrings.couldNotLoad, kit: TaxiCal.kit, actionLabel: OwnerSharedStrings.tryAgain, onAction: () => _open(_c.month.value)));
      return out;
    }
    final today = _c.serverToday;
    final locked = _c.summaryLocked || summary is OwnerLoadLocked<MoneySummary>;
    if ((load is OwnerLoadData<CalendarMonth> && load.stale) || (summary is OwnerLoadData<MoneySummary> && summary.stale)) {
      out.add((_) => const OwnerStaleLine());
    }
    if (data.window.months(today).length > 1) {
      out.add((_) => Padding(padding: DS.insets(b: 10), child: TaxiMonthChips(month: _c.month.value, window: data.window, today: today, onMonth: _open)));
    }
    if (locked) {
      out.add((_) => TaxiMoneyCard(month: _c.month.value, locked: true));
      for (var i = 0; i < view.monthRows.length; i++) {
        final e = view.monthRows[i];
        final first = i == 0;
        final last = i == view.monthRows.length - 1;
        if (first) out.add((_) => const TaxiTitleRow(title: TaxiCalendarStrings.tripsThisMonth, sub: TaxiCalendarStrings.amountsStayFree));
        out.add((_) => TaxiCardSegment(
              first: first,
              last: last,
              child: TaxiTripRow(entry: e, line: TaxiTripText.monthLine(e), trailing: TaxiChip(entry: e), onTap: () => TaxiDriverDeps.openEntry(e.id)),
            ));
      }
    } else {
      out.add((_) => _openCard(view, summary.valueOrNull));
    }
    final meter = _c.entriesMeter;
    out
      ..add((_) => Padding(padding: DS.insets(t: 12), child: TaxiReminderRow(controller: _c)))
      ..add((_) => Padding(
            padding: DS.insets(t: 12, b: 12),
            child: TaxiMeterPair(
              left: TaxiMeterTile(value: TaxiCalendarStrings.meter(meter.used, meter.limit), label: TaxiCalendarStrings.tripsYouAdded),
              right: TaxiMeterTile(value: '${view.tripCount}', label: TaxiCalendarStrings.tripsThisMonth),
            ),
          ))
      ..add((context) => PrimaryButton(
            label: TaxiCalendarStrings.addTrip,
            tone: TaxiCal.kit,
            onPressed: () => TaxiTripSheet.show(context, controller: _c, date: today),
          ));
    return out;
  }

  Widget _openCard(TaxiMonthView view, MoneySummary? s) {
    final rows = view.balanceRows;
    final short = rows.take(shortList).toList();
    return TaxiMoneyCard(
      month: _c.month.value,
      locked: false,
      booked: s?.booked ?? TaxiCalendarController.sumBooked(view.monthRows),
      received: s?.received ?? TaxiCalendarController.sumReceived(view.monthRows),
      toCollect: s?.toCollect ?? TaxiCalendarController.sumToCollect(view.monthRows),
      onToCollect: _balanceDue,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Gap.v(6),
          if (short.isEmpty)
            Padding(
              padding: DS.sym(v: 12),
              child: Text(TaxiCalendarStrings.nothingToCollect, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w600, Ink3D.grey, letterSpacing: 0)),
            ),
          for (final e in short) _SummaryRow(entry: e),
          if (rows.isNotEmpty) ...[
            Gap.v(10),
            SecondaryButton(label: TaxiCalendarStrings.balanceDueCount(rows.length), tone: TaxiCal.kit, onPressed: _balanceDue),
          ],
          Gap.v(10),
          Text(TaxiCalendarStrings.addedUpLine, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, height: 1.4, letterSpacing: 0)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.entry});

  final CalendarEntry entry;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: TaxiTripText.semantics(entry),
        child: InkWell(
          onTap: () => TaxiDriverDeps.openEntry(entry.id),
          child: Container(
            padding: DS.sym(v: 9),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Ink3D.line, width: DS.s(1)))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(TaxiTripText.title(entry), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                      Text(TaxiTripText.summaryLine(entry), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                    ],
                  ),
                ),
                Gap.h(8),
                TaxiChip(entry: entry),
              ],
            ),
          ),
        ),
      );
}
