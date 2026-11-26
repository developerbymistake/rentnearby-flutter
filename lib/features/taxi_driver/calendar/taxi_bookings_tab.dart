import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/owner_inactive.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/plan/soft_lock.dart';
import '../../owner_core/sheets/owner_confirm.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../../../utils/app_toast.dart';
import '../../owner_core/data/owner_result.dart';
import '../availability/taxi_availability_store.dart';
import '../strings/taxi_availability_strings.dart';
import '../strings/taxi_calendar_strings.dart';
import '../strings/taxi_gate_strings_calendar.dart';
import '../strings/taxi_work_strings.dart';
import '../taxi_driver_deps.dart';
import 'models/taxi_calendar_models.dart';
import 'taxi_calendar_controller.dart';
import 'taxi_calendar_widgets.dart';
import 'taxi_day_sheet.dart';
import 'taxi_month_grid.dart';
import 'taxi_reminder_row.dart';
import 'taxi_trip_sheet.dart';
import 'taxi_trip_text.dart';

abstract final class TaxiCalendarNav {
  static void viewCalendar() {
    if (Get.isRegistered<AuthController>()) {
      Get.find<AuthController>().openTab(AppTabs.fourth);
    } else {
      Get.toNamed(AppRoutes.taxiBookings);
    }
  }

  static Map<String, dynamic> monthArgs(DateTime m) => {'month': OwnerDates.monthKey(m)};

  static DateTime? monthOf(Map<String, dynamic> args) {
    final v = args['month'];
    return OwnerDates.month(v);
  }
}

class TaxiBookingsTab extends StatefulWidget {
  const TaxiBookingsTab({super.key, this.root = false, this.controller});

  final bool root;
  final TaxiCalendarController? controller;

  @override
  State<TaxiBookingsTab> createState() => _TaxiBookingsTabState();
}

class _TaxiBookingsTabState extends State<TaxiBookingsTab> {
  late final TaxiCalendarController _c;
  late final bool _owned;
  final _selected = Rxn<DateTime>();
  Worker? _intent;
  TaxiAvailabilityStore? get _store => TaxiAvailabilityStore.maybe;

  @override
  void initState() {
    super.initState();
    final given = widget.controller;
    _owned = given == null;
    _c = given ?? TaxiCalendarController.acquire();
    _open(_c.month.value);
    _store?.ensure().ignore();
    if (widget.root && Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      _intent = ever(auth.tabIntent, (_) => _takeIntent(auth));
      _takeIntent(auth);
    }
  }

  void _takeIntent(AuthController auth) {
    final i = auth.takeIntent(AppTabs.fourth);
    if (i == null) return;
    final d = OwnerDates.day(i.args['date']);
    if (d == null) return;
    _selected.value = d;
    _open(d);
  }

  Future<void> _open(DateTime m) async {
    await _c.open(m);
    if (!mounted) return;
    _c.loadSummary().ignore();
  }

  Future<void> _reload() async {
    _store?.refresh(force: true).ignore();
    await _c.reload();
    if (!mounted) return;
    _c.loadSummary().ignore();
  }

  @override
  void dispose() {
    _intent?.dispose();
    if (_owned) TaxiCalendarController.release();
    super.dispose();
  }

  void _addTrip() {
    final s = _selected.value;
    final today = _c.serverToday;
    final date = s != null && !s.isBefore(today) ? s : today;
    TaxiTripSheet.show(context, controller: _c, date: date);
  }

  VoidCallback? get _addAction => PlanGate.addEnabled(_c.entriesFull) ? _addTrip : null;

  Future<void> _deleteInactive(CalendarEntry e) async {
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
    if (r is OwnerOk<void> || gone) return;
    AppToast.error(r is OwnerRefused<void> && r.message != null ? r.message! : OwnerSharedStrings.noConnection);
  }

  Widget _row(CalendarEntry e, Widget row) {
    if (!e.inactiveByPlan) return row;
    return OwnerInactive(
      reason: TaxiGateStringsCalendar.entryInactive(TaxiGateStringsCalendar.freeEntries),
      taxi: true,
      onDelete: () => _deleteInactive(e),
      child: row,
    );
  }

  List<WidgetBuilder> _fullLine() =>
      _c.entriesFull && !PlanGate.canUpgrade ? [(_) => TaxiPlusFullLine(limit: _c.entriesMeter.limit)] : const [];

  Widget _pastLink() => Padding(
        padding: DS.insets(t: 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () => Get.toNamed(AppRoutes.taxiPast),
            child: Padding(
              padding: DS.sym(h: 6, v: 8),
              child: Text(TaxiWorkStrings.pastTrips, style: Ink3D.text(12.5, FontWeight.w600, TaxiCal.accent, letterSpacing: 0)),
            ),
          ),
        ),
      );

  bool _isOff(DateTime d) => !d.isBefore(_c.serverToday) && (_store?.offKeys.contains(OwnerDates.dayText(d)) ?? false);

  void _tapDay(DateTime d) {
    if (_isOff(d) && _c.dayRows(d).isEmpty) {
      AppToast.info(TaxiAvailabilityStrings.dayIsOff);
      return;
    }
    _selected.value = d;
    TaxiDaySheet.show(context, controller: _c, day: d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaxiCal.page,
      body: Column(
        children: [
          Obx(() => TaxiTabHeader(
                title: TaxiCalendarStrings.bookings,
                subtitle: OwnerSharedStrings.monthTitle(_c.month.value),
              )),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: RefreshIndicator(
                color: TaxiCal.accent,
                onRefresh: _reload,
                child: Obx(() {
                  final load = _c.load.value;
                  final parts = _parts(load);
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(4), DS.s(16), DS.s(24) + BarMetrics.bodyBottomOf(context)),
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

  List<WidgetBuilder> _parts(OwnerLoad<CalendarMonth> load) {
    final data = load.valueOrNull;
    final stale = load is OwnerLoadData<CalendarMonth> && load.stale;
    final out = <WidgetBuilder>[];
    if (data == null) {
      if (load is OwnerLoadLoading<CalendarMonth>) {
        out.add((_) => const OwnerSkeletonList(rows: 4));
      } else {
        out.add((_) => Padding(
              padding: DS.insets(t: 24),
              child: StateCard.error(title: TaxiCalendarStrings.couldNotLoadBookings, kit: TaxiCal.kit, actionLabel: OwnerSharedStrings.tryAgain, onAction: _reload),
            ));
      }
      out.addAll(_fromApp());
      return out;
    }
    final view = _c.view.value;
    final window = data.window;
    final today = _c.serverToday;
    final locked = _c.summaryLocked;
    if (stale) out.add((_) => const OwnerStaleLine());
    if (_c.staleLine.value) {
      out.add((_) => Padding(
            padding: DS.sym(v: 6),
            child: Text(OwnerSharedStrings.staleEdit, style: Ink3D.text(12, FontWeight.w600, DesignColors.error, letterSpacing: 0)),
          ));
    }
    if (window.months(today).length > 1) {
      out.add((_) => Padding(
            padding: DS.insets(b: 8),
            child: TaxiMonthChips(month: _c.month.value, window: window, today: today, onMonth: _open),
          ));
    }
    out.add((_) => TaxiMonthPager(month: _c.month.value, window: window, today: today, onMonth: _open));
    out.add((_) => Obx(() => TaxiMonthGrid(
          cells: _c.grid.toList(),
          selected: _selected.value,
          offDays: _store?.offKeys ?? const <String>{},
          onTap: (cell) => _tapDay(cell.date),
        )));
    out.add((_) => Padding(padding: DS.insets(t: 12, b: 10), child: const TaxiLegend()));
    final f = view.festival;
    if (f != null) out.add((_) => _FestivalCard(festival: f));
    final meter = _c.entriesMeter;
    final ownTile = TaxiMeterTile(value: TaxiCalendarStrings.meter(meter.used, meter.limit), label: TaxiCalendarStrings.tripsYouAdded);
    if (locked) {
      out
        ..add((_) => Padding(
              padding: DS.insets(t: 6, b: 12),
              child: TaxiMeterPair(left: ownTile, right: TaxiMeterTile(value: '${view.appCount}', label: TaxiCalendarStrings.fromAppThisMonth)),
            ))
        ..add((_) => PrimaryButton(label: TaxiCalendarStrings.addTrip, tone: TaxiCal.kit, onPressed: _addAction))
        ..addAll(_fullLine())
        ..add((_) => Padding(padding: DS.insets(t: 14), child: TaxiMoneyCard(month: _c.month.value, locked: true)));
      if (view.monthRows.isNotEmpty) {
        out.add((_) => const TaxiTitleRow(title: TaxiCalendarStrings.tripsThisMonth, sub: TaxiCalendarStrings.amountsStayFree));
        for (var i = 0; i < view.monthRows.length; i++) {
          final e = view.monthRows[i];
          final first = i == 0;
          final last = i == view.monthRows.length - 1;
          out.add((_) => TaxiCardSegment(
                first: first,
                last: last,
                child: _row(
                  e,
                  TaxiTripRow(
                    entry: e,
                    line: TaxiTripText.monthLine(e),
                    trailing: TaxiChip(entry: e),
                    onTap: () => TaxiDriverDeps.openEntry(e.id),
                  ),
                ),
              ));
        }
      }
      out.add((_) => _pastLink());
      out.add((_) => Padding(padding: DS.insets(t: 10), child: TaxiReminderRow(controller: _c)));
    } else {
      out
        ..add((_) => Padding(padding: DS.insets(t: 6), child: Obx(() => _openCard(view))))
        ..add((_) => Padding(padding: DS.insets(t: 12), child: TaxiReminderRow(controller: _c)))
        ..add((_) => Padding(
              padding: DS.insets(t: 12, b: 12),
              child: TaxiMeterPair(
                left: ownTile,
                right: TaxiMeterTile(value: TaxiCalendarStrings.monthsAhead(PlanGate.limit(PlanKey.monthsAhead)), label: TaxiCalendarStrings.aheadYouCanSee),
              ),
            ))
        ..add((_) => PrimaryButton(label: TaxiCalendarStrings.addTrip, tone: TaxiCal.kit, onPressed: _addAction))
        ..addAll(_fullLine())
        ..add((_) => _pastLink());
    }
    if (view.hiddenCount > 0) out.addAll(_downgraded(view));
    out.addAll(_fromApp());
    return out;
  }

  Widget _openCard(TaxiMonthView view) {
    final s = _c.summary.value.valueOrNull;
    final rows = view.monthRows;
    final m = _c.month.value;
    return TaxiMoneyCard(
      month: m,
      locked: false,
      booked: s?.booked ?? TaxiCalendarController.sumBooked(rows),
      received: s?.received ?? TaxiCalendarController.sumReceived(rows),
      toCollect: s?.toCollect ?? TaxiCalendarController.sumToCollect(rows),
      onOpen: () => Get.toNamed(AppRoutes.taxiMoneySummary, arguments: TaxiCalendarNav.monthArgs(m)),
      onToCollect: () => Get.toNamed(AppRoutes.taxiBalanceDue, arguments: TaxiCalendarNav.monthArgs(m)),
    );
  }

  List<WidgetBuilder> _downgraded(TaxiMonthView view) {
    final rows = view.ownVisible;
    final out = <WidgetBuilder>[
      (_) => TaxiTitleRow(title: TaxiCalendarStrings.tripsYouAdded, sub: TaxiCalendarStrings.shownOf(rows.length)),
    ];
    for (var i = 0; i < rows.length; i++) {
      final e = rows[i];
      final first = i == 0;
      out.add((_) => TaxiCardSegment(
            first: first,
            last: false,
            child: _row(e, TaxiTripRow(entry: e, line: TaxiTripText.upcomingLine(e), trailing: TaxiChip(entry: e), onTap: () => TaxiDriverDeps.openEntry(e.id))),
          ));
    }
    out
      ..add((_) => TaxiCardSegment(
            first: rows.isEmpty,
            last: true,
            child: Padding(
              padding: DS.all(8),
              child: SoftLock.row(
                text: TaxiCalendarStrings.hiddenTrips(view.hiddenCount),
                taxi: true,
                unlocked: Padding(
                  padding: DS.all(6),
                  child: Text(TaxiCalendarStrings.hiddenTrips(view.hiddenCount), style: Ink3D.text(12, FontWeight.w600, Ink3D.grey, letterSpacing: 0)),
                ),
              ),
            ),
          ))
      ..add((_) => const TaxiShieldNote(text: TaxiCalendarStrings.nothingDeleted));
    return out;
  }

  List<WidgetBuilder> _fromApp() => [
        (_) => const TaxiTitleRow(title: TaxiCalendarStrings.fromTheApp, sub: TaxiCalendarStrings.allConfirmedTrips),
        (_) => TaxiDriverDeps.appBookings(),
      ];
}

class _FestivalCard extends StatelessWidget {
  const _FestivalCard({required this.festival});

  final FestivalRow festival;

  @override
  Widget build(BuildContext context) {
    final a = festival.dateFrom;
    final b = festival.dateTo;
    final range = a == null || b == null ? '' : TaxiCalendarStrings.dateRange(a, b);
    final state = festival.stateName;
    return Container(
      margin: DS.insets(b: 10),
      padding: DS.sym(h: 14, v: 10),
      decoration: BoxDecoration(
        color: TaxiCal.amberFill,
        borderRadius: DS.circular(14),
        border: Border.all(color: TaxiCal.look.lockLine, width: DS.s(1)),
      ),
      child: Row(
        children: [
          Art3D(asset: ListingArt.diyaLamp, size: 30),
          Gap.h(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(TaxiCalendarStrings.festivalTitle(festival.name, range), style: Ink3D.text(12.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                if (state != null) Text(TaxiCalendarStrings.festivalState(state), style: Ink3D.text(11, FontWeight.w500, TaxiCal.amber, letterSpacing: 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TaxiPlusFullLine extends StatelessWidget {
  const TaxiPlusFullLine({super.key, required this.limit});

  final int limit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(t: 8),
        child: Text(
          TaxiGateStringsCalendar.plusFull(limit),
          key: const ValueKey('taxi_plus_full_line'),
          textAlign: TextAlign.center,
          style: Ink3D.text(12, FontWeight.w500, Ink3D.grey, letterSpacing: 0),
        ),
      );
}
