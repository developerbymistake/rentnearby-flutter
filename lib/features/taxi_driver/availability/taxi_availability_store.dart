import 'package:get/get.dart';

import '../../../controllers/auth_controller.dart';
import '../../owner_core/data/owner_cache.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/sheets/owner_states.dart';
import 'taxi_availability_api.dart';
import 'taxi_availability_models.dart';

class TaxiAvailabilityStore extends GetxController {
  TaxiAvailabilityStore({TaxiAvailabilityApi api = const TaxiAvailabilityApi(), String? Function()? userId, DateTime Function()? clock})
      : _api = api,
        _userId = userId,
        _clock = clock ?? DateTime.now;

  static TaxiAvailabilityStore? get maybe => Get.isRegistered<TaxiAvailabilityStore>() ? Get.find<TaxiAvailabilityStore>() : null;

  static TaxiAvailabilityStore ensureRegistered() => maybe ?? Get.put(TaxiAvailabilityStore());

  static const Duration staleAfter = Duration(seconds: 30);

  final TaxiAvailabilityApi _api;
  final String? Function()? _userId;
  final DateTime Function() _clock;

  final value = Rxn<TaxiAvailability>();
  final load = Rx<OwnerLoad<TaxiAvailability>>(const OwnerLoadLoading());

  final _flight = SingleFlight<void>();
  final _latest = LatestOnly();
  Future<void>? _queued;
  DateTime? _loadedAt;
  bool _cacheRead = false;
  bool _prefetched = false;

  String? get _uid => _userId != null ? _userId() : (Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null);

  DateTime get today {
    final local = OwnerDates.only(_clock());
    final server = value.value?.today;
    return server != null && server.isAfter(local) ? server : local;
  }

  Set<String> get offKeys => value.value?.offKeys ?? const <String>{};

  bool isOff(DateTime day) {
    final v = value.value;
    if (v == null) return false;
    final d = OwnerDates.only(day);
    return !d.isBefore(today) && v.hasOff(d);
  }

  bool isBooked(DateTime day) => value.value?.isBooked(day) ?? false;

  void prefetch() {
    if (_prefetched) return;
    _prefetched = true;
    ensure().ignore();
  }

  Future<void> ensure() {
    if (!_cacheRead) {
      _cacheRead = true;
      _readCache();
    }
    final at = _loadedAt;
    if (at != null && _clock().difference(at) < staleAfter) return Future.value();
    return refresh();
  }

  void _readCache() {
    if (value.value != null) return;
    final raw = OwnerCache.read(_uid, OwnerCacheKeys.daysOff);
    if (raw == null) return;
    final v = TaxiAvailability.fromJson(raw);
    value.value = v;
    load.value = OwnerLoadData<TaxiAvailability>(v);
  }

  Future<void> refresh({bool force = false}) {
    if (!force || !_flight.busy) return _flight.run(_refresh);
    return _queued ??= _refreshAfterCurrent();
  }

  Future<void> _refreshAfterCurrent() async {
    try {
      await _flight.run(_refresh);
    } catch (_) {}
    _queued = null;
    if (!isClosed) await _flight.run(_refresh);
  }

  Future<void> _refresh() async {
    final id = _latest.next();
    final saved = value.value;
    if (saved == null) load.value = const OwnerLoadLoading();
    OwnerResult<TaxiAvailability> r;
    try {
      r = await _api.load();
    } catch (_) {
      r = const OwnerFailed<TaxiAvailability>(message: '');
    }
    if (isClosed || !_latest.isLatest(id)) return;
    switch (r) {
      case OwnerOk<TaxiAvailability>(value: final fresh):
        _publish(fresh);
      default:
        load.value = saved != null ? OwnerLoadData<TaxiAvailability>(saved, stale: true) : OwnerLoads.from<TaxiAvailability>(r);
    }
  }

  void apply(TaxiAvailability v) {
    _latest.cancel();
    _publish(v);
  }

  void _publish(TaxiAvailability v) {
    _loadedAt = _clock();
    value.value = v;
    load.value = OwnerLoadData<TaxiAvailability>(v);
    OwnerCache.write(_uid, OwnerCacheKeys.daysOff, v.raw);
  }

  @override
  void onClose() {
    _latest.cancel();
    super.onClose();
  }
}
