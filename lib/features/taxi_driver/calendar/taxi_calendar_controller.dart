import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../owner_core/calendar/calendar_api.dart';
import '../../owner_core/calendar/calendar_core_controller.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_cache.dart';
import '../../owner_core/data/owner_page.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/money/money_note_math.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../availability/taxi_availability_api.dart';
import '../availability/taxi_availability_store.dart';
import '../taxi_driver_deps.dart';
import 'models/taxi_calendar_models.dart';

abstract final class TaxiMeterKeys {
  static const entries = 'CalendarEntries';
}

class TaxiCalendarController extends CalendarCoreController with WidgetsBindingObserver {
  // ignore: use_super_parameters
  TaxiCalendarController({CalendarApi? api, DateTime Function()? clock, String? Function()? userIdOf})
      // ignore: prefer_initializing_formals
      : _userIdOf = userIdOf,
        _now = clock ?? DateTime.now,
        super(api: api ?? const CalendarApi(CalendarApi.taxiPrefix), clock: clock);

  static const Duration staleAfter = Duration(seconds: 30);

  static const String tag = 'taxi-calendar';
  static int _users = 0;

  static TaxiCalendarController? get maybe =>
      Get.isRegistered<TaxiCalendarController>(tag: tag) ? Get.find<TaxiCalendarController>(tag: tag) : null;

  static TaxiCalendarController acquire({TaxiCalendarController Function()? create}) {
    final found = maybe;
    if (found != null) {
      _users++;
      return found;
    }
    _users = 1;
    return Get.put(create?.call() ?? TaxiCalendarController(), tag: tag);
  }

  static void release() {
    _users = _users > 0 ? _users - 1 : 0;
    if (_users == 0 && maybe != null) Get.delete<TaxiCalendarController>(tag: tag, force: true);
  }

  static void resetUsers() => _users = 0;

  final String? Function()? _userIdOf;
  final DateTime Function() _now;
  DateTime? _loadedAt;
  Worker? _tabWorker;
  bool _tabCurrent = true;
  final SingleFlight<void> _all = SingleFlight();
  Future<void>? _queuedAll;

  final summary = Rx<OwnerLoad<MoneySummary>>(const OwnerLoadLoading());
  final reminderOn = Rxn<bool>();
  final reminderBusy = false.obs;
  final view = Rx<TaxiMonthView>(TaxiMonthView.empty);

  bool? _reminderConfirmed;
  final LatestOnly _summaryLatest = LatestOnly();
  final SingleFlight<OwnerResult<CalendarReminder>> _reminder = SingleFlight();
  Worker? _loadWorker;

  @override
  bool get stayNights => false;

  @override
  String? get userId {
    final f = _userIdOf;
    if (f != null) return f();
    return Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null;
  }

  @override
  void onInit() {
    super.onInit();
    _loadWorker = ever<OwnerLoad<CalendarMonth>>(load, (_) => _rebuildView());
    WidgetsBinding.instance.addObserver(this);
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      _tabCurrent = auth.tabIndex.value == AppTabs.fourth;
      _tabWorker = ever<int>(auth.tabIndex, (i) {
        _tabCurrent = i == AppTabs.fourth;
        if (_tabCurrent) refreshIfStale();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _tabCurrent) refreshIfStale();
  }

  @override
  Future<void> open(DateTime m, {bool force = false}) {
    _loadedAt = _now();
    return super.open(m, force: force);
  }

  Future<void> refreshIfStale() async {
    final at = _loadedAt;
    if (at != null && _now().difference(at) < staleAfter) return;
    await refreshAll();
  }

  Future<void> refreshAll({bool force = false}) {
    if (!force || !_all.busy) return _all.run(_reloadAll);
    return _queuedAll ??= _refreshAfterCurrent();
  }

  Future<void> _refreshAfterCurrent() async {
    try {
      await _all.run(_reloadAll);
    } catch (_) {}
    _queuedAll = null;
    if (!isClosed) await _all.run(_reloadAll);
  }

  Future<void> _reloadAll() async {
    await reload();
    if (isClosed) return;
    await loadSummary();
  }

  DateTime get serverToday => current?.today ?? today;

  void _rebuildView() {
    final data = load.value.valueOrNull;
    view.value = data == null ? TaxiMonthView.empty : TaxiMonthView.build(month.value, data, today: serverToday);
    final r = data?.reminder;
    if (r != null && !reminderBusy.value) reminderOn.value = _reminderConfirmed ?? r.on;
  }

  bool get summaryLocked {
    final data = current;
    if (data == null) return PlanGate.canUpgrade && !PlanGate.on(PlanKey.monthSummary);
    return !data.summaryAllowed && PlanGate.canUpgrade;
  }

  bool get reminderLocked {
    final data = current;
    if (data == null) return PlanGate.canUpgrade && !PlanGate.on(PlanKey.reminders);
    return !data.reminder.allowed && PlanGate.canUpgrade;
  }

  Meter get entriesMeter {
    final m = current == null ? null : Meter.find(current!.meters, TaxiMeterKeys.entries);
    if (m != null) return m;
    return Meter(key: TaxiMeterKeys.entries, used: view.value.ownActive, limit: PlanGate.limit(PlanKey.calendarEntries));
  }

  bool get entriesFull => entriesMeter.limit > 0 && entriesMeter.used >= entriesMeter.limit;

  List<CalendarEntry> dayRows(DateTime day) => entriesOn(day);

  int bookingsOn(DateTime day) => entriesOn(day).where((e) => e.isAuto && !e.cancelled).length;

  FestivalRow? festivalOn(DateTime day) {
    final data = monthOf(day) ?? current;
    if (data == null) return null;
    for (final f in data.festivals) {
      final a = f.dateFrom;
      final b = f.dateTo;
      if (a != null && b != null && OwnerDates.within(day, a, b)) return f;
    }
    return null;
  }

  bool canAddOn(DateTime day) {
    final data = monthOf(day) ?? current;
    final w = data?.window;
    if (w == null) return !day.isBefore(OwnerDates.addDays(serverToday, -7));
    return w.allowsManual(day);
  }

  List<DateTime> manualDays(DateTime from, DateTime to) {
    final out = <DateTime>{};
    final seen = <String>{};
    for (var m = OwnerDates.firstOfMonth(from); !m.isAfter(to) && seen.length < 13; m = OwnerDates.addMonths(m, 1)) {
      seen.add(OwnerDates.monthKey(m));
      final data = monthOf(m);
      if (data == null) continue;
      for (final e in data.entries) {
        final d = e.dateFrom;
        if (e.isManual && !e.cancelled && d != null && OwnerDates.within(d, from, to)) out.add(d);
      }
    }
    return out.toList()..sort();
  }

  Future<void> loadSummary() async {
    final m = month.value;
    final key = OwnerDates.monthKey(m);
    if (summaryLocked) {
      summary.value = const OwnerLoadLocked(TaxiSummaryKeys.monthSummary);
      return;
    }
    final saved = OwnerCache.read(userId, OwnerCacheKeys.summary(key));
    final savedValue = saved == null ? null : MoneySummary.fromJson(saved);
    if (savedValue != null) {
      summary.value = OwnerLoadData(savedValue);
    } else {
      summary.value = const OwnerLoadLoading();
    }
    final id = _summaryLatest.next();
    final r = await api.summary(m);
    if (isClosed || !_summaryLatest.isLatest(id)) return;
    if (r is OwnerOk<MoneySummary>) {
      OwnerCache.write(userId, OwnerCacheKeys.summary(key), r.value.raw);
    }
    summary.value = OwnerLoads.from<MoneySummary>(r, saved: savedValue);
  }

  Future<OwnerResult<CalendarReminder>?> setReminder(bool on) async {
    if (reminderBusy.value) return null;
    final before = reminderOn.value ?? false;
    reminderOn.value = on;
    reminderBusy.value = true;
    try {
      final r = await _reminder.run(() => api.reminder(on));
      if (isClosed) return r;
      if (r is OwnerOk<CalendarReminder>) {
        _reminderConfirmed = r.value.on;
        reminderOn.value = r.value.on;
      } else {
        reminderOn.value = before;
      }
      return r;
    } finally {
      if (!isClosed) reminderBusy.value = false;
    }
  }

  Future<OwnerResult<UpcomingPage>> upcoming({String? cursor}) => api.upcoming(cursor: cursor);

  Future<OwnerResult<OwnerPage<CalendarEntry>>> past({String? cursor}) => api.past(cursor: cursor);

  Future<OwnerResult<OwnerPage<CalendarEntry>>> balanceDue(DateTime m, {String? cursor}) => api.balanceDue(m, cursor: cursor);

  Future<OwnerResult<CalendarEntry>> entry(String id) => api.entry(id);

  @override
  Future<OwnerResult<EntryWriteResult>> create(CalendarEntryDraft draft) => TaxiHourlyLimit.guard(TaxiHourlyLimit.bookings, () => super.create(draft));

  @override
  Future<OwnerResult<EntryWriteResult>> edit(CalendarEntryDraft draft) => TaxiHourlyLimit.guard(TaxiHourlyLimit.bookings, () => super.edit(draft));

  @override
  Future<OwnerResult<EntryWriteResult>> saveMoney(CalendarEntry e, {int? finalAmount, int? receivedSoFar, required bool paidInFull}) =>
      TaxiHourlyLimit.guard(TaxiHourlyLimit.bookings, () => super.saveMoney(e, finalAmount: finalAmount, receivedSoFar: receivedSoFar, paidInFull: paidInFull));

  @override
  Future<OwnerResult<void>> delete(String id) => TaxiHourlyLimit.guard(TaxiHourlyLimit.bookings, () => super.delete(id));

  Future<OwnerResult<EntryWriteResult>> markPaid(CalendarEntry e) =>
      saveMoney(e, finalAmount: e.finalAmount, receivedSoFar: e.receivedSoFar, paidInFull: true);

  @override
  Future<void> afterWrite() async {
    await super.afterWrite();
    if (isClosed) return;
    OwnerCache.remove(userId, OwnerCacheKeys.summary(OwnerDates.monthKey(month.value)));
    if (!summaryLocked) loadSummary().ignore();
    TaxiAvailabilityStore.maybe?.refresh(force: true).ignore();
    TaxiDriverDeps.refreshHome().ignore();
  }

  static int sumBooked(Iterable<CalendarEntry> rows) =>
      rows.where((e) => !e.cancelled).fold(0, (s, e) => s + (e.finalAmount ?? 0));

  static int sumReceived(Iterable<CalendarEntry> rows) =>
      rows.where((e) => !e.cancelled).fold(0, (s, e) => s + MoneyNoteMath.received(e.money));

  static int sumToCollect(Iterable<CalendarEntry> rows) =>
      rows.where((e) => !e.cancelled).fold(0, (s, e) => s + (MoneyNoteMath.balance(e.money) ?? 0));

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabWorker?.dispose();
    _loadWorker?.dispose();
    _summaryLatest.cancel();
    super.onClose();
  }
}

abstract final class TaxiSummaryKeys {
  static const monthSummary = 'MonthSummary';
}
