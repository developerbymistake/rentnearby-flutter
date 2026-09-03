import 'dart:async';
import 'package:get/get.dart';
import '../config/app_tabs.dart';
import '../repositories/config_repository.dart';

/// Single source of truth for the 5 bottom-nav tabs' admin-managed active/rename state
/// (master table — RentNearBy.Core.Entities.AppTab). Put first in MainScreen.initState(), before
/// any tab-scoped controller/hub, so it's the first network call the app fires this session.
///
/// Fail-open by design (mirrors the backend's own fallback): every getter below defaults to
/// "active"/the hardcoded label until (or if) a real response ever arrives, so a slow/failed
/// fetch never hides a real tab — it only ever narrows what's shown once a genuine "IsActive:
/// false" is confirmed from the server.
class TabConfigController extends GetxController {
  final _displayNames = <String, String>{}.obs;
  final _activeKeys = <String>{}.obs;
  final loaded = false.obs;

  // Only Services owns a persistent connection (EnquiryHubService) worth a dedicated Rx —
  // MainScreen watches this one with ever() to connect/disconnect it in lockstep with the tab's
  // live state, on top of what loaded/isActive already give every other caller.
  final servicesActive = true.obs;

  ConfigRepository get _repo => Get.find<ConfigRepository>();

  Future<void> load({bool forceRefresh = false}) async {
    final tabs = await _repo.getAppTabs(forceRefresh: forceRefresh);
    if (tabs.isEmpty) {
      // Network/parse failure with nothing cached yet — leave every default (active) as-is;
      // don't flip `loaded` so awaitLoaded() callers keep waiting for a real answer instead of
      // racing ahead on a guess.
      return;
    }
    for (final t in tabs) {
      _displayNames[t.tabKey] = t.displayName;
      if (t.isActive) {
        _activeKeys.add(t.tabKey);
      } else {
        _activeKeys.remove(t.tabKey);
      }
    }
    servicesActive.value = isActive(AppTabKeys.services);
    loaded.value = true;
  }

  bool isActive(String tabKey) => !_displayNames.containsKey(tabKey) || _activeKeys.contains(tabKey);
  bool isActiveForIndex(int tabIndex) => isActive(AppTabs.tabKeys[tabIndex] ?? '');

  String displayName(String tabKey, String fallback) => _displayNames[tabKey] ?? fallback;
  String displayNameForIndex(int tabIndex, String fallback) =>
      displayName(AppTabs.tabKeys[tabIndex] ?? '', fallback);

  bool get isRoomsActive => isActive(AppTabKeys.rooms);
  bool get isPlotsActive => isActive(AppTabKeys.plots);
  bool get isServicesActive => isActive(AppTabKeys.services);

  /// Waits for the first real response (bounded — a dead/slow network must never hang a caller
  /// forever). Used only by call sites that hit a real backend REST endpoint on first fire
  /// (AgentController.checkAgentStatus, ServiceCatalogController.loadCategories) so a disabled
  /// tab's very first cold-start check never reaches the server at all, not even once — a
  /// stricter guarantee than the fail-open default above, deliberately, because those two calls
  /// cost a real request+403 rather than just a same-process WebSocket open/close.
  Future<void> awaitLoaded() async {
    if (loaded.value) return;
    final completer = Completer<void>();
    late final Worker worker;
    worker = ever<bool>(loaded, (v) {
      if (v && !completer.isCompleted) completer.complete();
    });
    await completer.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    worker.dispose();
  }
}

// String keys matching the backend's master table (RentNearBy.Core.Models.AppTabKeys) — mirrors
// AppTabs.tabKeys' values so callers that only care about a specific vertical (not an int index)
// don't need to thread through AppTabs' int constants at all.
class AppTabKeys {
  static const home = 'HOME';
  static const rooms = 'ROOMS';
  static const plots = 'PLOTS';
  static const services = 'SERVICES';
  static const profile = 'PROFILE';
}
