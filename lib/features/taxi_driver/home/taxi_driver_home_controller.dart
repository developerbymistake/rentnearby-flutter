// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
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
import '../strings/taxi_home_strings.dart';
import 'taxi_attention_copy.dart';

class TaxiDriverHomeController extends GetxController with WidgetsBindingObserver {
  static TaxiDriverHomeController? get maybe => Get.isRegistered<TaxiDriverHomeController>() ? Get.find<TaxiDriverHomeController>() : null;

  static const Duration staleAfter = Duration(seconds: 30);

  TaxiDriverHomeController({
    OwnerHomeApi api = const OwnerHomeApi(),
    Future<bool> Function()? deniedProbe,
    String? Function()? userId,
    DateTime Function()? clock,
    Future<OwnerResult<void>> Function(bool on)? switchCall,
  })  : _api = api,
        _deniedProbe = deniedProbe,
        _userId = userId,
        _clock = clock ?? DateTime.now,
        _switchCall = switchCall;

  final OwnerHomeApi _api;
  final Future<bool> Function()? _deniedProbe;
  final String? Function()? _userId;
  final DateTime Function() _clock;
  final Future<OwnerResult<void>> Function(bool on)? _switchCall;

  final centreBadge = 0.obs;
  final load = Rx<OwnerLoad<OwnerHomeDto>>(const OwnerLoadLoading());
  final notificationsDenied = false.obs;
  final switchBusy = false.obs;
  final switchOverride = Rxn<bool>();
  final now = Rx<DateTime>(DateTime.now());

  final _latest = LatestOnly();
  final _flight = SingleFlight<void>();
  DateTime? _loadedAt;
  Worker? _tabWorker;
  Timer? _ticker;
  bool _tabCurrent = true;

  OwnerHomeDto? get data => load.value.valueOrNull;

  String? get _uid => _userId != null ? _userId() : (Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null);

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _readCache();
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      _tabCurrent = auth.tabIndex.value == AppTabs.home;
      _tabWorker = ever<int>(auth.tabIndex, (i) {
        _tabCurrent = i == AppTabs.home;
        if (_tabCurrent) {
          refreshIfStale();
          _syncTicker();
        } else {
          _stopTicker();
        }
      });
    }
    reload();
    checkNotifications();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabWorker?.dispose();
    _stopTicker();
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
    _syncTicker();
  }

  bool get _hasCountdown {
    final at = _clock();
    return data?.attention.any((a) {
          if (a.code != TaxiAttentionCodes.travellerChoseYou) return false;
          final left = TaxiAttentionCopy.remaining(a, at);
          return left != null && !left.isNegative;
        }) ??
        false;
  }

  void _syncTicker() {
    if (isClosed) return;
    if (!_hasCountdown || !_tabCurrent) {
      _stopTicker();
      return;
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    if (isClosed) return;
    now.value = _clock();
    final expired = data?.attention.any((a) {
          if (a.code != TaxiAttentionCodes.travellerChoseYou) return false;
          final left = TaxiAttentionCopy.remaining(a, now.value);
          return left != null && left.isNegative;
        }) ??
        false;
    if (expired) {
      _stopTicker();
      reload();
    }
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
        now.value = _clock();
        OwnerCache.write(_uid, OwnerCacheKeys.home, value.raw);
      case OwnerRefused<OwnerHomeDto>(:final statusCode) when statusCode == 429:
        AppToast.info(TaxiHomeStrings.tooManyTries);
        load.value = saved != null ? OwnerLoadData<OwnerHomeDto>(saved, stale: true) : const OwnerLoadError<OwnerHomeDto>();
      default:
        load.value = saved != null ? OwnerLoadData<OwnerHomeDto>(saved, stale: true) : OwnerLoads.from<OwnerHomeDto>(r);
    }
    _syncTicker();
  }

  bool get switchOn => switchOverride.value ?? data?.listing.switchOn ?? false;

  Future<OwnerResult<void>> _put(bool on) {
    final o = _switchCall;
    if (o != null) return o(on);
    return OwnerApi.put<void>('/taxis/me/availability', {'isAvailable': on}, (_) {});
  }

  Future<void> setAvailable(bool on) async {
    if (switchBusy.value) return;
    final l = data?.listing;
    if (l != null && l.underReview) {
      AppToast.info(TaxiHomeStrings.underReview);
      return;
    }
    if (l != null && !l.approved) {
      AppToast.info(TaxiHomeStrings.notLiveYet);
      return;
    }
    switchBusy.value = true;
    switchOverride.value = on;
    try {
      final r = await _put(on);
      if (isClosed) return;
      switch (r) {
        case OwnerOk<void>():
          AppToast.success(on ? TaxiHomeStrings.toastAvailable : TaxiHomeStrings.toastHidden);
          _loadedAt = null;
          if (on && notificationsDenied.value) Get.toNamed(AppRoutes.taxiReady);
          await reload();
        case OwnerRefused<void>(:final statusCode, :final message):
          switchOverride.value = null;
          if (statusCode == 429) {
            AppToast.warning(TaxiHomeStrings.tooManyTries);
          } else {
            AppToast.warning(message ?? TaxiHomeStrings.couldNotUpdate);
          }
        case OwnerOffline<void>():
          switchOverride.value = null;
          AppToast.error(TaxiHomeStrings.couldNotUpdate);
        case OwnerFailed<void>():
          switchOverride.value = null;
          AppToast.error(TaxiHomeStrings.couldNotUpdate);
      }
    } catch (_) {
      if (!isClosed) {
        switchOverride.value = null;
        AppToast.error(TaxiHomeStrings.couldNotUpdate);
      }
    } finally {
      if (!isClosed) switchBusy.value = false;
    }
  }
}
