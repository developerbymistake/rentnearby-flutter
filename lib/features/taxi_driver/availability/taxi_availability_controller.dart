import 'package:get/get.dart';

import '../../../utils/app_toast.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/calendar/month_grid_data.dart';
import '../../owner_core/data/owner_error_types.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../home/taxi_driver_home_controller.dart';
import '../home/taxi_home_compose.dart';
import '../strings/taxi_availability_strings.dart';
import '../taxi_driver_deps.dart';
import 'taxi_availability_api.dart';
import 'taxi_availability_models.dart';
import 'taxi_availability_store.dart';

typedef TaxiPendingDay = ({bool off, String? reason});

enum TaxiReasonKind { mark, saveReason, makeAvailable }

class TaxiReasonAction {
  const TaxiReasonAction._(this.kind, this.reason);

  const TaxiReasonAction.mark(String? reason) : this._(TaxiReasonKind.mark, reason);
  const TaxiReasonAction.saveReason(String? reason) : this._(TaxiReasonKind.saveReason, reason);
  const TaxiReasonAction.makeAvailable() : this._(TaxiReasonKind.makeAvailable, null);

  final TaxiReasonKind kind;
  final String? reason;
}

abstract final class TaxiAvailabilityDiff {
  static DateTime? _date(String key) => OwnerDates.day(key);

  static Map<String, TaxiPendingDay> normalise(Map<String, TaxiDayOff> base, Map<String, TaxiPendingDay> pending) {
    final out = <String, TaxiPendingDay>{};
    pending.forEach((k, p) {
      final saved = base[k];
      if (p.off) {
        if (saved != null && saved.reason == p.reason) return;
        out[k] = (off: true, reason: TaxiReasonText.clean(p.reason));
      } else {
        if (saved == null) return;
        out[k] = (off: false, reason: null);
      }
    });
    return out;
  }

  static ({List<TaxiDayOff> set, List<String> clear}) of(Map<String, TaxiDayOff> base, Map<String, TaxiPendingDay> pending) {
    final clean = normalise(base, pending);
    final keys = clean.keys.toList()..sort();
    final set = <TaxiDayOff>[];
    final clear = <String>[];
    for (final k in keys) {
      final p = clean[k];
      final d = _date(k);
      if (p == null || d == null) continue;
      if (p.off) {
        set.add(TaxiDayOff(date: d, reason: p.reason));
      } else {
        clear.add(k);
      }
    }
    return (set: set, clear: clear);
  }

  static Map<String, TaxiPendingDay> rebase(TaxiAvailability fresh, Map<String, TaxiPendingDay> pending, {required DateTime today}) {
    final kept = <String, TaxiPendingDay>{};
    final monthTo = fresh.window.monthTo;
    final windowEnd = monthTo == null ? null : OwnerDates.lastOfMonth(monthTo);
    pending.forEach((k, p) {
      final d = _date(k);
      if (d == null || d.isBefore(today)) return;
      if (p.off && fresh.bookedDays.contains(k)) return;
      final isNew = !fresh.daysOff.containsKey(k);
      if (p.off && isNew && windowEnd != null && d.isAfter(windowEnd)) return;
      kept[k] = p;
    });
    return normalise(fresh.daysOff, kept);
  }
}

class TaxiAvailabilityController extends GetxController {
  TaxiAvailabilityController({TaxiAvailabilityStore? store, TaxiAvailabilityApi api = const TaxiAvailabilityApi(), DateTime Function()? clock})
      : _givenStore = store,
        _api = api,
        _clock = clock ?? DateTime.now;

  static const String tag = 'taxi-availability';

  final TaxiAvailabilityStore? _givenStore;
  final TaxiAvailabilityApi _api;
  final DateTime Function() _clock;

  late final TaxiAvailabilityStore store = _givenStore ?? TaxiAvailabilityStore.ensureRegistered();

  final month = Rx<DateTime>(DateTime(2000));
  final cells = <DayCell>[].obs;
  final list = <TaxiDayOff>[].obs;
  final dirty = false.obs;
  final saving = false.obs;

  Map<String, TaxiPendingDay> _pending = {};
  DateTime _builtFor = DateTime(2000);
  final _flight = SingleFlight<bool>();
  Worker? _worker;

  Map<String, TaxiPendingDay> get pending => Map.unmodifiable(_pending);

  TaxiAvailability? get base => store.value.value;

  DateTime get today {
    final local = OwnerDates.only(_clock());
    final server = base?.today;
    return server != null && server.isAfter(local) ? server : local;
  }

  CalendarWindow get window => base?.window ?? CalendarWindow(monthFrom: OwnerDates.firstOfMonth(today), monthTo: OwnerDates.lastOfMonth(today));

  bool get switchOn {
    final home = TaxiDriverHomeController.maybe;
    if (home != null && home.data != null) return home.switchOn;
    return base?.switchOn ?? true;
  }

  bool get showOfflineNote {
    final d = TaxiDriverHomeController.maybe?.data;
    if (d != null) {
      final s = TaxiHomeCompose.stateOf(d.listing);
      if (s != TaxiHomeState.live && s != TaxiHomeState.offline) return false;
    }
    return !switchOn;
  }

  @override
  void onInit() {
    super.onInit();
    month.value = OwnerDates.firstOfMonth(today);
    _worker = ever<TaxiAvailability?>(store.value, (_) => _onFresh());
    _rebuild();
    store.ensure().ignore();
  }

  @override
  void onClose() {
    _worker?.dispose();
    super.onClose();
  }

  void _onFresh() {
    final b = base;
    if (b != null) _pending = TaxiAvailabilityDiff.rebase(b, _pending, today: today);
    final months = window.months(today);
    final m = month.value;
    if (!months.any((x) => x.year == m.year && x.month == m.month)) month.value = months.first;
    _rebuild();
  }

  void checkDay() {
    if (isClosed) return;
    if (!OwnerDates.sameDay(_builtFor, today)) _onFresh();
  }

  void setMonth(DateTime m) {
    month.value = OwnerDates.firstOfMonth(m);
    _rebuild();
  }

  String _key(DateTime d) => OwnerDates.dayText(d);

  bool isOff(DateTime d) {
    final k = _key(d);
    final p = _pending[k];
    if (p != null) return p.off;
    return base?.daysOff.containsKey(k) ?? false;
  }

  String? reasonOf(DateTime d) {
    final k = _key(d);
    final p = _pending[k];
    if (p != null) return p.off ? p.reason : null;
    return base?.daysOff[k]?.reason;
  }

  TaxiAvailDay stateOf(DayCell cell) {
    if (!cell.inMonth || cell.isPast || cell.outsideWindow) return TaxiAvailDay.past;
    if (base?.bookedDays.contains(_key(cell.date)) ?? false) return TaxiAvailDay.booked;
    if (isOff(cell.date)) return TaxiAvailDay.off;
    return TaxiAvailDay.free;
  }

  void apply(DateTime day, TaxiReasonAction action) {
    if (saving.value) return;
    final d = OwnerDates.only(day);
    if (d.isBefore(today)) {
      checkDay();
      return;
    }
    final k = _key(d);
    final next = Map<String, TaxiPendingDay>.from(_pending);
    switch (action.kind) {
      case TaxiReasonKind.mark:
      case TaxiReasonKind.saveReason:
        if (base?.bookedDays.contains(k) ?? false) {
          bookedTap();
          return;
        }
        next[k] = (off: true, reason: TaxiReasonText.clean(action.reason));
      case TaxiReasonKind.makeAvailable:
        next[k] = (off: false, reason: null);
    }
    _pending = TaxiAvailabilityDiff.normalise(base?.daysOff ?? const {}, next);
    _rebuild();
  }

  void _rebuild() {
    final t = today;
    _builtFor = t;
    cells.assignAll(MonthGridData.build(month: month.value, entries: const [], today: t, window: window, stayNights: false));
    final rows = <String, TaxiDayOff>{};
    final saved = base?.daysOff ?? const <String, TaxiDayOff>{};
    saved.forEach((k, v) {
      if (!v.date.isBefore(t)) rows[k] = v;
    });
    _pending.forEach((k, p) {
      final d = OwnerDates.day(k);
      if (d == null) return;
      if (p.off) {
        rows[k] = TaxiDayOff(date: d, reason: p.reason);
      } else {
        rows.remove(k);
      }
    });
    final keys = rows.keys.toList()..sort();
    list.assignAll([
      for (final k in keys)
        if (rows[k] case final v?) v,
    ]);
    dirty.value = _pending.isNotEmpty;
  }

  ({List<TaxiDayOff> set, List<String> clear}) diff() => TaxiAvailabilityDiff.of(base?.daysOff ?? const {}, _pending);

  void bookedTap() => AppToast.info(TaxiAvailabilityStrings.toastBooked);

  Future<bool> save() => _flight.run(_save);

  Future<bool> _save() async {
    if (saving.value || _pending.isEmpty) return false;
    if (TaxiHourlyLimit.toastIfHeld(TaxiHourlyLimit.availability)) return false;
    final d = diff();
    if (d.set.isEmpty && d.clear.isEmpty) return false;
    saving.value = true;
    try {
      final r = await _api.save(set: d.set, clear: d.clear);
      if (isClosed) {
        if (r case OwnerOk<TaxiAvailability>(:final value)) _saved(value);
        return r is OwnerOk<TaxiAvailability>;
      }
      switch (r) {
        case OwnerOk<TaxiAvailability>(:final value):
          _pending = {};
          _saved(value);
          _rebuild();
          AppToast.success(TaxiAvailabilityStrings.toastSaved);
          return true;
        case OwnerRefused<TaxiAvailability>():
          _refused(r);
          return false;
        case OwnerOffline<TaxiAvailability>():
        case OwnerFailed<TaxiAvailability>():
          AppToast.error(TaxiAvailabilityStrings.toastFailed);
          return false;
      }
    } catch (_) {
      if (!isClosed) AppToast.error(TaxiAvailabilityStrings.toastFailed);
      return false;
    } finally {
      if (!isClosed) saving.value = false;
    }
  }

  void _saved(TaxiAvailability value) {
    store.apply(value);
    final counts = value.counts?.raw;
    if (counts != null) TaxiDriverHomeController.maybe?.patchAvailability(counts);
    TaxiDriverDeps.refreshHome().ignore();
  }

  void _refused(OwnerRefused<TaxiAvailability> r) {
    if (TaxiHourlyLimit.toastIfLimited(r)) return;
    if (r.statusCode == 429) {
      AppToast.error(OwnerSharedStrings.tooManyTries);
      return;
    }
    switch (r.type) {
      case OwnerErrorTypes.dayOffBooked:
        AppToast.error(TaxiAvailabilityStrings.toastBooked);
        store.refresh(force: true).ignore();
      case OwnerErrorTypes.dayOffPast:
      case OwnerErrorTypes.planFeatureLocked:
      case OwnerErrorTypes.calendarOutsideWindow:
        AppToast.error(TaxiAvailabilityStrings.toastFailed);
        store.refresh(force: true).ignore();
      default:
        AppToast.error(TaxiAvailabilityStrings.toastFailed);
    }
  }
}
