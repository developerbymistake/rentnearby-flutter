import 'package:get/get.dart';
import '../services/api_service.dart';
import 'home_controller.dart' show HomeRoomModel, HomePlotModel;
import 'location_controller.dart';

enum ViewAllListingType { rooms, plots }

/// Normalized shape both Rooms and Plots collapse into, so ViewAllScreen's
/// grid doesn't need to branch on listing type.
class ViewAllItem {
  final String id;
  final String? thumbnailUrl;
  final String badgeLabel;
  final String priceLabel;
  final String title;
  final String locationLabel;

  ViewAllItem({
    required this.id,
    required this.thumbnailUrl,
    required this.badgeLabel,
    required this.priceLabel,
    required this.title,
    required this.locationLabel,
  });

  factory ViewAllItem.fromRoom(HomeRoomModel r) => ViewAllItem(
        id: r.id,
        thumbnailUrl: r.thumbnailUrl,
        badgeLabel: r.roomTypeName ?? 'Room',
        priceLabel: '₹${r.priceMonthly}/mo',
        title: '${r.roomTypeName ?? 'Room'}${r.furnishedStatus != 'None' ? ' · ${r.furnishedStatus}' : ''}',
        locationLabel: [r.cityName, r.districtName].where((s) => s != null && s.isNotEmpty).join(', '),
      );

  factory ViewAllItem.fromPlot(HomePlotModel p) => ViewAllItem(
        id: p.id,
        thumbnailUrl: p.thumbnailUrl,
        badgeLabel: p.plotTypeName ?? 'Plot',
        priceLabel: '${p.areaValue.toStringAsFixed(p.areaValue.truncateToDouble() == p.areaValue ? 0 : 1)} ${p.areaUnit}',
        title: p.plotTypeName ?? 'Plot',
        locationLabel: [p.cityName, p.districtName].where((s) => s != null && s.isNotEmpty).join(', '),
      );
}

/// Route-scoped controller for ViewAllScreen — deliberately NOT a permanent
/// singleton (see view_all_screen.dart): every push from Home gets a fresh
/// instance, which is what gives "reset filters + fetch latest data on
/// re-entry from Home" for free without manual reset bookkeeping.
///
/// Reload only happens on: initial onInit load, pull-to-refresh, Apply in
/// the filter sheet, a location change, or flipping the Rooms/Plots toggle.
/// No didChangeAppLifecycleState — see the plan's "refresh discipline" note
/// for why that's deliberate.
class ViewAllController extends GetxController {
  /// Which type the screen opened on — the Rooms/Plots toggle can still
  /// flip `activeType` afterward within the same screen/controller.
  /// [initialTypeId] seeds [selectedTypeId] — used by the "Find Near Me"
  /// tour's hand-off so View All opens already filtered to the same type
  /// the tour was scoped to, instead of always starting unfiltered.
  ViewAllController(ViewAllListingType initialType, {String? initialTypeId})
      : activeType = initialType.obs,
        selectedTypeId = Rxn<String>(initialTypeId);

  final Rx<ViewAllListingType> activeType;

  final items = <ViewAllItem>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasMore = false.obs;

  /// Room type id or plot type id — null means "all types". Type-specific,
  /// so it's always cleared when the toggle flips (a Rooms filter has no
  /// meaning once you're looking at Plots).
  final Rxn<String> selectedTypeId;
  final sortBy = 'newest'.obs;

  /// Bumped by resetFilters() — FilterSortSheet watches this to detect an
  /// external reset (location change, toggle flip) while it's open and
  /// dismiss itself, mirroring LocationSwitchSheet's own external-reset guard.
  final resetGeneration = 0.obs;

  int _page = 1;
  static const _pageSize = 10;

  /// Monotonic per-request token — guards against an in-flight loadNextPage()
  /// response landing after a pull-to-refresh has already reset _page to 1
  /// (which would otherwise overwrite the fresh page-1 items with stale
  /// page-2 data). Only the response matching the request that's still the
  /// most recent one gets applied.
  int _requestId = 0;

  Worker? _locationWorker;

  @override
  void onInit() {
    super.onInit();
    final locationCtrl = Get.find<LocationController>();
    _locationWorker = everAll(
      [
        locationCtrl.selectedDistrict,
        locationCtrl.browsingDistrict,
        locationCtrl.browsingCity,
        locationCtrl.autoCity,
      ],
      (_) {
        resetFilters();
        loadPage(reset: true);
      },
    );
    loadPage(reset: true);
  }

  @override
  void onClose() {
    _locationWorker?.dispose();
    super.onClose();
  }

  void resetFilters() {
    selectedTypeId.value = null;
    sortBy.value = 'newest';
    resetGeneration.value++;
  }

  void setType(ViewAllListingType type) {
    if (activeType.value == type) return;
    activeType.value = type;
    resetFilters();
    loadPage(reset: true);
  }

  void applyFilters({String? typeId, required String sort}) {
    selectedTypeId.value = typeId;
    sortBy.value = sort;
    loadPage(reset: true);
  }

  Future<void> loadNextPage() async {
    if (!hasMore.value || isLoading.value || isLoadingMore.value) return;
    _page++;
    await loadPage();
  }

  Future<void> loadPage({bool reset = false}) async {
    final locationCtrl = Get.find<LocationController>();
    final districtId = locationCtrl.effectiveDistrict?.id;
    if (districtId == null) return;
    final cityId = locationCtrl.effectiveCity?.id;

    final isRooms = activeType.value == ViewAllListingType.rooms;

    if (reset) {
      _page = 1;
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    final requestedPage = _page;
    final myRequestId = ++_requestId;

    try {
      final path = isRooms ? '/home/rooms/browse' : '/home/plots/browse';
      final typeParamKey = isRooms ? 'roomTypeId' : 'plotTypeId';

      final res = await ApiService.get(path, params: {
        'districtId': districtId,
        if (cityId != null) 'cityId': cityId,
        if (selectedTypeId.value != null) typeParamKey: selectedTypeId.value,
        'sortBy': sortBy.value,
        'page': requestedPage,
        'pageSize': _pageSize,
      });

      // A newer request (e.g. a pull-to-refresh reset) started after this
      // one — discard this response instead of letting it clobber fresher
      // state that's already landed or is still in flight.
      if (myRequestId != _requestId) return;

      final list = (res['data']?['items'] as List?) ?? const [];
      final parsed = isRooms
          ? list.map((e) => ViewAllItem.fromRoom(HomeRoomModel.fromJson(e as Map<String, dynamic>)))
          : list.map((e) => ViewAllItem.fromPlot(HomePlotModel.fromJson(e as Map<String, dynamic>)));

      if (requestedPage == 1) {
        items.value = parsed.toList();
      } else {
        items.addAll(parsed);
      }
      hasMore.value = res['data']?['hasMore'] == true;
    } catch (_) {
      if (myRequestId == _requestId && requestedPage > 1) {
        _page = requestedPage - 1; // don't strand the page counter past a failed next-page fetch
      }
    } finally {
      if (myRequestId == _requestId) {
        isLoading.value = false;
        isLoadingMore.value = false;
      }
    }
  }
}
