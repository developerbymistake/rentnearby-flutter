import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../controllers/location_controller.dart';
import '../../../models/place_result_model.dart';
import '../models/taxi_browse_item.dart';
import '../taxi_option_sets.dart';
import 'taxi_browse_repository.dart';

class TaxiListController extends GetxController {
  static const tag = 'taxi';
  static const _pageSize = 20;

  final items = <TaxiBrowseItem>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasMore = false.obs;
  final loadFailed = false.obs;
  final loadMoreFailed = false.obs;
  final noDistrict = false.obs;
  final from = Rxn<PlaceResult>();
  final to = Rxn<PlaceResult>();
  final category = Rxn<String>();
  final refreshTrigger = 0.obs;

  final _repo = const TaxiBrowseRepository();
  final _workers = <Worker>[];
  int _page = 1;
  int _gen = 0;
  String? _loadedLocationKey;
  bool _resetInFlight = false;
  bool _locationCheckQueued = false;

  LocationController get _loc => Get.find<LocationController>();

  bool get isSearch => from.value != null && to.value != null;

  bool get hasOneEndpoint => (from.value == null) != (to.value == null);

  String get _locationKey => '${_loc.effectiveDistrict?.id}|${_loc.effectiveCity?.id}';

  @override
  void onInit() {
    super.onInit();
    _readPreset();
    final loc = _loc;
    _workers.add(everAll(
      [loc.selectedDistrict, loc.browsingDistrict, loc.browsingCity, loc.autoCity],
      (_) => _queueLocationCheck(),
    ));
    _workers.add(ever(refreshTrigger, (_) => _fetch(reset: true, silent: true)));
    _fetch(reset: true);
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  void _readPreset() {
    final args = Get.arguments;
    if (args is! Map) return;
    final name = args['fromName'];
    final lat = args['fromLat'];
    final lng = args['fromLng'];
    if (name is! String || name.isEmpty || lat is! num || lng is! num) return;
    from.value = PlaceResult(name: name, subtitle: '', latLng: LatLng(lat.toDouble(), lng.toDouble()));
  }

  void _queueLocationCheck() {
    if (_locationCheckQueued) return;
    _locationCheckQueued = true;
    Future.microtask(() {
      _locationCheckQueued = false;
      if (isClosed || isSearch || _locationKey == _loadedLocationKey) return;
      _reloadFresh();
    });
  }

  bool isTooClose(PlaceResult a, PlaceResult? b) =>
      b != null &&
      TaxiOptionSets.distanceMeters(a.latLng.latitude, a.latLng.longitude, b.latLng.latitude, b.latLng.longitude) <
          TaxiOptionSets.minEndpointDistanceMeters;

  void setFrom(PlaceResult p) => _setEndpoint(() => from.value = p);

  void setTo(PlaceResult p) => _setEndpoint(() => to.value = p);

  void clearFrom() {
    if (from.value == null) return;
    _setEndpoint(() => from.value = null);
  }

  void clearTo() {
    if (to.value == null) return;
    _setEndpoint(() => to.value = null);
  }

  void _setEndpoint(void Function() apply) {
    final wasSearch = isSearch;
    apply();
    if (isSearch || wasSearch) _reloadFresh();
  }

  void setCategory(String? value) {
    if (category.value == value) return;
    category.value = value;
    _reloadFresh();
  }

  void search() => _reloadFresh();

  Future<void> pullRefresh() => _fetch(reset: true, silent: true);

  void retry() => _fetch(reset: true);

  void retryLoadMore() => _fetch(reset: false);

  void loadNextPage() {
    if (!hasMore.value || isLoading.value || isLoadingMore.value || loadMoreFailed.value || _resetInFlight) return;
    _fetch(reset: false);
  }

  void _reloadFresh() {
    _gen++;
    _resetInFlight = false;
    _loadedLocationKey = null;
    hasMore.value = false;
    loadFailed.value = false;
    loadMoreFailed.value = false;
    isLoadingMore.value = false;
    isLoading.value = true;
    items.clear();
    _fetch(reset: true);
  }

  Future<void> _fetch({required bool reset, bool silent = false}) async {
    final searching = isSearch;
    final districtId = _loc.effectiveDistrict?.id;
    noDistrict.value = !searching && districtId == null;
    if (noDistrict.value) {
      _gen++;
      _resetInFlight = false;
      items.clear();
      hasMore.value = false;
      isLoading.value = false;
      isLoadingMore.value = false;
      return;
    }

    final myGen = ++_gen;
    if (reset) {
      _resetInFlight = true;
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
      final page = reset ? 1 : _page + 1;
      final f = from.value;
      final t = to.value;
      final res = searching && f != null && t != null
          ? await _repo.search(
              fromLat: f.latLng.latitude,
              fromLng: f.latLng.longitude,
              toLat: t.latLng.latitude,
              toLng: t.latLng.longitude,
              category: category.value,
              page: page,
              pageSize: _pageSize,
            )
          : await _repo.browseLocal(
              districtId: districtId!,
              cityId: _loc.effectiveCity?.id,
              category: category.value,
              page: page,
              pageSize: _pageSize,
            );
      if (myGen != _gen) return;

      if (reset) {
        items.assignAll(res.items);
        _page = 1;
      } else {
        final seen = items.map((e) => e.id).toSet();
        items.addAll(res.items.where((e) => seen.add(e.id)));
        _page++;
      }
      hasMore.value = res.hasMore;
    } catch (_) {
      if (myGen != _gen) return;
      if (reset) {
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
