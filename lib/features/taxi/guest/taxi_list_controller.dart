import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../controllers/location_controller.dart';
import '../../../models/location_context.dart';
import '../../../models/place_result_model.dart';
import '../models/taxi_browse_item.dart';
import '../taxi_option_sets.dart';
import 'taxi_browse_repository.dart';

typedef TaxiFromPlace = ({PlaceResult place, String districtId, String? cityId});

class TaxiListController extends GetxController {
  static const tag = 'taxi';
  static const _pageSize = 20;

  final items = <TaxiBrowseItem>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasMore = false.obs;
  final loadFailed = false.obs;
  final loadMoreFailed = false.obs;
  final from = Rxn<PlaceResult>();
  final to = Rxn<PlaceResult>();
  final category = Rxn<String>();
  final refreshTrigger = 0.obs;

  final _repo = const TaxiBrowseRepository();
  final _workers = <Worker>[];
  int _page = 1;
  int _gen = 0;
  bool _resetInFlight = false;
  bool _fromIsDefault = false;
  String? _fromDistrictId;
  String? _fromCityId;

  LocationController get _loc => Get.find<LocationController>();

  bool get isSearch => from.value != null && to.value != null;

  static TaxiFromPlace? currentCity(LocationController loc) {
    final auto = loc.autoCity.value;
    if (auto != null && auto.latitude != null && auto.longitude != null) {
      return (
        place: PlaceResult(name: auto.name, subtitle: '', latLng: LatLng(auto.latitude!, auto.longitude!)),
        districtId: auto.districtId,
        cityId: auto.id,
      );
    }
    final gps = loc.userLocation.value;
    final district = loc.selectedDistrict.value;
    if (gps != null && district != null) {
      return (place: PlaceResult(name: district.name, subtitle: '', latLng: gps), districtId: district.id, cityId: null);
    }
    final city = loc.effectiveCity;
    if (city != null && city.latitude != null && city.longitude != null) {
      return (
        place: PlaceResult(name: city.name, subtitle: '', latLng: LatLng(city.latitude!, city.longitude!)),
        districtId: city.districtId,
        cityId: city.id,
      );
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    _readPreset();
    if (from.value == null) _applyDefaultFrom();
    final loc = _loc;
    _workers.add(everAll(
      [loc.autoCity, loc.userLocation, loc.selectedDistrict, loc.browsingCity, loc.locationLoading],
      (_) => _onLocationChanged(),
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
    final toName = args['toName'];
    final toLat = args['toLat'];
    final toLng = args['toLng'];
    if (toName is String && toName.isNotEmpty && toLat is num && toLng is num) {
      to.value = PlaceResult(name: toName, subtitle: '', latLng: LatLng(toLat.toDouble(), toLng.toDouble()));
    }
  }

  bool _applyDefaultFrom() {
    final c = currentCity(_loc);
    if (c == null) return false;
    final current = from.value;
    if (_fromIsDefault && current != null && current.name == c.place.name && current.latLng == c.place.latLng) {
      return false;
    }
    _fromIsDefault = true;
    _fromDistrictId = c.districtId;
    _fromCityId = c.cityId;
    from.value = c.place;
    return true;
  }

  void _onLocationChanged() {
    if (isClosed) return;
    final waiting = from.value == null;
    if (!waiting && !_fromIsDefault) return;
    if (_applyDefaultFrom()) {
      _reloadFresh();
    } else if (waiting && !_loc.locationLoading.value) {
      isLoading.value = false;
    }
  }

  bool isTooClose(PlaceResult a, PlaceResult? b) =>
      b != null &&
      TaxiOptionSets.distanceMeters(a.latLng.latitude, a.latLng.longitude, b.latLng.latitude, b.latLng.longitude) <
          TaxiOptionSets.minEndpointDistanceMeters;

  void setFrom(PlaceResult p) {
    _fromIsDefault = false;
    _fromDistrictId = null;
    _fromCityId = null;
    from.value = p;
    _reloadFresh();
  }

  void setTo(PlaceResult p) {
    to.value = p;
    _reloadFresh();
  }

  void clearTo() {
    if (to.value == null) return;
    to.value = null;
    _reloadFresh();
  }

  void setCategory(String? v) {
    if (category.value == v) return;
    category.value = v;
    _reloadFresh();
  }

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
    hasMore.value = false;
    loadFailed.value = false;
    loadMoreFailed.value = false;
    isLoadingMore.value = false;
    isLoading.value = true;
    items.clear();
    _fetch(reset: true);
  }

  Future<({String districtId, String? cityId})?> _localArea(PlaceResult f) async {
    final known = _fromDistrictId;
    if (known != null) return (districtId: known, cityId: _fromCityId);
    final ctx = await _loc.resolveDistrictAt(f.latLng.latitude, f.latLng.longitude);
    if (from.value != f) return null;
    _fromDistrictId = ctx.district.id;
    _fromCityId = ctx.nearestCity?.id;
    return (districtId: ctx.district.id, cityId: ctx.nearestCity?.id);
  }

  Future<void> _fetch({required bool reset, bool silent = false}) async {
    final f = from.value;
    if (f == null) {
      _gen++;
      _resetInFlight = false;
      items.clear();
      hasMore.value = false;
      isLoadingMore.value = false;
      isLoading.value = _loc.locationLoading.value;
      return;
    }

    final myGen = ++_gen;
    if (reset) {
      _resetInFlight = true;
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
      final t = to.value;
      final TaxiBrowsePage res;
      if (t != null) {
        res = await _repo.search(
          fromLat: f.latLng.latitude,
          fromLng: f.latLng.longitude,
          toLat: t.latLng.latitude,
          toLng: t.latLng.longitude,
          category: category.value,
          page: page,
          pageSize: _pageSize,
        );
      } else {
        final area = await _localArea(f);
        if (area == null || myGen != _gen) return;
        res = await _repo.browseLocal(
          districtId: area.districtId,
          cityId: area.cityId,
          category: category.value,
          page: page,
          pageSize: _pageSize,
        );
      }
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
    } on DistrictNotFoundException {
      if (myGen != _gen) return;
      if (reset) {
        items.clear();
        hasMore.value = false;
      }
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
