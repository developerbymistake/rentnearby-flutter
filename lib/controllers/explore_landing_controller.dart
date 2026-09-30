import 'package:get/get.dart';
import '../config/app_tabs.dart';
import '../models/browse_item.dart';
import '../models/explore_kind.dart';
import '../repositories/explore_browse_repository.dart';
import 'auth_controller.dart';
import 'listing_controller.dart';
import 'location_controller.dart';
import 'plot_controller.dart';

class ExploreLandingController extends GetxController {
  ExploreLandingController(this.kind);

  final ExploreKind kind;

  static const _pageSize = 20;
  static const _staleAfter = Duration(minutes: 2);

  final items = <BrowseItem>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasMore = false.obs;
  final loadFailed = false.obs;
  final loadMoreFailed = false.obs;
  final selectedTypeId = Rxn<String>();
  final sortBy = 'newest'.obs;
  final resetGeneration = 0.obs;

  final _repo = ExploreBrowseRepository();
  final _workers = <Worker>[];
  String? _cursor;
  int _page = 1;
  int _gen = 0;
  DateTime? _loadedAt;
  String? _loadedLocationKey;
  bool _dirty = false;
  bool _resetInFlight = false;
  bool _locationCheckQueued = false;

  bool get isRooms => kind == ExploreKind.rooms;
  int get _tab => isRooms ? AppTabs.rooms : AppTabs.plots;
  bool get _tabActive => Get.find<AuthController>().tabIndex.value == _tab;

  String get _locationKey {
    final loc = Get.find<LocationController>();
    return '${loc.effectiveDistrict?.id}|${loc.effectiveCity?.id}';
  }

  @override
  void onInit() {
    super.onInit();
    final loc = Get.find<LocationController>();
    _workers.add(everAll(
      [loc.selectedDistrict, loc.browsingDistrict, loc.browsingCity, loc.autoCity],
      (_) => _queueLocationCheck(),
    ));
    _workers.add(ever(Get.find<AuthController>().tabIndex, (i) {
      if (i == _tab) refreshIfNeeded();
    }));
    if (isRooms) {
      final c = Get.find<ListingController>();
      _workers.add(everAll([c.listingPostedTrigger, c.listingStatusChangedTrigger], (_) => _markDirty()));
      _workers.add(ever(c.filterResetTrigger, (_) => _clearType()));
    } else {
      final c = Get.find<PlotController>();
      _workers.add(everAll([c.plotPostedTrigger, c.listingStatusChangedTrigger], (_) => _markDirty()));
      _workers.add(ever(c.filterResetTrigger, (_) => _clearType()));
    }
    if (_tabActive) refreshIfNeeded();
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  void _queueLocationCheck() {
    if (_locationCheckQueued) return;
    _locationCheckQueued = true;
    Future.microtask(() {
      _locationCheckQueued = false;
      if (isClosed || _locationKey == _loadedLocationKey) return;
      _invalidateHard();
      if (_tabActive) refreshIfNeeded();
    });
  }

  void _markDirty() {
    _dirty = true;
    if (_tabActive) refreshIfNeeded();
  }

  void _clearType() {
    if (selectedTypeId.value == null) return;
    selectedTypeId.value = null;
    resetGeneration.value++;
    _invalidateHard();
    if (_tabActive) refreshIfNeeded();
  }

  void _invalidateHard() {
    _gen++;
    _resetInFlight = false;
    _loadedAt = null;
    _loadedLocationKey = null;
    _cursor = null;
    hasMore.value = false;
    loadFailed.value = false;
    loadMoreFailed.value = false;
    isLoadingMore.value = false;
    isLoading.value = true;
    items.clear();
  }

  void refreshIfNeeded() {
    if (_resetInFlight && !_dirty) return;
    final at = _loadedAt;
    final stale = at == null || DateTime.now().difference(at) > _staleAfter;
    if (!_dirty && !stale) return;
    _fetch(reset: true, silent: items.isNotEmpty);
  }

  Future<void> pullRefresh() => _fetch(reset: true, silent: true);

  void retry() => _fetch(reset: true);

  void retryLoadMore() => _fetch(reset: false);

  void loadNextPage() {
    if (!hasMore.value || isLoading.value || isLoadingMore.value || loadMoreFailed.value || _resetInFlight) return;
    _fetch(reset: false);
  }

  void setType(String? typeId) {
    if (selectedTypeId.value == typeId) return;
    selectedTypeId.value = typeId;
    _reloadFresh();
  }

  void applyFilters({String? typeId, required String sort}) {
    if (selectedTypeId.value == typeId && sortBy.value == sort) return;
    selectedTypeId.value = typeId;
    sortBy.value = sort;
    _reloadFresh();
  }

  void _reloadFresh() {
    _invalidateHard();
    _fetch(reset: true);
  }

  Future<void> _fetch({required bool reset, bool silent = false}) async {
    final loc = Get.find<LocationController>();
    final districtId = loc.effectiveDistrict?.id;
    if (districtId == null) {
      _gen++;
      _resetInFlight = false;
      isLoading.value = false;
      isLoadingMore.value = false;
      return;
    }

    final keyset = sortBy.value == 'newest';
    if (!reset && keyset && _cursor == null) {
      hasMore.value = false;
      return;
    }

    final myGen = ++_gen;
    if (reset) {
      _resetInFlight = true;
      _dirty = false;
      _loadedLocationKey = _locationKey;
      loadFailed.value = false;
      loadMoreFailed.value = false;
      isLoadingMore.value = false;
      if (!silent || items.isEmpty) isLoading.value = true;
    } else {
      isLoadingMore.value = true;
      loadMoreFailed.value = false;
    }

    try {
      final res = await _repo.fetch(
        kind,
        districtId: districtId,
        cityId: loc.effectiveCity?.id,
        typeId: selectedTypeId.value,
        sortBy: sortBy.value,
        cursor: reset || !keyset ? null : _cursor,
        page: reset ? 1 : _page + 1,
        pageSize: _pageSize,
      );
      if (myGen != _gen) return;

      if (reset) {
        items.assignAll(res.items);
        _page = 1;
        _loadedAt = DateTime.now();
      } else {
        final seen = items.map((e) => e.id).toSet();
        items.addAll(res.items.where((e) => seen.add(e.id)));
        _page++;
      }
      _cursor = res.nextCursor;
      hasMore.value = res.hasMore && (!keyset || res.nextCursor != null);
    } catch (_) {
      if (myGen != _gen) return;
      if (reset) {
        _dirty = true;
        if (items.isEmpty) loadFailed.value = true;
      } else {
        loadMoreFailed.value = true;
      }
    } finally {
      if (myGen == _gen) {
        isLoading.value = false;
        isLoadingMore.value = false;
        if (reset) _resetInFlight = false;
      }
    }
  }
}
