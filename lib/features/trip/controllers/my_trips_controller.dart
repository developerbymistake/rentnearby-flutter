import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:get/get.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../data/trip_repository.dart';
import '../models/trip_model.dart';
import '../trip_strings.dart';
import '../utils/trip_clock.dart';

class MyTripsController extends GetxController {
  static MyTripsController get to => Get.isRegistered<MyTripsController>()
      ? Get.find<MyTripsController>()
      : Get.put(MyTripsController(), permanent: true);

  static const _pageSize = 20;

  final _repo = const TripRepository();

  final items = <TripSummaryModel>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final loadFailed = false.obs;
  final plannerOff = false.obs;
  final hasMore = false.obs;
  final state = 'upcoming'.obs;
  final counts = const TripListCounts().obs;
  final offlineCopyAt = Rxn<DateTime>();
  final upcoming = <TripSummaryModel>[].obs;
  int page = 1;
  int _seq = 0;
  bool _loadedOnce = false;
  Future<void>? _ensuring;
  DateTime? _loadedDay;
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

  Future<void> refreshIfStale() {
    if (!_loadedOnce || isLoading.value) return Future.value();
    if (_loadedDay == _today && state.value == _upcoming) return Future.value();
    return load();
  }

  void resetView() {
    if (state.value == _upcoming) return;
    state.value = _upcoming;
    items.assignAll(upcoming);
    hasMore.value = false;
  }

  void adoptCompleted(String id, DateTime? at) {
    _doneIds.add(id);
    final wasUpcoming = upcoming.any((t) => t.id == id);
    if (wasUpcoming) upcoming.removeWhere((t) => t.id == id);
    final index = items.indexWhere((t) => t.id == id);
    if (index >= 0 && !items[index].isCompleted) {
      if (state.value == _upcoming) {
        items.removeAt(index);
      } else {
        items[index] = items[index].asCompleted(at);
      }
    }
    if (wasUpcoming) {
      _shiftCount(false, -1);
      _shiftCount(true, 1);
    }
  }

  void adoptMuted(String id, DateTime? at) {
    final i = items.indexWhere((t) => t.id == id);
    if (i >= 0 && items[i].mutedAt != at) items[i] = items[i].withMuted(at);
    final u = upcoming.indexWhere((t) => t.id == id);
    if (u >= 0 && upcoming[u].mutedAt != at) upcoming[u] = upcoming[u].withMuted(at);
  }

  TripSummaryModel? get runningTrip {
    final now = TripClock.today();
    final source = upcoming.isNotEmpty || _loadedDay != null
        ? upcoming
        : (_repo.cachedList(_upcoming)?.value.items ?? const <TripSummaryModel>[]);
    for (final t in source) {
      if (!_doneIds.contains(t.id) && t.isRunningOn(now)) return t;
    }
    return null;
  }

  Future<void> ensureLoaded() {
    if (_loadedOnce) return Future.value();
    return _ensuring ??= load().whenComplete(() => _ensuring = null);
  }

  static const String _upcoming = 'upcoming';

  Future<void> load() async {
    final seq = ++_seq;
    final current = state.value;
    isLoading.value = true;
    loadFailed.value = false;
    plannerOff.value = false;
    try {
      final res = await _repo.list(page: 1, pageSize: _pageSize, state: current);
      if (seq != _seq) return;
      _loadedOnce = true;
      if (current == _upcoming) _loadedDay = _today;
      offlineCopyAt.value = null;
      counts.value = res.counts;
      items.assignAll(res.items);
      if (current == _upcoming) upcoming.assignAll(res.items);
      hasMore.value = res.hasMore;
      page = 1;
    } catch (e) {
      if (seq != _seq) return;
      if (DioErrorMapper.errorType(e) == TripErrorTypes.plannerDisabled) {
        plannerOff.value = true;
      } else if (!(e is DioException && e.response?.statusCode == 401)) {
        if (!(DioErrorMapper.isNetworkError(e) && _fromCache(current))) loadFailed.value = true;
      }
    } finally {
      if (seq == _seq) isLoading.value = false;
    }
  }

  bool _fromCache(String current) {
    final cached = _repo.cachedList(current);
    if (cached == null) return false;
    _loadedOnce = true;
    counts.value = cached.value.counts;
    items.assignAll(cached.value.items);
    if (current == _upcoming) upcoming.assignAll(cached.value.items);
    hasMore.value = false;
    page = 1;
    offlineCopyAt.value = cached.savedAt ?? DateTime.now();
    return true;
  }

  Future<void> selectState(String v) async {
    if (state.value == v) return;
    state.value = v;
    items.clear();
    hasMore.value = false;
    await load();
  }

  Future<void> loadMore() async {
    if (!hasMore.value || isLoading.value || isLoadingMore.value || offlineCopyAt.value != null) return;
    final seq = _seq;
    isLoadingMore.value = true;
    try {
      final res = await _repo.list(page: page + 1, pageSize: _pageSize, state: state.value);
      if (seq != _seq) return;
      final known = items.map((t) => t.id).toSet();
      final fresh = res.items.where((t) => known.add(t.id)).toList();
      items.addAll(fresh);
      if (state.value == _upcoming) upcoming.addAll(fresh);
      hasMore.value = res.hasMore;
      page++;
    } catch (_) {
      return;
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<bool> delete(String id) async {
    final index = items.indexWhere((t) => t.id == id);
    if (index < 0) return false;
    final removed = items.removeAt(index);
    upcoming.removeWhere((t) => t.id == id);
    _shiftCount(removed.isCompleted, -1);
    try {
      await _repo.delete(id);
      return true;
    } catch (e) {
      if (DioErrorMapper.errorType(e) == TripErrorTypes.tripNotFound) return true;
      items.insert(index.clamp(0, items.length), removed);
      if (state.value == _upcoming) upcoming.insert(index.clamp(0, upcoming.length), removed);
      _shiftCount(removed.isCompleted, 1);
      AppToast.error(DioErrorMapper.toMessage(e, "Couldn't delete the trip."));
      return false;
    }
  }

  void removeLocal(String id) {
    upcoming.removeWhere((t) => t.id == id);
    final index = items.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _shiftCount(items[index].isCompleted, -1);
    items.removeAt(index);
  }

  void _shiftCount(bool completed, int by) {
    final c = counts.value;
    counts.value = completed
        ? TripListCounts(upcoming: c.upcoming, completed: (c.completed + by).clamp(0, 1 << 30))
        : TripListCounts(upcoming: (c.upcoming + by).clamp(0, 1 << 30), completed: c.completed);
  }

  Future<bool> markComplete(String id) async {
    try {
      final trip = await _repo.complete(id);
      _doneIds.add(id);
      upcoming.removeWhere((t) => t.id == id);
      final index = items.indexWhere((t) => t.id == id);
      if (index >= 0) {
        items.removeAt(index);
        _shiftCount(false, -1);
        _shiftCount(true, 1);
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

  Future<bool> toggleMute(String id, bool muted) async {
    try {
      final trip = await _repo.mute(id, muted: muted);
      adoptMuted(id, trip.mutedAt);
      AppToast.success(trip.isMuted ? TripStrings.remindersMuted : TripStrings.remindersOn);
      return true;
    } catch (e) {
      AppToast.error(DioErrorMapper.toMessage(e, TripStrings.couldNotLoad));
      return false;
    }
  }
}
