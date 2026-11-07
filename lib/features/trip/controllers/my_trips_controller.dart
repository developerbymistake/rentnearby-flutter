import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:get/get.dart';
import '../../../services/storage_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../data/trip_repository.dart';
import '../models/trip_model.dart';
import '../trip_strings.dart';
import '../utils/trip_bar_rules.dart';
import '../utils/trip_clock.dart';

class MyTripsController extends GetxController {
  static MyTripsController get to => Get.isRegistered<MyTripsController>()
      ? Get.find<MyTripsController>()
      : Get.put(MyTripsController(), permanent: true);

  static const _pageSize = 20;
  static const String activeState = 'active';
  static const String pastState = 'past';

  final _repo = const TripRepository();

  final active = <TripSummaryModel>[].obs;
  final past = <TripSummaryModel>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final loadFailed = false.obs;
  final plannerOff = false.obs;
  final hasMoreActive = false.obs;
  final hasMorePast = false.obs;
  final pastOpen = false.obs;
  final pastLoading = false.obs;
  final pastFailed = false.obs;
  final counts = const TripListCounts().obs;
  final offlineCopyAt = Rxn<DateTime>();
  final hiddenVersion = 0.obs;
  int _activePage = 1;
  int _pastPage = 1;
  int _seq = 0;
  int _pastSeq = 0;
  bool _loadedOnce = false;
  Future<void>? _ensuring;
  DateTime? _loadedDay;
  DateTime? _loadedAt;
  final _doneIds = <String>{};
  AppLifecycleListener? _lifecycle;

  @override
  void onInit() {
    super.onInit();
    _lifecycle = AppLifecycleListener(onResume: refreshIfStale);
  }

  @override
  void onClose() {
    _lifecycle?.dispose();
    super.onClose();
  }

  static DateTime get _today => TripClock.today();

  static const _resumeGap = Duration(seconds: 30);

  Future<void> refreshIfStale() {
    if (!_loadedOnce || isLoading.value) return Future.value();
    final at = _loadedAt;
    if (_loadedDay == _today && at != null && DateTime.now().difference(at) < _resumeGap) return Future.value();
    return load();
  }

  Future<void> ensureLoaded() {
    if (_loadedOnce) return Future.value();
    return _ensuring ??= load().whenComplete(() => _ensuring = null);
  }

  List<TripSummaryModel> get _barSource {
    if (active.isNotEmpty || _loadedDay != null) return active;
    return _repo.cachedList(activeState)?.value.items ?? const <TripSummaryModel>[];
  }

  List<TripSummaryModel> get _openTrips => _barSource.where((t) => !_doneIds.contains(t.id)).toList();

  TripListGroups get groups => TripBarRules.group(active.where((t) => !_doneIds.contains(t.id)).toList(), _today);

  TripSummaryModel? get runningTrip {
    final now = _today;
    for (final t in _openTrips) {
      if (!TripBarRules.isPast(t, now) && (t.isRunningOn(now) || t.isCheckOutDay(now))) return t;
    }
    return null;
  }

  TripBarHide? hideOf(String tripId) {
    final h = StorageService.getTripBarHidden(tripId);
    return h == null ? null : TripBarHide(h.at, needYou: h.needYou);
  }

  TripBarPick? get barPick {
    hiddenVersion.value;
    if (plannerOff.value) return null;
    final today = _today;
    return TripBarRules.pick(_openTrips, today,
        isHidden: (t) => TripBarRules.stillHidden(t, hideOf(t.id), today));
  }

  void hideBar(TripSummaryModel t) {
    StorageService.saveTripBarHidden(t.id, DateTime.now(), needYou: TripBarRules.needCount(t));
    hiddenVersion.value++;
  }

  void adoptCompleted(String id, DateTime? at) {
    _doneIds.add(id);
    final index = active.indexWhere((t) => t.id == id);
    if (index < 0) return;
    final done = active.removeAt(index).asCompleted(at);
    if (pastOpen.value && !past.any((t) => t.id == id)) past.insert(0, done);
    _shiftCount(false, -1);
    _shiftCount(true, 1);
  }

  void adoptMuted(String id, DateTime? at) {
    for (final list in [active, past]) {
      final i = list.indexWhere((t) => t.id == id);
      if (i >= 0 && list[i].mutedAt != at) list[i] = list[i].withMuted(at);
    }
  }

  Future<void> load() async {
    final seq = ++_seq;
    isLoading.value = true;
    loadFailed.value = false;
    plannerOff.value = false;
    if (active.isEmpty) _activeFromCache();
    try {
      final res = await _repo.list(page: 1, pageSize: _pageSize, state: activeState);
      if (seq != _seq) return;
      _loadedOnce = true;
      _loadedDay = _today;
      _loadedAt = DateTime.now();
      offlineCopyAt.value = null;
      counts.value = res.counts;
      active.assignAll(res.items);
      hasMoreActive.value = res.hasMore;
      _activePage = 1;
    } catch (e) {
      if (seq != _seq) return;
      if (DioErrorMapper.errorType(e) == TripErrorTypes.plannerDisabled) {
        plannerOff.value = true;
      } else if (!(e is DioException && e.response?.statusCode == 401)) {
        if (!(DioErrorMapper.isNetworkError(e) && _activeFromCache())) loadFailed.value = true;
      }
    } finally {
      if (seq == _seq) isLoading.value = false;
    }
    if (pastOpen.value && seq == _seq && !plannerOff.value) await loadPast();
  }

  bool _activeFromCache() {
    final cached = _repo.cachedList(activeState);
    if (cached == null) return false;
    _loadedOnce = true;
    counts.value = cached.value.counts;
    active.assignAll(cached.value.items);
    hasMoreActive.value = false;
    _activePage = 1;
    offlineCopyAt.value = cached.savedAt ?? DateTime.now();
    return true;
  }

  Future<void> loadPast() async {
    final seq = ++_pastSeq;
    pastLoading.value = true;
    pastFailed.value = false;
    try {
      final res = await _repo.list(page: 1, pageSize: _pageSize, state: pastState);
      if (seq != _pastSeq) return;
      past.assignAll(res.items);
      hasMorePast.value = res.hasMore;
      _pastPage = 1;
    } catch (e) {
      if (seq != _pastSeq) return;
      final cached = DioErrorMapper.isNetworkError(e) ? _repo.cachedList(pastState) : null;
      if (cached != null) {
        past.assignAll(cached.value.items);
        hasMorePast.value = false;
      } else if (!(e is DioException && e.response?.statusCode == 401)) {
        pastFailed.value = true;
      }
    } finally {
      if (seq == _pastSeq) pastLoading.value = false;
    }
  }

  Future<void> togglePast() async {
    pastOpen.value = !pastOpen.value;
    if (pastOpen.value && past.isEmpty) await loadPast();
  }

  Future<void> loadMore() async {
    if (isLoading.value || isLoadingMore.value || offlineCopyAt.value != null) return;
    final more = hasMoreActive.value ? activeState : (pastOpen.value && hasMorePast.value ? pastState : null);
    if (more == null) return;
    final seq = more == activeState ? _seq : _pastSeq;
    isLoadingMore.value = true;
    try {
      final page = (more == activeState ? _activePage : _pastPage) + 1;
      final res = await _repo.list(page: page, pageSize: _pageSize, state: more);
      if (seq != (more == activeState ? _seq : _pastSeq)) return;
      final list = more == activeState ? active : past;
      final known = list.map((t) => t.id).toSet();
      list.addAll(res.items.where((t) => known.add(t.id)));
      if (more == activeState) {
        hasMoreActive.value = res.hasMore;
        _activePage = page;
      } else {
        hasMorePast.value = res.hasMore;
        _pastPage = page;
      }
    } catch (_) {
      return;
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<bool> delete(String id) async {
    final inActive = active.indexWhere((t) => t.id == id);
    final inPast = past.indexWhere((t) => t.id == id);
    final listed = inActive >= 0 || inPast >= 0;
    final removed = inActive >= 0 ? active.removeAt(inActive) : (inPast >= 0 ? past.removeAt(inPast) : null);
    final wasPast = inActive < 0;
    if (listed) _shiftCount(wasPast, -1);
    try {
      await _repo.delete(id);
      StorageService.clearTripCache(id);
      _repo.forgetCached(id);
      return true;
    } catch (e) {
      if (DioErrorMapper.errorType(e) == TripErrorTypes.tripNotFound) {
        StorageService.clearTripCache(id);
        _repo.forgetCached(id);
        return true;
      }
      if (removed != null) {
        if (wasPast) {
          past.insert(inPast.clamp(0, past.length), removed);
        } else {
          active.insert(inActive.clamp(0, active.length), removed);
        }
        _shiftCount(wasPast, 1);
      }
      AppToast.error(DioErrorMapper.toMessage(e, "Couldn't delete the trip."));
      return false;
    }
  }

  void removeLocal(String id) {
    _repo.forgetCached(id);
    final a = active.indexWhere((t) => t.id == id);
    if (a >= 0) {
      active.removeAt(a);
      _shiftCount(false, -1);
    }
    final p = past.indexWhere((t) => t.id == id);
    if (p >= 0) {
      past.removeAt(p);
      _shiftCount(true, -1);
    }
  }

  void _shiftCount(bool past, int by) {
    final c = counts.value;
    counts.value = past
        ? TripListCounts(upcoming: c.upcoming, completed: (c.completed + by).clamp(0, 1 << 30))
        : TripListCounts(upcoming: (c.upcoming + by).clamp(0, 1 << 30), completed: c.completed);
  }

  Future<bool> markComplete(String id) async {
    try {
      final trip = await _repo.complete(id);
      if (active.any((t) => t.id == id)) {
        adoptCompleted(id, trip.completedAt);
      } else {
        _doneIds.add(id);
        final i = past.indexWhere((t) => t.id == id);
        if (i >= 0) past[i] = past[i].asCompleted(trip.completedAt);
      }
      AppToast.success(TripStrings.tripCompleted);
      return trip.isCompleted;
    } catch (e) {
      if (DioErrorMapper.errorType(e) == TripErrorTypes.tripNotEnded) {
        AppToast.error(TripStrings.tripNotEnded);
      } else {
        AppToast.error(DioErrorMapper.toMessage(e, TripStrings.couldNotLoad));
      }
      return false;
    }
  }
}
