import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../data/trip_repository.dart';
import '../models/trip_model.dart';
import '../trip_strings.dart';

class MyTripsController extends GetxController {
  static MyTripsController get to =>
      Get.isRegistered<MyTripsController>() ? Get.find<MyTripsController>() : Get.put(MyTripsController());

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
  int page = 1;
  int _seq = 0;

  Future<void> load() async {
    final seq = ++_seq;
    isLoading.value = true;
    loadFailed.value = false;
    plannerOff.value = false;
    try {
      final res = await _repo.list(page: 1, pageSize: _pageSize, state: state.value);
      if (seq != _seq) return;
      counts.value = res.counts;
      items.assignAll(res.items);
      hasMore.value = res.hasMore;
      page = 1;
    } catch (e) {
      if (seq != _seq) return;
      if (DioErrorMapper.errorType(e) == TripErrorTypes.plannerDisabled) {
        plannerOff.value = true;
      } else if (!(e is DioException && e.response?.statusCode == 401)) {
        loadFailed.value = true;
      }
    } finally {
      if (seq == _seq) isLoading.value = false;
    }
  }

  Future<void> selectState(String v) async {
    if (state.value == v) return;
    state.value = v;
    items.clear();
    hasMore.value = false;
    await load();
  }

  Future<void> loadMore() async {
    if (!hasMore.value || isLoading.value || isLoadingMore.value) return;
    final seq = _seq;
    isLoadingMore.value = true;
    try {
      final res = await _repo.list(page: page + 1, pageSize: _pageSize, state: state.value);
      if (seq != _seq) return;
      final known = items.map((t) => t.id).toSet();
      items.addAll(res.items.where((t) => known.add(t.id)));
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
    _shiftCount(removed.isCompleted, -1);
    try {
      await _repo.delete(id);
      return true;
    } catch (e) {
      if (DioErrorMapper.errorType(e) == TripErrorTypes.tripNotFound) return true;
      items.insert(index.clamp(0, items.length), removed);
      _shiftCount(removed.isCompleted, 1);
      AppToast.error(DioErrorMapper.toMessage(e, "Couldn't delete the trip."));
      return false;
    }
  }

  void removeLocal(String id) {
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
      final index = items.indexWhere((t) => t.id == id);
      if (index >= 0) items[index] = items[index].withMuted(trip.mutedAt);
      AppToast.success(trip.isMuted ? TripStrings.remindersMuted : TripStrings.remindersOn);
      return true;
    } catch (e) {
      AppToast.error(DioErrorMapper.toMessage(e, TripStrings.couldNotLoad));
      return false;
    }
  }
}
