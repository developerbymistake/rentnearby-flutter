import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/location_controller.dart';
import '../../../models/location_context.dart';
import '../../../models/place_result_model.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../models/taxi_browse_item.dart';
import '../taxi_option_sets.dart';
import 'taxi_browse_repository.dart';
import 'traveller_city.dart';

class TaxiPreset {
  final PlaceResult? from;
  final String? fromCityId;
  final String? fromDistrictId;
  final PlaceResult? to;
  final String? toCityId;

  const TaxiPreset({this.from, this.fromCityId, this.fromDistrictId, this.to, this.toCityId});

  static TaxiPreset? fromArgs(Object? args) {
    if (args is! Map) return null;
    final name = args['fromName'];
    final lat = args['fromLat'];
    final lng = args['fromLng'];
    final hasFrom = name is String && name.isNotEmpty && lat is num && lng is num;
    final toName = args['toName'];
    final toLat = args['toLat'];
    final toLng = args['toLng'];
    final hasTo = toName is String && toName.isNotEmpty && toLat is num && toLng is num;
    if (!hasFrom && !hasTo) return null;
    final fromCityId = args['fromCityId'];
    final fromDistrictId = args['fromDistrictId'];
    final toCityId = args['toCityId'];
    return TaxiPreset(
      from: hasFrom ? PlaceResult(name: name, subtitle: '', latLng: LatLng(lat.toDouble(), lng.toDouble())) : null,
      fromCityId: hasFrom && fromCityId is String && fromCityId.isNotEmpty ? fromCityId : null,
      fromDistrictId: hasFrom && fromDistrictId is String && fromDistrictId.isNotEmpty ? fromDistrictId : null,
      to: hasTo ? PlaceResult(name: toName, subtitle: '', latLng: LatLng(toLat.toDouble(), toLng.toDouble())) : null,
      toCityId: hasTo && toCityId is String && toCityId.isNotEmpty ? toCityId : null,
    );
  }
}

class TaxiListController extends GetxController {
  static const tag = 'taxi';
  static const pushTag = 'taxi-push';
  static const _pageSize = 20;
  static const _staleAfter = Duration(minutes: 2);

  final bool root;
  final TaxiPreset? _preset;

  TaxiListController({this.root = false, TaxiPreset? preset}) : _preset = preset;

  final items = <TaxiBrowseItem>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasMore = false.obs;
  final loadFailed = false.obs;
  final loadMoreFailed = false.obs;
  final from = Rxn<PlaceResult>();
  final to = Rxn<PlaceResult>();
  final fromIsCurrent = false.obs;
  final refreshTrigger = 0.obs;

  final _repo = const TaxiBrowseRepository();
  final _workers = <Worker>[];
  int _page = 1;
  int _gen = 0;
  bool _resetInFlight = false;
  DateTime? _loadedAt;
  String? _fromDistrictId;
  String? _fromCityId;

  LocationController get _loc => Get.find<LocationController>();
  AuthController get _auth => Get.find<AuthController>();
  bool get _tabActive => !root || _auth.tabIndex.value == AppTabs.taxi;

  bool get isSearch => from.value != null && to.value != null;

  static PlaceResult placeOf(PickedPlace p) =>
      PlaceResult(name: p.name, subtitle: p.districtName, latLng: LatLng(p.latitude, p.longitude));

  @override
  void onInit() {
    super.onInit();
    final preset = _preset;
    if (preset != null) {
      applyPreset(preset);
    } else {
      _applyDefaultFrom();
    }
    final loc = _loc;
    _workers.add(everAll(
      [loc.autoCity, loc.userLocation, loc.selectedDistrict, loc.locationLoading],
      (_) => _onLocationChanged(),
    ));
    _workers.add(ever(refreshTrigger, (_) => _invalidate()));
    if (root) {
      _workers.add(ever(_auth.tabIndex, (i) {
        if (i == AppTabs.taxi) refreshIfStale();
      }));
    }
    if (_tabActive) _fetch(reset: true);
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  void applyPreset(TaxiPreset p) {
    to.value = p.to;
    final f = p.from;
    if (f == null) {
      if (!fromIsCurrent.value) {
        _fromDistrictId = null;
        _fromCityId = null;
        from.value = null;
      }
      _applyDefaultFrom();
    } else {
      fromIsCurrent.value = false;
      _fromDistrictId = p.fromDistrictId;
      _fromCityId = p.fromDistrictId != null ? p.fromCityId : null;
      from.value = f;
    }
    if (_loadedAt != null || _resetInFlight) _reloadFresh();
  }

  bool _applyDefaultFrom() {
    final c = travellerCity(_loc);
    if (c == null) return false;
    final current = from.value;
    if (fromIsCurrent.value && current != null && current.name == c.place.name && current.latLng == c.place.latLng) {
      return false;
    }
    fromIsCurrent.value = true;
    _fromDistrictId = c.districtId;
    _fromCityId = c.cityId;
    from.value = c.place;
    return true;
  }

  void _onLocationChanged() {
    if (isClosed) return;
    final waiting = from.value == null;
    if (!waiting && !fromIsCurrent.value) return;
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

  void setFromCity(PickedPlace p) {
    fromIsCurrent.value = false;
    _fromDistrictId = p.districtId;
    _fromCityId = p.cityId;
    from.value = placeOf(p);
    _reloadFresh();
  }

  void useCurrentFrom() {
    if (fromIsCurrent.value) return;
    from.value = null;
    _applyDefaultFrom();
    _reloadFresh();
  }

  void setToCity(PickedPlace p) {
    to.value = placeOf(p);
    _reloadFresh();
  }

  void clearTo() {
    if (to.value == null) return;
    to.value = null;
    _reloadFresh();
  }

  void refreshIfStale() {
    if (_resetInFlight || !_tabActive) return;
    final at = _loadedAt;
    if (at != null && DateTime.now().difference(at) <= _staleAfter) return;
    _fetch(reset: true, silent: items.isNotEmpty);
  }

  Future<void> pullRefresh() => _fetch(reset: true, silent: true);

  void retry() => _fetch(reset: true);

  void retryLoadMore() => _fetch(reset: false);

  void loadNextPage() {
    if (!hasMore.value || isLoading.value || isLoadingMore.value || loadMoreFailed.value || _resetInFlight) return;
    _fetch(reset: false);
  }

  void _invalidate() {
    _loadedAt = null;
    if (_tabActive) _fetch(reset: true, silent: true);
  }

  void _reloadFresh() {
    _gen++;
    _resetInFlight = false;
    _loadedAt = null;
    hasMore.value = false;
    loadFailed.value = false;
    loadMoreFailed.value = false;
    isLoadingMore.value = false;
    isLoading.value = true;
    items.clear();
    if (_tabActive) _fetch(reset: true);
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
          page: page,
          pageSize: _pageSize,
        );
      } else {
        final area = await _localArea(f);
        if (area == null || myGen != _gen) return;
        res = await _repo.browseLocal(
          districtId: area.districtId,
          cityId: area.cityId,
          page: page,
          pageSize: _pageSize,
        );
      }
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
      hasMore.value = res.hasMore;
    } on DistrictNotFoundException {
      if (myGen != _gen) return;
      if (reset) {
        items.clear();
        hasMore.value = false;
        _loadedAt = DateTime.now();
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
