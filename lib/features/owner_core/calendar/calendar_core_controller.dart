import 'package:get/get.dart';

import '../data/owner_cache.dart';
import '../data/owner_error_types.dart';
import '../data/owner_result.dart';
import '../data/single_flight.dart';
import '../json/owner_dates.dart';
import '../sheets/owner_states.dart';
import 'calendar_api.dart';
import 'month_grid_data.dart';
import 'models/calendar_models.dart';

abstract class CalendarCoreController extends GetxController {
  CalendarCoreController({required this.api, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final CalendarApi api;
  final DateTime Function() _clock;

  bool get stayNights;
  String? get userId;

  DateTime get today => OwnerDates.only(_clock());

  final month = Rx<DateTime>(DateTime(2000));
  final load = Rx<OwnerLoad<CalendarMonth>>(const OwnerLoadLoading());
  final grid = <DayCell>[].obs;
  final staleLine = false.obs;
  final saving = false.obs;

  final Map<String, CalendarMonth> _months = {};
  final Map<String, LatestOnly> _latest = {};
  final Map<String, SingleFlight<OwnerResult<EntryWriteResult>>> _writes = {};
  int _writing = 0;
  final SingleFlight<OwnerResult<void>> _delete = SingleFlight();

  CalendarMonth? get current => _months[OwnerDates.monthKey(month.value)];

  CalendarMonth? monthOf(DateTime m) => _months[OwnerDates.monthKey(m)];

  @override
  void onInit() {
    super.onInit();
    month.value = OwnerDates.firstOfMonth(today);
  }

  static DateTime _rangeEnd(DateTime m) => OwnerDates.lastOfMonth(m);

  Future<void> open(DateTime m, {bool force = false}) async {
    final first = OwnerDates.firstOfMonth(m);
    month.value = first;
    final key = OwnerDates.monthKey(first);
    final cached = _months[key] ?? _readSaved(key);
    if (cached != null) {
      _months[key] = cached;
      _apply(first, cached, stale: false);
      if (!force) {
        _refresh(first);
        return;
      }
    } else {
      load.value = const OwnerLoadLoading();
    }
    await _refresh(first);
  }

  Future<void> reload() => open(month.value, force: true);

  Future<void> _refresh(DateTime first) async {
    final key = OwnerDates.monthKey(first);
    final latest = _latest[key] ??= LatestOnly();
    final id = latest.next();
    final r = await api.month(first, _rangeEnd(first));
    if (isClosed || !latest.isLatest(id)) return;
    final saved = _months[key];
    if (r is OwnerOk<CalendarMonth>) {
      _months[key] = r.value;
      OwnerCache.write(userId, OwnerCacheKeys.calMonth(key), r.value.raw);
      if (OwnerDates.monthKey(month.value) == key) _apply(first, r.value, stale: false);
      return;
    }
    if (OwnerDates.monthKey(month.value) != key) return;
    final next = OwnerLoads.from<CalendarMonth>(r, saved: saved);
    load.value = next;
    if (next is OwnerLoadData<CalendarMonth>) _rebuildGrid(first, next.value);
  }

  void _apply(DateTime first, CalendarMonth data, {required bool stale}) {
    load.value = OwnerLoadData(data, stale: stale);
    _rebuildGrid(first, data);
  }

  void _rebuildGrid(DateTime first, CalendarMonth data) {
    grid.assignAll(MonthGridData.build(
      month: first,
      entries: data.entries,
      blocks: data.blocks,
      bands: data.specialPrices,
      festivals: data.festivals,
      today: data.today ?? today,
      window: data.window,
      stayNights: stayNights,
    ));
  }

  List<CalendarEntry> entriesOn(DateTime day) {
    final data = monthOf(day) ?? current;
    if (data == null) return const [];
    return MonthGridData.entriesOn(day, data.entries, stayNights: stayNights);
  }

  Future<OwnerResult<EntryWriteResult>> create(CalendarEntryDraft draft) => _runWrite('create', () => api.create(draft));

  Future<OwnerResult<EntryWriteResult>> edit(CalendarEntryDraft draft) => _runWrite('edit:${draft.id}', () => api.update(draft));

  Future<OwnerResult<EntryWriteResult>> saveMoney(CalendarEntry e, {int? finalAmount, int? receivedSoFar, required bool paidInFull}) =>
      _runWrite('money:${e.id}', () => api.money(e.id, finalAmount: finalAmount, receivedSoFar: receivedSoFar, paidInFull: paidInFull, version: e.version));

  Future<OwnerResult<void>> delete(String id) async {
    saving.value = true;
    try {
      final r = await _delete.run(() => api.delete(id));
      if (!isClosed && r is OwnerOk<void>) await afterWrite();
      return r;
    } finally {
      if (!isClosed) saving.value = false;
    }
  }

  Future<OwnerResult<EntryWriteResult>> _runWrite(String op, Future<OwnerResult<EntryWriteResult>> Function() call) async {
    _writing++;
    saving.value = true;
    staleLine.value = false;
    try {
      final r = await (_writes[op] ??= SingleFlight()).run(call);
      if (isClosed) return r;
      if (r is OwnerOk<EntryWriteResult>) {
        await afterWrite();
      } else if (r is OwnerRefused<EntryWriteResult> && OwnerRefusal.stale(r)) {
        staleLine.value = true;
        await reload();
      }
      return r;
    } finally {
      _writing--;
      if (!isClosed) saving.value = _writing > 0;
    }
  }

  Future<void> afterWrite() async {
    _months.clear();
    await reload();
  }

  void clearCache() {
    _months.clear();
    grid.clear();
  }

  CalendarMonth? _readSaved(String key) {
    final raw = OwnerCache.read(userId, OwnerCacheKeys.calMonth(key));
    return raw == null ? null : CalendarMonth.fromJson(raw);
  }

  @override
  void onClose() {
    for (final l in _latest.values) {
      l.cancel();
    }
    super.onClose();
  }
}
