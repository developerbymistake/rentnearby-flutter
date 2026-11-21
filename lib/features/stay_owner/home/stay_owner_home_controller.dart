// ignore_for_file: prefer_initializing_formals
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../services/notification_service.dart';
import '../../../utils/app_toast.dart';
import '../../owner_core/data/owner_api.dart';
import '../../owner_core/data/owner_cache.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/home/owner_home_api.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../strings/stay_home_strings.dart';

class StayOwnerHomeController extends GetxController with WidgetsBindingObserver {
  static StayOwnerHomeController? get maybe => Get.isRegistered<StayOwnerHomeController>() ? Get.find<StayOwnerHomeController>() : null;

  static const Duration staleAfter = Duration(seconds: 30);

  StayOwnerHomeController({OwnerHomeApi api = const OwnerHomeApi(), Future<bool> Function()? deniedProbe, String? Function()? userId, DateTime Function()? clock})
      : _api = api,
        _deniedProbe = deniedProbe,
        _userId = userId,
        _clock = clock ?? DateTime.now;

  final OwnerHomeApi _api;
  final Future<bool> Function()? _deniedProbe;
  final String? Function()? _userId;
  final DateTime Function() _clock;

  final centreBadge = 0.obs;
  final load = Rx<OwnerLoad<OwnerHomeDto>>(const OwnerLoadLoading());
  final notificationsDenied = false.obs;
  final switchBusy = false.obs;
  final switchOverride = Rxn<bool>();

  final _latest = LatestOnly();
  final _flight = SingleFlight<void>();
  DateTime? _loadedAt;
  Worker? _tabWorker;

  OwnerHomeDto? get data => load.value.valueOrNull;

  String? get _uid => _userId != null ? _userId() : (Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null);

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _readCache();
    if (Get.isRegistered<AuthController>()) {
      _tabWorker = ever<int>(Get.find<AuthController>().tabIndex, (i) {
        if (i == AppTabs.home) refreshIfStale();
      });
    }
    reload();
    checkNotifications();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabWorker?.dispose();
    _latest.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshIfStale();
      checkNotifications();
    }
  }

  void _readCache() {
    final raw = OwnerCache.read(_uid, OwnerCacheKeys.home);
    if (raw == null) return;
    final dto = OwnerHomeDto.fromJson(raw);
    centreBadge.value = dto.numbers.centreBadge;
    load.value = OwnerLoadData<OwnerHomeDto>(dto, stale: true);
  }

  Future<void> checkNotifications() async {
    try {
      final probe = _deniedProbe;
      final denied = probe != null
          ? await probe()
          : (Get.isRegistered<NotificationService>() ? await NotificationService.to.isPermissionDenied() : false);
      if (isClosed) return;
      notificationsDenied.value = denied;
    } catch (_) {}
  }

  Future<void> refreshIfStale() async {
    final at = _loadedAt;
    if (at != null && _clock().difference(at) < staleAfter) return;
    await reload();
  }

  Future<void> reload() => _flight.run(_refresh);

  Future<void> _refresh() async {
    final id = _latest.next();
    final saved = data;
    final OwnerResult<OwnerHomeDto> r;
    try {
      r = await _api.load();
    } catch (_) {
      if (isClosed || !_latest.isLatest(id)) return;
      load.value = saved != null ? OwnerLoadData<OwnerHomeDto>(saved, stale: true) : const OwnerLoadError<OwnerHomeDto>();
      return;
    }
    if (isClosed || !_latest.isLatest(id)) return;
    _loadedAt = _clock();
    switch (r) {
      case OwnerOk<OwnerHomeDto>(:final value):
        load.value = OwnerLoadData<OwnerHomeDto>(value);
        centreBadge.value = value.numbers.centreBadge;
        switchOverride.value = null;
        OwnerCache.write(_uid, OwnerCacheKeys.home, value.raw);
      case OwnerRefused<OwnerHomeDto>(:final statusCode) when statusCode == 429:
        AppToast.info('Too many tries. Wait a minute.');
        load.value = saved != null ? OwnerLoadData<OwnerHomeDto>(saved, stale: true) : const OwnerLoadError<OwnerHomeDto>();
      default:
        load.value = saved != null ? OwnerLoadData<OwnerHomeDto>(saved, stale: true) : OwnerLoads.from<OwnerHomeDto>(r);
    }
  }

  bool get switchOn => switchOverride.value ?? data?.listing.switchOn ?? false;

  Future<void> setAccepting(bool on) async {
    if (switchBusy.value) return;
    switchBusy.value = true;
    switchOverride.value = on;
    try {
      final r = await OwnerApi.put<void>('/stays/me/accepting', {'acceptingGuests': on}, (_) {});
      if (isClosed) return;
      switch (r) {
        case OwnerOk<void>():
          AppToast.success(on ? StayHomeStrings.toastAccepting : StayHomeStrings.toastPaused);
          _loadedAt = null;
          await reload();
        case OwnerRefused<void>(:final type, :final message):
          switchOverride.value = null;
          AppToast.warning(type == 'StayNotApproved' ? StayHomeStrings.notLiveYet : (message ?? StayHomeStrings.notLiveYet));
        case OwnerOffline<void>():
          switchOverride.value = null;
          AppToast.error(StayHomeStrings.noConnection);
        case OwnerFailed<void>(:final message):
          switchOverride.value = null;
          AppToast.error(message);
      }
    } catch (_) {
      if (!isClosed) {
        switchOverride.value = null;
        AppToast.error(StayHomeStrings.noConnection);
      }
    } finally {
      if (!isClosed) switchBusy.value = false;
    }
  }
}
