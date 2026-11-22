// ignore_for_file: prefer_initializing_formals
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../utils/app_toast.dart';
import '../../owner_core/data/owner_api.dart';
import '../../owner_core/data/owner_cache.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/json/owner_json.dart';
import '../../owner_core/session/owner_session_hooks.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../taxi/models/taxi_owner_model.dart';
import '../../taxi/setup/taxi_setup_controller.dart';
import '../strings/taxi_hub_strings.dart';
import '../calendar/taxi_calendar_controller.dart';
import '../taxi_driver_deps.dart';

class TaxiHubController extends GetxController with WidgetsBindingObserver {
  static const String tag = 'taxi-hub';
  static const Duration staleAfter = Duration(seconds: 30);

  static TaxiHubController? get maybe => Get.isRegistered<TaxiHubController>(tag: tag) ? Get.find<TaxiHubController>(tag: tag) : null;

  TaxiHubController({
    String? Function()? userId,
    DateTime Function()? clock,
    Future<Map<String, dynamic>> Function()? fetch,
    Future<OwnerResult<void>> Function()? deleteTaxiCall,
  })  : _userId = userId,
        _clock = clock ?? DateTime.now,
        _fetchOverride = fetch,
        _deleteTaxiCall = deleteTaxiCall;

  final String? Function()? _userId;
  final DateTime Function() _clock;
  final Future<Map<String, dynamic>> Function()? _fetchOverride;
  final Future<OwnerResult<void>> Function()? _deleteTaxiCall;

  final load = Rx<OwnerLoad<TaxiOwnerModel>>(const OwnerLoadLoading());
  final paused = false.obs;
  final staleNotice = false.obs;
  final busy = false.obs;
  final deleting = false.obs;
  final scrollTarget = Rxn<String>();

  final _latest = LatestOnly();
  final _flight = SingleFlight<void>();
  DateTime? _loadedAt;
  Worker? _tabWorker;
  Worker? _intentWorker;

  TaxiOwnerModel? get taxi => load.value.valueOrNull;

  String? get _uid => _userId != null ? _userId() : (Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null);

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    final raw = OwnerCache.read(_uid, OwnerCacheKeys.listing);
    if (raw != null) {
      final m = TaxiOwnerModel.fromJson(raw);
      if (m.id.isNotEmpty) load.value = OwnerLoadData<TaxiOwnerModel>(m, stale: true);
    }
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      _tabWorker = ever<int>(auth.tabIndex, (i) {
        if (i == AppTabs.hub) refreshIfStale();
      });
      _intentWorker = ever(auth.tabIntent, (intent) {
        if (intent == null || intent.index != AppTabs.hub) return;
        final taken = auth.takeIntent(AppTabs.hub);
        final section = taken?.args['section'];
        if (section is String) scrollTarget.value = section;
      });
    }
    reload();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabWorker?.dispose();
    _intentWorker?.dispose();
    _latest.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshIfStale();
  }

  Future<void> refreshIfStale() async {
    final at = _loadedAt;
    if (at != null && _clock().difference(at) < staleAfter) return;
    await reload();
  }

  Future<void>? _queued;

  Future<void> reload({bool force = false}) {
    if (!force || !_flight.busy) return _flight.run(_reload);
    return _queued ??= _reloadAfterCurrent();
  }

  Future<void> _reloadAfterCurrent() async {
    try {
      await _flight.run(_reload);
    } catch (_) {}
    _queued = null;
    if (!isClosed) await _flight.run(_reload);
  }

  Future<OwnerResult<Map<String, dynamic>>> _fetch() => OwnerApi.run(() => OwnerApi.read(() async {
        final o = _fetchOverride;
        final res = o != null ? await o() : await OwnerApi.transport.get('/taxis/me', null);
        return OwnerJson.map(res['data']);
      }));

  Future<void> _reload() async {
    final id = _latest.next();
    final saved = taxi;
    final r = await _fetch();
    if (isClosed || !_latest.isLatest(id)) return;
    _loadedAt = _clock();
    switch (r) {
      case OwnerOk<Map<String, dynamic>>(:final value):
        paused.value = false;
        staleNotice.value = false;
        if (OwnerJson.str(value['id']).isEmpty) {
          load.value = const OwnerLoadEmpty<TaxiOwnerModel>();
          OwnerCache.remove(_uid, OwnerCacheKeys.listing);
          if (Get.isRegistered<TaxiSetupController>()) Get.find<TaxiSetupController>().taxi.value = null;
          return;
        }
        final m = TaxiOwnerModel.fromJson(value);
        load.value = OwnerLoadData<TaxiOwnerModel>(m);
        OwnerCache.write(_uid, OwnerCacheKeys.listing, value);
        TaxiSetupController.ensure().taxi.value = m;
      case OwnerRefused<Map<String, dynamic>>(:final type, :final statusCode) when statusCode == 403 && type == 'TabInactive':
        paused.value = true;
        if (saved == null) load.value = const OwnerLoadPaused<TaxiOwnerModel>(null);
      case OwnerRefused<Map<String, dynamic>>(:final statusCode) when statusCode == 429:
        AppToast.info(TaxiHubStrings.tooManyTries);
        _keepOrError(saved);
      default:
        _keepOrError(saved);
    }
  }

  void _keepOrError(TaxiOwnerModel? saved) {
    if (saved != null) {
      staleNotice.value = true;
      load.value = OwnerLoadData<TaxiOwnerModel>(saved, stale: true);
    } else {
      load.value = const OwnerLoadError<TaxiOwnerModel>();
    }
  }

  Future<bool> _write(Future<bool> Function(TaxiSetupController c) call, String? toast) async {
    if (busy.value) return false;
    busy.value = true;
    try {
      final ok = await call(TaxiSetupController.ensure());
      if (isClosed) return ok;
      if (ok) {
        _loadedAt = null;
        await reload();
        if (toast != null) AppToast.success(toast);
        TaxiDriverDeps.refreshHome();
      }
      return ok;
    } finally {
      if (!isClosed) busy.value = false;
    }
  }

  Future<bool> updateFare(String routeId, int fare) => _write((c) => c.updateFare(routeId, fare), TaxiHubStrings.fareUpdated);

  Future<bool> saveLocalRate(int? rate, int? km) => _write((c) => c.saveLocalRate(dayRate: rate, kmPerDay: km), TaxiHubStrings.localSaved);

  Future<bool> saveRoutes(List<Map<String, dynamic>> routes, String toast) => _write((c) => c.saveRoutes(routes), toast);

  Future<bool> deleteTaxi() async {
    if (deleting.value) return false;
    deleting.value = true;
    try {
      final call = _deleteTaxiCall;
      final r = call != null ? await call() : await OwnerApi.delete('/taxis/me');
      if (isClosed) return false;
      switch (r) {
        case OwnerOk<void>():
          final uid = _uid;
          if (Get.isRegistered<AuthController>()) Get.find<AuthController>().setOwnerShellEmpty(true);
          OwnerCache.removeListingScoped(uid);
          if (Get.isRegistered<TaxiSetupController>()) Get.find<TaxiSetupController>().clear();
          load.value = const OwnerLoadEmpty<TaxiOwnerModel>();
          OwnerSessionHooks.refreshHome().ignore();
          TaxiCalendarController.maybe?.reload();
          if (Get.isRegistered<AuthController>()) await Get.find<AuthController>().refreshProfile();
          AppToast.success(TaxiHubStrings.taxiDeleted);
          return true;
        case OwnerRefused<void>(:final message):
          AppToast.warning(message ?? TaxiHubStrings.noConnection);
        case OwnerOffline<void>():
          AppToast.error(TaxiHubStrings.noConnection);
        case OwnerFailed<void>():
          AppToast.error(TaxiHubStrings.somethingWrong);
      }
      return false;
    } finally {
      if (!isClosed) deleting.value = false;
    }
  }
}
