import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_constants.dart';
import '../config/app_routes.dart';
import '../config/app_tour_state.dart';
import '../config/tour_registry.dart';
import '../models/app_version_config_model.dart';
import '../navigation/tab_keys.dart';
import '../repositories/app_version_repository.dart';
import '../services/storage_service.dart';
import '../utils/app_toast.dart';
import '../utils/dio_error_mapper.dart';
import '../utils/rx_safe_call.dart';
import '../utils/update_decision.dart';
import 'auth_controller.dart';
import 'banner_controller.dart';
import 'location_controller.dart';
import 'tour_controller.dart';

enum UpdateCheckReason { launch, resume, connectivity, manual }

/// Result the soft-update dialog pops with. Barrier/back pops null (= later).
enum SoftUpdateChoice { update, later }

enum _CheckStatus { success, offline, failed, throttled, unsupported }

class _CheckOutcome {
  final _CheckStatus status;
  final Object? error;
  const _CheckOutcome(this.status, [this.error]);
}

class AppVersionController extends GetxController with WidgetsBindingObserver {
  AppVersionController({
    required this.installedBuild,
    required this.installedVersionName,
    AppVersionRepository? repository,
  }) : _repo = repository ?? AppVersionRepository();

  static AppVersionController get to => Get.find<AppVersionController>();

  final int installedBuild;
  final String installedVersionName;
  final AppVersionRepository _repo;

  final config = Rxn<AppVersionConfigModel>();
  final gate = UpdateGateState.none.obs;
  final isChecking = false.obs;
  final softDialogOpen = false.obs;

  /// Set by the UI layer; the soft prompt is never shown while null.
  WidgetBuilder? softDialogBuilder;

  /// The launch check; never completes with an error.
  late final Future<void> initialCheck;

  Future<_CheckOutcome>? _inFlight;
  DateTime? _lastSuccessAt;
  int? _softPromptedForBuild;
  bool _wasOffline = false;
  bool _openingStore = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Worker? _gateWorker;
  DialogRoute<SoftUpdateChoice>? _softRoute;
  bool _softRouteClosedBySystem = false;

  /// 'android' | 'ios', or null where the gate does not apply (web, desktop).
  static String? get currentPlatform {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return null;
    }
  }

  static bool get isSupportedPlatform => currentPlatform != null;

  /// Never throws; build 0 means unknown and never gates.
  static Future<({int build, String name})> readInstalledVersion() async {
    if (!isSupportedPlatform) return (build: 0, name: '');
    try {
      final info = await PackageInfo.fromPlatform().timeout(const Duration(seconds: 2));
      return (build: int.tryParse(info.buildNumber.trim()) ?? 0, name: info.version);
    } catch (_) {
      return (build: 0, name: '');
    }
  }

  bool get isForced => gate.value == UpdateGateState.force;

  @override
  void onInit() {
    super.onInit();
    config.value = _readCachedConfig();
    _refreshGate();
    WidgetsBinding.instance.addObserver(this);
    _gateWorker = ever<UpdateGateState>(gate, rxSafe('appVersion.gate', _onGateChanged));
    if (isSupportedPlatform) {
      _connectivitySub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged, onError: (_) {});
    }
    initialCheck = check(reason: UpdateCheckReason.launch);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _gateWorker?.dispose();
    _connectivitySub?.cancel();
    _closeSoftDialog();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(check(reason: UpdateCheckReason.resume));
  }

  @override
  Future<bool> didPopRoute() async {
    if (!isForced) return false;
    await SystemNavigator.pop();
    return true;
  }

  /// Single-flight, throttled for resume/connectivity, never completes with an error.
  /// Only [UpdateCheckReason.manual] surfaces toasts.
  Future<void> check({UpdateCheckReason reason = UpdateCheckReason.manual}) async {
    try {
      final outcome = await _joinOrStart(reason);
      if (reason == UpdateCheckReason.manual) _reportManual(outcome);
    } catch (_) {}
  }

  Future<_CheckOutcome> _joinOrStart(UpdateCheckReason reason) {
    final existing = _inFlight;
    if (existing != null) return existing;
    if (!isSupportedPlatform) return Future.value(const _CheckOutcome(_CheckStatus.unsupported));
    final throttleable = reason == UpdateCheckReason.resume || reason == UpdateCheckReason.connectivity;
    final last = _lastSuccessAt;
    if (throttleable && last != null && DateTime.now().difference(last).abs() < AppConstants.appVersionRecheckThrottle) {
      _refreshGate();
      return Future.value(const _CheckOutcome(_CheckStatus.throttled));
    }
    final flight = _performCheck();
    _inFlight = flight;
    return flight;
  }

  Future<_CheckOutcome> _performCheck() async {
    isChecking.value = true;
    try {
      if (await _isOffline()) {
        _wasOffline = true;
        _refreshGate();
        return const _CheckOutcome(_CheckStatus.offline);
      }
      final cfg = await _repo.fetch(platform: currentPlatform!, installedBuild: installedBuild);
      _applyConfig(cfg);
      return const _CheckOutcome(_CheckStatus.success);
    } catch (e) {
      if (AppVersionRepository.isNoConfigResponse(e)) {
        _applyNoConfig();
        return const _CheckOutcome(_CheckStatus.success);
      }
      _refreshGate();
      return _CheckOutcome(_CheckStatus.failed, e);
    } finally {
      _inFlight = null;
      isChecking.value = false;
    }
  }

  Future<bool> _isOffline() async {
    try {
      final results = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 2), onTimeout: () => const [ConnectivityResult.wifi]);
      return results.isNotEmpty && results.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  void _applyConfig(AppVersionConfigModel cfg) {
    _lastSuccessAt = DateTime.now();
    config.value = cfg;
    StorageService.saveAppVersionConfig(cfg.toJson());
    _refreshGate();
    if (gate.value == UpdateGateState.soft) {
      maybeShowSoftPrompt();
    } else {
      StorageService.clearSoftUpdateSnooze();
    }
  }

  void _applyNoConfig() {
    _lastSuccessAt = DateTime.now();
    config.value = null;
    StorageService.clearAppVersionConfig();
    StorageService.clearSoftUpdateSnooze();
    _refreshGate();
  }

  void _refreshGate() {
    gate.value = isSupportedPlatform
        ? UpdateDecision.evaluate(installedBuild, config.value, now: DateTime.now())
        : UpdateGateState.none;
  }

  AppVersionConfigModel? _readCachedConfig() {
    final raw = StorageService.getAppVersionConfig();
    if (raw == null) return null;
    try {
      return AppVersionConfigModel.fromJson(raw);
    } catch (_) {
      StorageService.clearAppVersionConfig();
      return null;
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline = results.isNotEmpty && results.every((r) => r == ConnectivityResult.none);
    final restored = _wasOffline && !offline;
    _wasOffline = offline;
    if (restored) unawaited(check(reason: UpdateCheckReason.connectivity));
  }

  void _onGateChanged(UpdateGateState state) {
    if (state != UpdateGateState.soft) _closeSoftDialog();
    if (state == UpdateGateState.force) FocusManager.instance.primaryFocus?.unfocus();
  }

  void _reportManual(_CheckOutcome outcome) {
    switch (outcome.status) {
      case _CheckStatus.offline:
        AppToast.error('No internet connection');
      case _CheckStatus.failed:
        AppToast.error(DioErrorMapper.toMessage(outcome.error, 'Could not check for updates'));
      case _CheckStatus.success:
        if (isForced) AppToast.warning('This version is no longer supported. Please update to continue.');
      case _CheckStatus.throttled:
      case _CheckStatus.unsupported:
        break;
    }
  }

  // ── Soft update prompt ─────────────────────────────────────────────────────

  /// Idempotent; shows the soft dialog only when every precondition holds,
  /// otherwise defers to the next check success / MainScreen ready.
  void maybeShowSoftPrompt() {
    try {
      final cfg = config.value;
      final builder = softDialogBuilder;
      if (cfg == null || builder == null || !_canShowSoftPrompt(cfg)) return;
      unawaited(_showSoftPrompt(cfg, builder));
    } catch (_) {}
  }

  bool _canShowSoftPrompt(AppVersionConfigModel cfg) {
    if (gate.value != UpdateGateState.soft || softDialogOpen.value) return false;
    if (_softPromptedForBuild == cfg.latestBuild) return false;
    final snooze = SoftSnooze.tryParse(StorageService.getSoftUpdateSnooze());
    if (!SoftPromptPolicy.shouldPrompt(snooze, cfg.latestBuild, DateTime.now())) return false;

    if (Get.currentRoute != AppRoutes.main) return false;
    if (!Get.isRegistered<TourController>() || !Get.isRegistered<LocationController>()) return false;
    if (Get.find<LocationController>().hasActiveGate) return false;
    if (tourInProgress.value) return false;
    final tabIndex = Get.find<AuthController>().tabIndex.value;
    final tour = tourRegistry[tabIndex];
    if (tour != null && !StorageService.getTourSeen(tour.storageKey)) return false;
    if (Get.isRegistered<BannerController>() && Get.find<BannerController>().activeBanner.value != null) {
      return false;
    }
    if (tabIndex >= 0 && tabIndex < tabKeys.length && (tabKeys[tabIndex].currentState?.canPop() ?? false)) {
      return false;
    }
    return _topRootRouteName() == AppRoutes.main;
  }

  String? _topRootRouteName() {
    final nav = Get.key.currentState;
    if (nav == null) return null;
    Route<dynamic>? top;
    nav.popUntil((route) {
      top = route;
      return true;
    });
    final route = top;
    if (route == null) return null;
    return route.settings.name ?? (route is GetPageRoute ? route.routeName : null);
  }

  Future<void> _showSoftPrompt(AppVersionConfigModel cfg, WidgetBuilder builder) async {
    final nav = Get.key.currentState;
    final navContext = Get.key.currentContext;
    if (nav == null || navContext == null) return;

    _softPromptedForBuild = cfg.latestBuild;
    _softRouteClosedBySystem = false;
    final route = DialogRoute<SoftUpdateChoice>(
      context: navContext,
      builder: builder,
      barrierDismissible: true,
    );
    _softRoute = route;
    softDialogOpen.value = true;

    SoftUpdateChoice? choice;
    try {
      choice = await nav.push<SoftUpdateChoice>(route);
    } catch (_) {
      choice = null;
    } finally {
      _softRoute = null;
      softDialogOpen.value = false;
    }

    if (_softRouteClosedBySystem) return;
    final now = DateTime.now();
    final prev = SoftSnooze.tryParse(StorageService.getSoftUpdateSnooze());
    if (choice == SoftUpdateChoice.update) {
      StorageService.saveSoftUpdateSnooze(SoftPromptPolicy.afterStoreOpened(prev, cfg.latestBuild, now).toJson());
      await openStore();
    } else if (Get.currentRoute == AppRoutes.main) {
      StorageService.saveSoftUpdateSnooze(SoftPromptPolicy.nextSnooze(prev, cfg.latestBuild, now).toJson());
    }
  }

  void _closeSoftDialog() {
    final route = _softRoute;
    if (route == null) return;
    _softRouteClosedBySystem = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = route.navigator;
      if (nav != null && route.isActive) nav.removeRoute(route);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  // ── Store launch ───────────────────────────────────────────────────────────

  /// market:// -> server storeUrl (host allow-listed) -> constant Play URL -> toast.
  Future<void> openStore() async {
    final platform = currentPlatform;
    if (platform == null || _openingStore) return;
    _openingStore = true;
    try {
      final serverUrl = _allowedStoreUri(config.value?.storeUrl, platform);
      if (platform == 'android') {
        if (await _launch(Uri.parse(AppConstants.playStoreMarketUrl))) return;
        if (serverUrl != null && await _launch(serverUrl)) return;
        if (await _launch(Uri.parse(AppConstants.playStoreUrl))) return;
        AppToast.error('Could not open Play Store');
      } else {
        if (serverUrl != null && await _launch(serverUrl)) return;
        AppToast.info('Please update Bakhli from the App Store');
      }
    } finally {
      _openingStore = false;
    }
  }

  static Uri? _allowedStoreUri(String? url, String platform) {
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return null;
    final host = platform == 'android' ? AppConstants.playStoreHost : AppConstants.appStoreHost;
    return uri.host.toLowerCase() == host ? uri : null;
  }

  static Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
