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
import '../../owner_core/sheets/owner_states.dart';
import '../../stay/models/stay_owner_model.dart';
import '../../stay/setup/stay_setup_controller.dart';
import '../stay_owner_deps.dart';
import '../strings/stay_hub_strings.dart';

class StayHubController extends GetxController with WidgetsBindingObserver {
  static const String tag = 'stay-hub';
  static const Duration staleAfter = Duration(seconds: 30);

  static StayHubController? get maybe => Get.isRegistered<StayHubController>(tag: tag) ? Get.find<StayHubController>(tag: tag) : null;

  StayHubController({String? Function()? userId, DateTime Function()? clock, Future<Map<String, dynamic>> Function()? fetch})
      : _userId = userId,
        _clock = clock ?? DateTime.now,
        _fetchOverride = fetch;

  final String? Function()? _userId;
  final DateTime Function() _clock;
  final Future<Map<String, dynamic>> Function()? _fetchOverride;

  final load = Rx<OwnerLoad<StayOwnerModel>>(const OwnerLoadLoading());
  final paused = false.obs;
  final staleNotice = false.obs;
  final priceBusy = false.obs;
  final deleting = false.obs;
  final scrollTarget = Rxn<String>();

  final _latest = LatestOnly();
  final _flight = SingleFlight<void>();
  DateTime? _loadedAt;
  Worker? _tabWorker;
  Worker? _intentWorker;

  static const Duration resultWindow = Duration(days: 7);

  StayOwnerModel? get stay => load.value.valueOrNull;

  DateTime now() => _clock();

  String? get _uid => _userId != null ? _userId() : (Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null);

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    final raw = OwnerCache.read(_uid, OwnerCacheKeys.listing);
    if (raw != null) {
      final m = StayOwnerModel.fromJson(raw);
      if (m.id.isNotEmpty) load.value = OwnerLoadData<StayOwnerModel>(m, stale: true);
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

  Future<void> reload() => _flight.run(_reload);

  Future<OwnerResult<Map<String, dynamic>>> _fetch() => OwnerApi.run(() => OwnerApi.read(() async {
        final o = _fetchOverride;
        final res = o != null ? await o() : await OwnerApi.transport.get('/stays/me', null);
        return OwnerJson.map(res['data']);
      }));

  Future<void> _reload() async {
    final id = _latest.next();
    final saved = stay;
    final r = await _fetch();
    if (isClosed || !_latest.isLatest(id)) return;
    _loadedAt = _clock();
    switch (r) {
      case OwnerOk<Map<String, dynamic>>(:final value):
        paused.value = false;
        staleNotice.value = false;
        if (value['id'] == null || OwnerJson.str(value['id']).isEmpty) {
          load.value = const OwnerLoadEmpty<StayOwnerModel>();
          OwnerCache.remove(_uid, OwnerCacheKeys.listing);
          if (Get.isRegistered<StaySetupController>()) Get.find<StaySetupController>().stay.value = null;
          return;
        }
        final m = StayOwnerModel.fromJson(value);
        load.value = OwnerLoadData<StayOwnerModel>(m);
        OwnerCache.write(_uid, OwnerCacheKeys.listing, value);
        StaySetupController.ensure().stay.value = m;
      case OwnerRefused<Map<String, dynamic>>(:final type, :final statusCode) when statusCode == 403 && type == 'TabInactive':
        paused.value = true;
        if (saved == null) load.value = const OwnerLoadPaused<StayOwnerModel>(null);
      case OwnerRefused<Map<String, dynamic>>(:final statusCode) when statusCode == 429:
        AppToast.info('Too many tries. Wait a minute.');
        _keepOrError(saved);
      default:
        _keepOrError(saved);
    }
  }

  void _keepOrError(StayOwnerModel? saved) {
    if (saved != null) {
      staleNotice.value = true;
      load.value = OwnerLoadData<StayOwnerModel>(saved, stale: true);
    } else {
      load.value = const OwnerLoadError<StayOwnerModel>();
    }
  }

  Future<bool> updatePrice(String roomId, int price) async {
    if (priceBusy.value) return false;
    priceBusy.value = true;
    try {
      final r = await OwnerApi.put<Map<String, dynamic>>('/stays/me/rooms/$roomId/price', {'pricePerNight': price}, (d) => d);
      if (isClosed) return false;
      switch (r) {
        case OwnerOk<Map<String, dynamic>>(:final value):
          final merged = StayOwnerModel.mergeJson(stay?.raw, value);
          final m = StayOwnerModel.fromJson(merged);
          if (m.id.isNotEmpty) {
            load.value = OwnerLoadData<StayOwnerModel>(m);
            OwnerCache.write(_uid, OwnerCacheKeys.listing, merged);
            StaySetupController.ensure().stay.value = m;
          } else {
            await reload();
          }
          AppToast.success(StayHubStrings.priceUpdated);
          StayOwnerDeps.refreshHome();
          return true;
        case OwnerRefused<Map<String, dynamic>>(:final message):
          AppToast.warning(message ?? StayHubStrings.noConnection);
        case OwnerOffline<Map<String, dynamic>>():
          AppToast.error(StayHubStrings.noConnection);
        case OwnerFailed<Map<String, dynamic>>():
          AppToast.error(StayHubStrings.somethingWrong);
      }
      return false;
    } finally {
      if (!isClosed) priceBusy.value = false;
    }
  }

  Future<bool> deleteStay() async {
    if (deleting.value) return false;
    deleting.value = true;
    try {
      final r = await OwnerApi.delete('/stays/me');
      if (isClosed) return false;
      switch (r) {
        case OwnerOk<void>():
          final uid = _uid;
          if (Get.isRegistered<AuthController>()) Get.find<AuthController>().setOwnerShellEmpty(true);
          OwnerCache.removeListingScoped(uid);
          if (Get.isRegistered<StaySetupController>()) Get.find<StaySetupController>().clear();
          load.value = const OwnerLoadEmpty<StayOwnerModel>();
          StayOwnerDeps.afterStayDeleted();
          if (Get.isRegistered<AuthController>()) await Get.find<AuthController>().refreshProfile();
          AppToast.success(StayHubStrings.stayDeleted);
          return true;
        case OwnerRefused<void>(:final message):
          AppToast.warning(message ?? StayHubStrings.noConnection);
        case OwnerOffline<void>():
          AppToast.error(StayHubStrings.noConnection);
        case OwnerFailed<void>():
          AppToast.error(StayHubStrings.somethingWrong);
      }
      return false;
    } finally {
      if (!isClosed) deleting.value = false;
    }
  }
}
