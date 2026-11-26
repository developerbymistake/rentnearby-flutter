// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/plan_controller.dart';
import '../../../services/notification_service.dart';
import '../../../utils/app_toast.dart';
import '../../owner_core/data/owner_api.dart';
import '../../owner_core/data/owner_cache.dart';
import '../../owner_core/data/owner_error_types.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/home/owner_home_api.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/json/owner_json.dart';
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
  DateTime _nowPlain = DateTime.now();

  DateTime get nowUntracked => _nowPlain;

  void _setNow(DateTime t) {
    _nowPlain = t;
    now.value = t;
  }

  final _latest = LatestOnly();
  final _flight = SingleFlight<void>();
  DateTime? _loadedAt;
  Worker? _tabWorker;
  Timer? _ticker;
  bool _tabCurrent = true;
  bool _paused = false;

  OwnerHomeDto? get data => load.value.valueOrNull;

  DateTime? get loadedAt => _loadedAt;

  final planChangedAt = Rxn<DateTime>();
  Worker? _planWorker;

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
    if (Get.isRegistered<PlanController>()) {
      _planWorker = ever<int>(Get.find<PlanController>().planVersion, (_) => planChangedAt.value = _clock());
    }
    reload();
    checkNotifications();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabWorker?.dispose();
    _planWorker?.dispose();
    _stopTicker();
    _latest.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _paused = false;
      if (_countdownExpired(_clock())) {
        reload();
      } else {
        _syncTicker();
        refreshIfStale();
      }
      checkNotifications();
    } else if (state == AppLifecycleState.paused) {
      _paused = true;
      _stopTicker();
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
    if (!_hasCountdown || !_tabCurrent || _paused) {
      _stopTicker();
      return;
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  bool _countdownExpired(DateTime at) =>
      data?.attention.any((a) {
        if (a.code != TaxiAttentionCodes.travellerChoseYou) return false;
        final left = TaxiAttentionCopy.remaining(a, at);
        return left != null && left.isNegative;
      }) ??
      false;

  void _tick() {
    if (isClosed) return;
    _setNow(_clock());
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

  Future<void>? _queued;

  Future<void> reload({bool force = false}) {
    if (!force || !_flight.busy) return _flight.run(_refresh);
    return _queued ??= _reloadAfterCurrent();
  }

  Future<void> _reloadAfterCurrent() async {
    try {
      await _flight.run(_refresh);
    } catch (_) {}
    _queued = null;
    if (!isClosed) await _flight.run(_refresh);
  }

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
        _setNow(_clock());
        OwnerCache.write(_uid, OwnerCacheKeys.home, value.raw);
      case OwnerRefused<OwnerHomeDto>(:final type, :final statusCode) when statusCode == 404 && type == OwnerErrorTypes.listingNotFound:
        load.value = const OwnerLoadEmpty<OwnerHomeDto>();
        centreBadge.value = 0;
        switchOverride.value = null;
        OwnerCache.remove(_uid, OwnerCacheKeys.home);
      case OwnerRefused<OwnerHomeDto>(:final statusCode) when statusCode == 429:
        AppToast.info(TaxiHomeStrings.tooManyTries);
        load.value = saved != null ? OwnerLoadData<OwnerHomeDto>(saved, stale: true) : const OwnerLoadError<OwnerHomeDto>();
      default:
        load.value = saved != null ? OwnerLoadData<OwnerHomeDto>(saved, stale: true) : OwnerLoads.from<OwnerHomeDto>(r);
    }
    _syncTicker();
  }

  bool get switchOn => switchOverride.value ?? data?.listing.switchOn ?? false;

  void patchAvailability(Map<String, dynamic> counts) {
    final current = load.value;
    if (isClosed || current is! OwnerLoadData<OwnerHomeDto>) return;
    final raw = Map<String, dynamic>.from(current.value.raw);
    final numbers = Map<String, dynamic>.from(OwnerJson.map(raw['numbers']));
    final taxi = Map<String, dynamic>.from(OwnerJson.map(numbers['taxi']));
    taxi['availability'] = Map<String, dynamic>.from(counts);
    numbers['taxi'] = taxi;
    raw['numbers'] = numbers;
    load.value = OwnerLoadData<OwnerHomeDto>(OwnerHomeDto.fromJson(raw), stale: current.stale);
    OwnerCache.write(_uid, OwnerCacheKeys.home, raw);
  }

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
