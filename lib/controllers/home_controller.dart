import 'package:get/get.dart';
import '../features/taxi/models/taxi_browse_item.dart';
import '../models/home_feed_model.dart';
import '../repositories/home_repository.dart';
import 'location_controller.dart';
import 'tab_config_controller.dart';

export '../models/home_feed_model.dart';

/// Home tab's data source: one GET /home/feed per load, limited to the sections of active tabs.
class HomeController extends GetxController {
  final stays = <HomeStayModel>[].obs;
  final taxis = <TaxiBrowseItem>[].obs;

  final recentlyAddedStays = <HomeStayModel>[].obs;

  final staysLoading = true.obs;
  final taxisLoading = true.obs;
  final recentlyAddedStaysLoading = true.obs;
  final failedSections = <String>{}.obs;

  static const _allSections = {
    HomeSectionKeys.stays,
    HomeSectionKeys.taxis,
    HomeSectionKeys.recentStays,
  };

  final _repo = const HomeRepository();
  final _gen = <String, int>{};
  final _workers = <Worker>[];
  late final LocationController _loc;
  late final TabConfigController _tabs;
  late Set<String> _sections;
  String? _loadedDistrictId;

  @override
  void onInit() {
    super.onInit();
    _loc = Get.find<LocationController>();
    _tabs = Get.find<TabConfigController>();
    _sections = _activeSections();

    _workers.add(everAll([_loc.selectedDistrict, _loc.browsingDistrict], (_) {
      final district = _loc.effectiveDistrict;
      if (district != null) loadHomeData(district.id);
    }));

    _workers.add(ever(_tabs.version, (_) => _onTabsChanged()));

    final current = _loc.effectiveDistrict;
    if (current != null) loadHomeData(current.id);
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  Set<String> _activeSections() => _tabs.activeSectionKeys.where(_allSections.contains).toSet();

  void _onTabsChanged() {
    final now = _activeSections();
    final turnedOn = now.difference(_sections);
    final turnedOff = _sections.difference(now);
    _sections = now;
    if (turnedOff.isNotEmpty) clearSections(turnedOff);
    if (turnedOn.isNotEmpty) reloadSections(turnedOn);
  }

  List<HomeRecentItem> recentMixed({
    bool stays = true,
    int count = 6,
  }) {
    final all = <HomeRecentItem>[
      if (stays) ...recentlyAddedStays.map(HomeRecentItem.stay),
    ];
    all.sort((a, b) {
      final x = a.createdAt, y = b.createdAt;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });
    return all.take(count).toList();
  }

  Future<void> loadHomeData(String districtId) async {
    if (_loadedDistrictId == districtId) return;
    _loadedDistrictId = districtId;
    final active = _activeSections();
    clearSections(_allSections.difference(active));
    final ok = await _fetch(districtId, active);
    if (!ok && _loadedDistrictId == districtId) _loadedDistrictId = null;
  }

  /// Fetches only [keys] that are active, ignoring the per-district memo.
  Future<void> reloadSections(Set<String> keys) async {
    final district = _loc.effectiveDistrict;
    if (district == null) return;
    await _fetch(district.id, keys.intersection(_activeSections()));
  }

  void clearSections(Set<String> keys) {
    failedSections.removeAll(keys);
    for (final k in keys) {
      _gen[k] = (_gen[k] ?? 0) + 1;
      switch (k) {
        case HomeSectionKeys.stays:
          stays.clear();
        case HomeSectionKeys.taxis:
          taxis.clear();
        case HomeSectionKeys.recentStays:
          recentlyAddedStays.clear();
      }
      _loadingOf(k)?.value = false;
    }
  }

  /// Pull-to-refresh. (Not named refresh: GetxController.refresh() is synchronous.)
  Future<void> reloadDistrict() async {
    final district = _loc.effectiveDistrict;
    if (district == null) return;
    _loadedDistrictId = district.id;
    await _fetch(district.id, _activeSections());
  }

  Future<bool> _fetch(String districtId, Set<String> keys) async {
    if (keys.isEmpty) return true;
    final tickets = <String, int>{};
    for (final k in keys) {
      tickets[k] = _gen[k] = (_gen[k] ?? 0) + 1;
      _loadingOf(k)?.value = true;
    }
    failedSections.removeAll(keys);
    bool current(String k) => _gen[k] == tickets[k];
    try {
      final feed = await _repo.fetchFeed(districtId: districtId, sections: keys);
      for (final k in keys) {
        if (current(k)) _apply(k, feed);
      }
      if (keys.any(feed.isSectionTabOff)) _tabs.load(forceRefresh: true);
      return true;
    } catch (_) {
      failedSections.addAll(keys.where(current));
      return false;
    } finally {
      for (final k in keys) {
        if (current(k)) _loadingOf(k)?.value = false;
      }
    }
  }

  void _apply(String key, HomeFeedModel feed) {
    failedSections.remove(key);
    switch (key) {
      case HomeSectionKeys.stays:
        stays.assignAll(feed.stays ?? const []);
      case HomeSectionKeys.taxis:
        taxis.assignAll(feed.taxis ?? const []);
      case HomeSectionKeys.recentStays:
        recentlyAddedStays.assignAll(feed.recentStays ?? const []);
    }
  }

  RxBool? _loadingOf(String key) => switch (key) {
        HomeSectionKeys.stays => staysLoading,
        HomeSectionKeys.taxis => taxisLoading,
        HomeSectionKeys.recentStays => recentlyAddedStaysLoading,
        _ => null,
      };
}
