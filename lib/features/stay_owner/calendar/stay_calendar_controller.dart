import 'package:get/get.dart';

import '../../../controllers/auth_controller.dart';
import '../../owner_core/calendar/calendar_api.dart';
import '../../owner_core/calendar/calendar_core_controller.dart';
import '../../owner_core/calendar/month_grid_data.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_cache.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../home/stay_owner_home_controller.dart';
import '../reminder/stay_reminder_row.dart';
import '../stay_owner_deps.dart';
import 'data/stay_calendar_apis.dart';
import 'models/stay_calendar_models.dart';

abstract final class StayMeterKeys {
  static const entries = 'CalendarEntries';
  static const blocks = 'BlockedRanges';
  static const specialPrices = 'SpecialPrices';
}

class StayCalendarController extends CalendarCoreController {
  StayCalendarController({
    CalendarApi? api,
    this.blockApi = const StayBlockApi(),
    this.priceApi = const StaySpecialPriceApi(),
    super.clock,
    this.userIdOf,
    this.listingNameOf,
  }) : super(api: api ?? const CalendarApi(CalendarApi.stayPrefix));

  static const String tag = 'stay-calendar';

  static StayCalendarController? get maybe => Get.isRegistered<StayCalendarController>(tag: tag) ? Get.find<StayCalendarController>(tag: tag) : null;

  final StayBlockApi blockApi;
  final StaySpecialPriceApi priceApi;
  final String? Function()? userIdOf;
  final String Function()? listingNameOf;

  final summary = Rx<OwnerLoad<MoneySummary>>(const OwnerLoadLoading());
  final selectedDay = Rxn<DateTime>();
  final monthRows = <CalendarEntry>[].obs;
  final ownActive = <CalendarEntry>[].obs;
  final activeBlocks = <CalendarBlock>[].obs;
  final priceRules = <SpecialPriceBand>[].obs;
  final priceRooms = <StayPriceRoom>[].obs;

  final LatestOnly _summaryLatest = LatestOnly();
  final SingleFlight<OwnerResult<StayBlockWrite>> _blockWrite = SingleFlight();
  final SingleFlight<OwnerResult<void>> _blockDelete = SingleFlight();
  Worker? _loadWorker;

  @override
  bool get stayNights => true;

  @override
  String? get userId {
    final f = userIdOf;
    if (f != null) return f();
    return Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null;
  }

  String get listingName {
    final f = listingNameOf;
    if (f != null) return f();
    return StayOwnerHomeController.maybe?.data?.listing.name ?? '';
  }

  CalendarMonth? get data => load.value.valueOrNull;

  CalendarWindow get window => data?.window ?? const CalendarWindow();

  bool get paymentEnabled => data?.paymentEnabled ?? PlanGate.paymentOn;

  bool get freeLook => window.locked && PlanGate.canUpgrade;

  bool get plusPill => paymentEnabled && !window.locked && !freeLook && PlanGate.paymentOn;

  Meter? meter(String key) {
    final d = data;
    return d == null ? null : Meter.find(d.meters, key);
  }

  bool fullOnFree(String key) {
    final m = meter(key);
    if (m == null || m.limit <= 0) return false;
    return PlanGate.canUpgrade && m.full;
  }

  bool needsG10(DateTime dateTo) => fullOnFree(StayMeterKeys.entries) && !dateTo.isBefore(today);

  bool get needsG11 => fullOnFree(StayMeterKeys.blocks);

  bool get summaryOpen => (data?.summaryAllowed ?? false) || !PlanGate.canUpgrade;

  bool get afterPlusSections {
    final d = data;
    if (d == null) return false;
    return d.hiddenCount > 0 || d.specialPrices.any((b) => b.pausedByPlan);
  }

  @override
  void onInit() {
    super.onInit();
    _loadWorker = ever<OwnerLoad<CalendarMonth>>(load, (_) => _prepare());
  }

  Future<void> start({DateTime? date}) async {
    final m = date == null ? month.value : OwnerDates.firstOfMonth(date);
    await open(m);
  }

  void _prepare() {
    final d = data;
    if (d == null) return;
    StayReminderState.value.value = d.reminder;
    final m = month.value;
    final rows = d.entries.where((e) {
      final f = e.dateFrom;
      return f != null && !e.cancelled && f.year == m.year && f.month == m.month;
    }).toList()
      ..sort(_byDate);
    monthRows.assignAll(rows);
    final t = today;
    final own = d.entries.where((e) => e.isManual && !e.cancelled && !(e.lastDay ?? t).isBefore(t)).toList()
      ..sort((a, b) => (a.dateFrom ?? t).compareTo(b.dateFrom ?? t));
    ownActive.assignAll(own);
    if (activeBlocks.isEmpty) activeBlocks.assignAll(d.blocks.where((b) => !(b.dateTo ?? t).isBefore(t)));
    if (summaryOpen) loadSummary();
    if (afterPlusSections) {
      loadSections();
      loadOwnUpcoming();
    } else if (priceRooms.isEmpty && d.specialPrices.any((b) => b.active)) {
      loadRooms();
    }
  }

  bool _roomsAsked = false;

  Future<void> loadRooms() async {
    if (_roomsAsked) return;
    _roomsAsked = true;
    final p = await priceApi.list();
    if (isClosed) return;
    if (p is OwnerOk<StaySpecialPricesPage>) priceRooms.assignAll(p.value.rooms);
  }

  Future<void> loadSummary() async {
    final m = month.value;
    final key = OwnerCacheKeys.summary(OwnerDates.monthKey(m));
    final id = _summaryLatest.next();
    MoneySummary? saved;
    final raw = OwnerCache.read(userId, key);
    if (raw != null) saved = MoneySummary.fromJson(raw);
    if (summary.value.valueOrNull == null || saved != null) {
      summary.value = saved == null ? const OwnerLoadLoading() : OwnerLoadData(saved, stale: true);
    }
    final r = await api.summary(m);
    if (isClosed || !_summaryLatest.isLatest(id)) return;
    if (r is OwnerOk<MoneySummary>) {
      summary.value = OwnerLoadData(r.value);
      OwnerCache.write(userId, key, r.value.raw);
      return;
    }
    summary.value = OwnerLoads.from<MoneySummary>(r, saved: saved);
  }

  final LatestOnly _ownLatest = LatestOnly();

  // After Plus the visible own bookings span months; the upcoming read is that set in date order.
  Future<void> loadOwnUpcoming() async {
    final id = _ownLatest.next();
    final r = await api.upcoming();
    if (isClosed || !_ownLatest.isLatest(id)) return;
    if (r is OwnerOk<UpcomingPage>) {
      final t = today;
      ownActive.assignAll(r.value.items.where((e) => e.isManual && !e.cancelled && !(e.lastDay ?? t).isBefore(t)));
    }
  }

  Future<void> loadSections() async {
    final b = await blockApi.list();
    if (isClosed) return;
    if (b is OwnerOk<StayBlockList>) {
      activeBlocks.assignAll(b.value.items);
      OwnerCache.write(userId, OwnerCacheKeys.blocks, {'items': [for (final x in b.value.items) _blockJson(x)]});
    }
    final p = await priceApi.list();
    if (isClosed) return;
    if (p is OwnerOk<StaySpecialPricesPage>) {
      priceRules.assignAll(p.value.items);
      priceRooms.assignAll(p.value.rooms);
    }
  }

  static int _byDate(CalendarEntry a, CalendarEntry b) {
    final fa = a.dateFrom;
    final fb = b.dateFrom;
    if (fa != null && fb != null && fa != fb) return fa.compareTo(fb);
    return MonthGridData.dayOrder(a, b);
  }

  static Map<String, dynamic> _blockJson(CalendarBlock b) => {
        'id': b.id,
        'dateFrom': OwnerDates.dayTextOrNull(b.dateFrom),
        'dateTo': OwnerDates.dayTextOrNull(b.dateTo),
        'reason': b.reason,
        'version': b.version,
      };

  Future<void> goTo(DateTime m) async {
    selectedDay.value = null;
    summary.value = const OwnerLoadLoading();
    await open(m);
  }

  void selectDay(DateTime? d) => selectedDay.value = d;

  List<CalendarEntry> dayEntries(DateTime day) {
    final d = monthOf(day) ?? current;
    if (d == null) return const [];
    return MonthGridData.entriesOn(day, d.entries, stayNights: true);
  }

  CalendarBlock? knownBlock(String id) {
    for (final b in [...activeBlocks, ...?data?.blocks]) {
      if (b.id == id) return b;
    }
    return null;
  }

  CalendarBlock? blockOn(DateTime day) {
    for (final b in [...?data?.blocks, ...activeBlocks]) {
      final f = b.dateFrom;
      final t = b.dateTo;
      if (f != null && t != null && OwnerDates.within(day, f, t)) return b;
    }
    return null;
  }

  SpecialPriceBand? ruleOn(DateTime day) {
    for (final b in data?.specialPrices ?? const <SpecialPriceBand>[]) {
      final f = b.dateFrom;
      final t = b.dateTo;
      if (b.active && f != null && t != null && OwnerDates.within(day, f, t)) return b;
    }
    return null;
  }

  FestivalRow? festivalOn(DateTime day) {
    for (final f in data?.festivals ?? const <FestivalRow>[]) {
      final a = f.dateFrom;
      final b = f.dateTo;
      if (a != null && b != null && OwnerDates.within(day, a, b)) return f;
    }
    return null;
  }

  SpecialPriceBand? get monthRule {
    final m = month.value;
    final first = OwnerDates.firstOfMonth(m);
    final last = OwnerDates.lastOfMonth(m);
    for (final b in data?.specialPrices ?? const <SpecialPriceBand>[]) {
      final f = b.dateFrom;
      final t = b.dateTo;
      if (b.direction == PriceDirection.unknown || f == null || t == null) continue;
      if (!t.isBefore(first) && !f.isAfter(last)) return b;
    }
    return null;
  }

  int overlapCount(DateTime from, DateTime to, {String? exceptId}) {
    var n = 0;
    final seen = <String>{};
    for (var m = OwnerDates.firstOfMonth(from); !m.isAfter(to); m = OwnerDates.addMonths(m, 1)) {
      for (final e in monthOf(m)?.entries ?? const <CalendarEntry>[]) {
        if (e.cancelled || e.id == exceptId || !seen.add(e.id)) continue;
        final f = e.dateFrom;
        final t = e.dateTo ?? f;
        if (f == null || t == null) continue;
        if (f.isBefore(to) && t.isAfter(from)) n++;
      }
    }
    return n;
  }

  bool blockedBetween(DateTime from, DateTime to) {
    for (final b in [...?data?.blocks, ...activeBlocks]) {
      final f = b.dateFrom;
      final t = b.dateTo;
      if (f == null || t == null) continue;
      if (!f.isAfter(OwnerDates.addDays(to, -1)) && !t.isBefore(from)) return true;
    }
    return false;
  }

  Future<OwnerResult<StayBlockWrite>> saveBlock(StayBlockDraft d, {required bool edit, bool confirm = false}) async {
    saving.value = true;
    staleLine.value = false;
    try {
      final r = await _blockWrite.run(() => edit ? blockApi.update(d, confirm: confirm) : blockApi.create(d, confirm: confirm));
      if (isClosed) return r;
      if (r is OwnerOk<StayBlockWrite>) {
        activeBlocks.clear();
        await afterWrite();
      } else if (r is OwnerRefused<StayBlockWrite> && r.type == 'StaleEdit') {
        staleLine.value = true;
        await reload();
      }
      return r;
    } finally {
      if (!isClosed) saving.value = false;
    }
  }

  Future<OwnerResult<void>> removeBlock(String id) async {
    final r = await _blockDelete.run(() => blockApi.delete(id));
    if (isClosed) return r;
    if (r is OwnerOk<void>) {
      activeBlocks.removeWhere((b) => b.id == id);
      await afterWrite();
    }
    return r;
  }

  @override
  Future<void> afterWrite() async {
    await super.afterWrite();
    StayOwnerDeps.refreshHome();
  }

  @override
  void onClose() {
    _loadWorker?.dispose();
    _summaryLatest.cancel();
    _ownLatest.cancel();
    super.onClose();
  }
}
