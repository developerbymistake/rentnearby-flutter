import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../data/trip_repository.dart';
import '../models/trip_spot_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';

class TripSpotsController extends GetxController {
  final int cityKey;
  final Set<String> existingIds;

  TripSpotsController(this.cityKey, {this.existingIds = const {}});

  final _repo = const TripRepository();

  final items = <TripSpotModel>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final loadFailed = false.obs;
  final plannerOff = false.obs;
  final status = TripSpotStatus.ready.obs;
  final hasMore = false.obs;
  final total = 0.obs;
  final cityName = ''.obs;
  final selected = <String>{}.obs;
  final filter = Rxn<String>();
  String? nextCursor;
  int _seq = 0;
  bool _loadingAll = false;
  bool _moreInFlight = false;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  bool get isNotReady => status.value == TripSpotStatus.notReady;

  List<String> get categories {
    final seen = <String>{};
    return [for (final s in items) if (seen.add(s.category)) s.category];
  }

  List<TripSpotModel> get visible {
    final f = filter.value;
    return f == null ? items : items.where((s) => s.category == f).toList();
  }

  List<TripSpotModel> get chosen => items.where((s) => selected.contains(s.id)).toList();

  Future<void> load() async {
    final seq = ++_seq;
    isLoading.value = true;
    loadFailed.value = false;
    plannerOff.value = false;
    try {
      final page = await _repo.spots(cityKey);
      if (seq != _seq) return;
      items.assignAll(page.items);
      status.value = page.status;
      cityName.value = page.cityName;
      total.value = page.total;
      hasMore.value = page.hasMore;
      nextCursor = page.nextCursor;
    } catch (e) {
      if (seq != _seq) return;
      final type = DioErrorMapper.errorType(e);
      if (type == TripErrorTypes.plannerDisabled) {
        plannerOff.value = true;
      } else if (type == TripErrorTypes.cityNotFound) {
        status.value = TripSpotStatus.notReady;
      } else if (!(e is DioException && e.response?.statusCode == 401)) {
        loadFailed.value = true;
      }
    } finally {
      if (seq == _seq) isLoading.value = false;
    }
  }

  Future<bool> loadMore() async {
    if (!hasMore.value || isLoading.value || _moreInFlight) return false;
    final seq = _seq;
    _moreInFlight = true;
    isLoadingMore.value = true;
    try {
      final page = await _repo.spots(cityKey, cursor: nextCursor);
      if (seq != _seq) return false;
      final known = items.map((s) => s.id).toSet();
      items.addAll(page.items.where((s) => known.add(s.id)));
      status.value = page.status;
      total.value = page.total;
      hasMore.value = page.hasMore;
      nextCursor = page.nextCursor;
      return true;
    } catch (_) {
      return false;
    } finally {
      _moreInFlight = false;
      if (!_loadingAll) isLoadingMore.value = false;
    }
  }

  Future<void> loadAll() async {
    if (_loadingAll) return;
    _loadingAll = true;
    isLoadingMore.value = true;
    try {
      while (hasMore.value) {
        if (_moreInFlight) {
          await Future.delayed(const Duration(milliseconds: 100));
          continue;
        }
        if (!await loadMore()) break;
      }
    } finally {
      _loadingAll = false;
      isLoadingMore.value = false;
    }
  }

  void setFilter(String? c) {
    filter.value = c;
    if (c != null && hasMore.value) loadAll();
  }

  void toggle(String id) {
    if (selected.contains(id)) {
      selected.remove(id);
      return;
    }
    if (selected.length + existingIds.length >= TripConstants.maxSpots) {
      AppToast.warning(TripStrings.maxPlaces);
      return;
    }
    selected.add(id);
  }
}
