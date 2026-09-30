import 'package:get/get.dart';
import '../config/app_tabs.dart';
import '../models/app_tab_config_model.dart';
import '../repositories/config_repository.dart';

/// Single source of truth for the 4 bottom-nav tabs' admin-managed active/rename state
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
    if (cached != null && cached.isNotEmpty) _applyTabs(cached);
    load();
  }

  Future<void> load({bool forceRefresh = false}) async {
    final tabs = await _repo.getAppTabs(forceRefresh: forceRefresh);
    if (tabs.isEmpty) {
      // Network/parse failure with nothing cached yet — leave every default (active, or
      // whatever onInit()'s persisted-cache seed already applied) as-is; don't flip `loaded`.
      return;
    }
    _applyTabs(tabs);
    loaded.value = true;
  }

  void _applyTabs(List<AppTabConfigModel> tabs) {
    for (final t in tabs) {
      _displayNames[t.tabKey] = t.displayName;
      if (t.isActive) {
        _activeKeys.add(t.tabKey);
      } else {
        _activeKeys.remove(t.tabKey);
      }
    }
  }

  bool isActive(String tabKey) => !_displayNames.containsKey(tabKey) || _activeKeys.contains(tabKey);
  bool isActiveForIndex(int tabIndex) => isActive(AppTabs.tabKeys[tabIndex] ?? '');

  String displayName(String tabKey, String fallback) => _displayNames[tabKey] ?? fallback;
  String displayNameForIndex(int tabIndex, String fallback) =>
      displayName(AppTabs.tabKeys[tabIndex] ?? '', fallback);

  bool get isRoomsActive => isActive(AppTabKeys.rooms);
  bool get isPlotsActive => isActive(AppTabKeys.plots);
}

// String keys matching the backend's master table (RentNearBy.Core.Models.AppTabKeys) — mirrors
// AppTabs.tabKeys' values so callers that only care about a specific vertical (not an int index)
// don't need to thread through AppTabs' int constants at all.
class AppTabKeys {
  static const home = 'HOME';
  static const rooms = 'ROOMS';
  static const plots = 'PLOTS';
  static const profile = 'PROFILE';
}
