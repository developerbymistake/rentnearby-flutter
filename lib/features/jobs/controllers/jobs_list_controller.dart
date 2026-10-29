import 'dart:async';
import 'package:get/get.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/location_controller.dart';
import '../data/jobs_repository.dart';
import '../models/job_experience_bucket.dart';
import '../models/job_lookups_model.dart';
import '../models/job_summary_model.dart';

class JobsListController extends GetxController {
  static const tag = 'jobs';
  static const _pageSize = 20;
  static const _staleAfter = Duration(minutes: 2);

  final items = <JobSummaryModel>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasMore = false.obs;
  final loadFailed = false.obs;
  final loadMoreFailed = false.obs;
  final noDistrict = false.obs;
  final lookups = Rxn<JobLookups>();
  final selectedDepartmentId = Rxn<String>();
  final selectedExperience = Rxn<JobExperienceBucket>();
  final minSalary = Rxn<int>();
  final resetGeneration = 0.obs;
  final exploreRefreshTrigger = 0.obs;
  final filterResetTrigger = 0.obs;

  final _repo = const JobsRepository();
  final _workers = <Worker>[];
  int _page = 1;
  int _gen = 0;
  DateTime? _loadedAt;
  String? _loadedDistrictId;
  bool _dirty = false;
  bool _resetInFlight = false;
  bool _lookupsLoading = false;

  AuthController get _auth => Get.find<AuthController>();
  bool get _tabActive => _auth.tabIndex.value == AppTabs.jobs;
  String? get _districtId => Get.find<LocationController>().effectiveDistrict?.id;

  bool get hasFilters => selectedExperience.value != null || minSalary.value != null;

  @override
  void onInit() {
    super.onInit();
    final loc = Get.find<LocationController>();
    _workers.add(everAll([loc.selectedDistrict, loc.browsingDistrict], (_) => _onDistrictChanged()));
    _workers.add(ever(_auth.tabIndex, (i) {
      if (i == AppTabs.jobs) refreshIfNeeded();
    }));
    _workers.add(ever(exploreRefreshTrigger, (_) => refreshIfNeeded()));
    _workers.add(ever(filterResetTrigger, (_) => _clearFilters()));
    if (_tabActive) refreshIfNeeded();
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  void _onDistrictChanged() {
    if (isClosed || _districtId == _loadedDistrictId) return;
    _invalidateHard();
    if (_tabActive) refreshIfNeeded();
  }

  void _clearFilters() {
    if (selectedDepartmentId.value == null && !hasFilters) return;
    selectedDepartmentId.value = null;
    selectedExperience.value = null;
    minSalary.value = null;
    resetGeneration.value++;
    _invalidateHard();
    if (_tabActive) refreshIfNeeded();
  }

  void invalidate() {
    _dirty = true;
    _loadedAt = null;
    if (_tabActive) refreshIfNeeded();
  }

  void _invalidateHard() {
    _gen++;
    _resetInFlight = false;
    _loadedAt = null;
    _loadedDistrictId = null;
    hasMore.value = false;
    loadFailed.value = false;
    loadMoreFailed.value = false;
    isLoadingMore.value = false;
    isLoading.value = true;
    items.clear();
  }

  Future<void> loadLookups() async {
    if (lookups.value != null || _lookupsLoading) return;
    _lookupsLoading = true;
    try {
      lookups.value = await _repo.getLookups();
    } catch (_) {
      // Retried on the next refresh.
    } finally {
      _lookupsLoading = false;
    }
  }

  void refreshIfNeeded() {
    unawaited(loadLookups());
    if (_resetInFlight && !_dirty) return;
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
    if (!hasMore.value || isLoading.value || isLoadingMore.value || loadMoreFailed.value || _resetInFlight) return;
    _fetch(reset: false);
  }

  void setDepartment(String? id) {
    if (selectedDepartmentId.value == id) return;
    selectedDepartmentId.value = id;
    _reloadFresh();
  }

  void applyFilters({JobExperienceBucket? experience, int? minSalary}) {
    if (selectedExperience.value == experience && this.minSalary.value == minSalary) return;
    selectedExperience.value = experience;
    this.minSalary.value = minSalary;
    _reloadFresh();
  }

  void _reloadFresh() {
    _invalidateHard();
    _fetch(reset: true);
  }

  Future<void> _fetch({required bool reset, bool silent = false}) async {
    final districtId = _districtId;
    noDistrict.value = districtId == null;
    if (districtId == null) {
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
      _dirty = false;
      _loadedDistrictId = districtId;
      loadFailed.value = false;
      loadMoreFailed.value = false;
      isLoadingMore.value = false;
      if (!silent || items.isEmpty) isLoading.value = true;
    } else {
      isLoadingMore.value = true;
      loadMoreFailed.value = false;
    }

    try {
      final res = await _repo.browse(
        districtId: districtId,
        departmentId: selectedDepartmentId.value,
        minExperience: selectedExperience.value?.min,
        maxExperience: selectedExperience.value?.max,
        minSalary: minSalary.value,
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
      hasMore.value = res.hasMore;
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
