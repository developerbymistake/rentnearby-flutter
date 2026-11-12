import 'dart:async';
import 'package:get/get.dart';
import '../../../controllers/location_controller.dart';
import '../../nearby/models/nearby_models.dart';
import '../../trip/models/trip_city_model.dart';
import '../data/jobs_repository.dart';
import '../models/job_experience_bucket.dart';
import '../models/job_lookups_model.dart';
import 'jobs_feed_repository.dart';

typedef JobsFeedFetch = Future<NearbyPage<JobFeedItem>> Function({
  int? cityKey,
  double? lat,
  double? lng,
  String? departmentId,
  int? minExperience,
  int? maxExperience,
  int? minSalary,
  String? pageToken,
  int pageSize,
});

typedef JobsGps = ({double lat, double lng})? Function();

class JobsFeedController extends GetxController {
  static const tag = 'jobs-v2';
  static const _pageSize = 20;
  static const _staleAfter = Duration(minutes: 2);
  static const _gpsMoveDeg = 0.01;

  JobsFeedController({JobsFeedFetch? fetch, JobsGps? gps, Future<JobLookups> Function()? lookupsLoader})
      : _fetchFn = fetch ?? const JobsFeedRepository().getFeed,
        _gps = gps ?? _defaultGps,
        _lookupsLoader = lookupsLoader ?? (() => const JobsRepository().getLookups());

  final JobsFeedFetch _fetchFn;
  final JobsGps _gps;
  final Future<JobLookups> Function() _lookupsLoader;

  final items = <JobFeedItem>[].obs;
  final header = Rxn<NearbyHeader>();
  final city = Rxn<TripCityModel>();
  final searchPin = Rxn<({double lat, double lng, String label})>();
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasMore = false.obs;
  final loadFailed = false.obs;
  final loadMoreFailed = false.obs;
  final lookups = Rxn<JobLookups>();
  final selectedDepartmentId = Rxn<String>();
  final selectedExperience = Rxn<JobExperienceBucket>();
  final minSalary = Rxn<int>();
  final resetGeneration = 0.obs;

  final _workers = <Worker>[];
  String? _nextToken;
  int _gen = 0;
  DateTime? _loadedAt;
  bool _dirty = false;
  bool _lookupsLoading = false;
  ({double lat, double lng})? _loadedGps;

  static JobsGps get _defaultGps => () {
        if (!Get.isRegistered<LocationController>()) return null;
        final loc = Get.find<LocationController>();
        final p = loc.userLocation.value ?? loc.effectiveSearchCenter;
        return (lat: p.latitude, lng: p.longitude);
      };

  bool get hasFilters =>
      selectedDepartmentId.value != null || selectedExperience.value != null || minSalary.value != null;

  bool get usingCity => city.value != null;

  static void invalidate() {
    if (Get.isRegistered<JobsFeedController>(tag: tag)) {
      Get.find<JobsFeedController>(tag: tag).markDirty();
    }
  }

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<LocationController>()) {
      _workers.add(ever(Get.find<LocationController>().userLocation, (_) => _onGpsMoved()));
    }
    refreshIfNeeded();
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  void _onGpsMoved() {
    if (usingCity || searchPin.value != null) return;
    final now = _gps();
    final was = _loadedGps;
    if (now == null || was == null) return;
    if ((now.lat - was.lat).abs() > _gpsMoveDeg || (now.lng - was.lng).abs() > _gpsMoveDeg) _reloadFresh();
  }

  void markDirty() {
    _dirty = true;
    _loadedAt = null;
    refreshIfNeeded();
  }

  void pickCity(TripCityModel c) {
    if (city.value?.cityKey == c.cityKey && searchPin.value == null) return;
    searchPin.value = null;
    city.value = c;
    _reloadFresh();
  }

  void useMyLocation() {
    if (city.value == null && searchPin.value == null) return;
    city.value = null;
    searchPin.value = null;
    _reloadFresh();
  }

  void pickPin(double lat, double lng, String label) {
    city.value = null;
    searchPin.value = (lat: lat, lng: lng, label: label);
    _reloadFresh();
  }

  void clearFilters() {
    if (!hasFilters) return;
    selectedDepartmentId.value = null;
    selectedExperience.value = null;
    minSalary.value = null;
    resetGeneration.value++;
    _reloadFresh();
  }

  Future<void> loadLookups() async {
    if (lookups.value != null || _lookupsLoading) return;
    _lookupsLoading = true;
    try {
      lookups.value = await _lookupsLoader();
    } catch (_) {
      // Retried on the next refresh.
    } finally {
      _lookupsLoading = false;
    }
  }

  void refreshIfNeeded() {
    unawaited(loadLookups());
    final at = _loadedAt;
    final stale = at == null || DateTime.now().difference(at) > _staleAfter;
    if (!_dirty && !stale) return;
    _fetch(reset: true, silent: items.isNotEmpty);
  }

  Future<void> pullRefresh() {
    unawaited(loadLookups());
    return _fetch(reset: true, silent: true);
  }

  void retry() => _fetch(reset: true);

  void retryLoadMore() => _fetch(reset: false);

  void loadNextPage() {
    if (!hasMore.value || isLoading.value || isLoadingMore.value || loadMoreFailed.value) return;
    _fetch(reset: false);
  }

  void setDepartment(String? id) {
    if (selectedDepartmentId.value == id) return;
    selectedDepartmentId.value = id;
    _reloadFresh();
  }

  void applyFilters({
    required String? departmentId,
    required JobExperienceBucket? experience,
    required int? minSalary,
  }) {
    if (selectedDepartmentId.value == departmentId &&
        selectedExperience.value == experience &&
        this.minSalary.value == minSalary) {
      return;
    }
    selectedDepartmentId.value = departmentId;
    selectedExperience.value = experience;
    this.minSalary.value = minSalary;
    _reloadFresh();
  }

  void _reloadFresh() {
    _gen++;
    _loadedAt = null;
    _nextToken = null;
    hasMore.value = false;
    loadFailed.value = false;
    loadMoreFailed.value = false;
    isLoadingMore.value = false;
    isLoading.value = true;
    items.clear();
    _fetch(reset: true);
  }

  Future<void> _fetch({required bool reset, bool silent = false}) async {
    final myGen = ++_gen;
    final c = city.value;
    final pin = searchPin.value;
    final gps = c != null ? null : (pin != null ? (lat: pin.lat, lng: pin.lng) : _gps());
    if (reset) {
      _dirty = false;
      loadFailed.value = false;
      loadMoreFailed.value = false;
      isLoadingMore.value = false;
      if (!silent || items.isEmpty) isLoading.value = true;
    } else {
      isLoadingMore.value = true;
      loadMoreFailed.value = false;
    }
    try {
      final page = await _fetchFn(
        cityKey: c?.cityKey,
        lat: gps?.lat,
        lng: gps?.lng,
        departmentId: selectedDepartmentId.value,
        minExperience: selectedExperience.value?.min,
        maxExperience: selectedExperience.value?.max,
        minSalary: minSalary.value,
        pageToken: reset ? null : _nextToken,
        pageSize: _pageSize,
      );
      if (myGen != _gen) return;
      header.value = page.header;
      _nextToken = page.nextToken;
      hasMore.value = page.hasMore && page.nextToken != null;
      if (reset) {
        items.assignAll(_dedupe(page.items));
        _loadedAt = DateTime.now();
        _loadedGps = gps;
      } else {
        final seen = items.map((e) => e.id).toSet();
        items.addAll(page.items.where((e) => seen.add(e.id)));
      }
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
      }
    }
  }

  static List<JobFeedItem> _dedupe(List<JobFeedItem> list) {
    final seen = <String>{};
    return [for (final e in list) if (seen.add(e.id)) e];
  }
}
