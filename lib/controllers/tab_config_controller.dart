import 'dart:async';
import 'package:get/get.dart';
import '../config/app_tabs.dart';
import '../models/app_tab_config_model.dart';
import '../repositories/config_repository.dart';

/// Single source of truth for the 7 bottom-nav tabs' admin-managed active/rename state
/// (master table — RentNearBy.Core.Entities.AppTab). Put permanently in main() before
/// AuthController, so every routing decision (splash, postLoginRoute, deep links, pushes)
/// already sees the tab state.
///
/// Fail-open by design (mirrors the backend's own fallback): every getter below defaults to
/// "active"/the hardcoded label until (or if) a real response ever arrives, so a slow/failed
/// fetch never hides a real tab — it only ever narrows what's shown once a genuine "IsActive:
/// false" is confirmed from the server.
class TabConfigController extends GetxController {
  static TabConfigController get to => Get.find<TabConfigController>();

  final _displayNames = <String, String>{};
  final _activeKeys = <String>{};
  final loaded = false.obs;
  final version = 0.obs;

  final _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  Future<void>? _inFlight;
  DateTime? _lastForcedAt;
  static const _forceDebounce = Duration(seconds: 3);

  ConfigRepository get _repo => Get.find<ConfigRepository>();

  @override
  void onInit() {
    super.onInit();
    // Seed synchronously from the last-known-good persisted config, before the first frame
    // ever builds — without this, a process relaunch that Android/Flutter reports as a plain
    // "resume" (very common: the OS kills a backgrounded app for memory, then relaunches it,
    // indistinguishable from a warm resume at the Dart level) would restart with every tab
    // fail-open/active for the brief window before load()'s network response lands, visibly
    // flashing a genuinely-deactivated tab before it disappears. This does NOT set `loaded` —
    // it's a best-guess seed, not a confirmed answer.
    final cached = _repo.getPersistedAppTabs();
    if (cached != null && cached.isNotEmpty) {
      _applyTabs(cached);
      _completeReady();
    }
    load();
  }

  Future<void> load({bool forceRefresh = false}) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final last = _lastForcedAt;
    if (forceRefresh && last != null && DateTime.now().difference(last) < _forceDebounce) {
      return Future.value();
    }
    if (forceRefresh) _lastForcedAt = DateTime.now();
    return _inFlight = _load(forceRefresh).whenComplete(() => _inFlight = null);
  }

  Future<void> _load(bool forceRefresh) async {
    try {
      final tabs = await _repo.getAppTabs(forceRefresh: forceRefresh);
      if (tabs.isEmpty) return;
      _applyTabs(tabs);
      loaded.value = true;
    } finally {
      _completeReady();
    }
  }

  void _completeReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void _applyTabs(List<AppTabConfigModel> tabs) {
    var changed = false;
    for (final t in tabs) {
      if (_displayNames[t.tabKey] != t.displayName) {
        _displayNames[t.tabKey] = t.displayName;
        changed = true;
      }
      if (t.isActive ? _activeKeys.add(t.tabKey) : _activeKeys.remove(t.tabKey)) changed = true;
    }
    if (changed) version.value++;
  }

  // Reading `version` subscribes any enclosing Obx to real changes only.
  bool isActive(String tabKey) {
    version.value;
    return !_displayNames.containsKey(tabKey) || _activeKeys.contains(tabKey);
  }

  // Jobs are a Stays sub-feature, so the Jobs tab also needs STAYS (same as the /stay-jobs gate).
  bool isActiveForIndex(int tabIndex) => tabIndex == AppTabs.jobs
      ? isJobsActive && isStaysActive
      : isActive(AppTabs.tabKeys[tabIndex] ?? '');

  String displayName(String tabKey, String fallback) {
    version.value;
    return _displayNames[tabKey] ?? fallback;
  }
  String displayNameForIndex(int tabIndex, String fallback) =>
      displayName(AppTabs.tabKeys[tabIndex] ?? '', fallback);

  bool get isRoomsActive => isActive(AppTabKeys.rooms);
  bool get isPlotsActive => isActive(AppTabKeys.plots);
  bool get isStaysActive => isActive(AppTabKeys.stays);
  bool get isTaxiActive => isActive(AppTabKeys.taxi);
  bool get isJobsActive => isActive(AppTabKeys.jobs);

  List<String> get activeSectionKeys => [
        if (isRoomsActive) HomeSectionKeys.rooms,
        if (isPlotsActive) HomeSectionKeys.plots,
        if (isStaysActive) HomeSectionKeys.stays,
        if (isTaxiActive) HomeSectionKeys.taxis,
        if (isRoomsActive) HomeSectionKeys.recentRooms,
        if (isPlotsActive) HomeSectionKeys.recentPlots,
        if (isStaysActive) HomeSectionKeys.recentStays,
      ];
}

// String keys matching the backend's master table (RentNearBy.Core.Models.AppTabKeys) — mirrors
// AppTabs.tabKeys' values so callers that only care about a specific vertical (not an int index)
// don't need to thread through AppTabs' int constants at all.
class AppTabKeys {
  static const home = 'HOME';
  static const rooms = 'ROOMS';
  static const plots = 'PLOTS';
  static const stays = 'STAYS';
  static const jobs = 'JOBS';
  static const taxi = 'TAXI';
  static const profile = 'PROFILE';
}

// `sections` values of GET /home/feed.
class HomeSectionKeys {
  static const rooms = 'rooms';
  static const plots = 'plots';
  static const stays = 'stays';
  static const taxis = 'taxis';
  static const recentRooms = 'recentRooms';
  static const recentPlots = 'recentPlots';
  static const recentStays = 'recentStays';
}
