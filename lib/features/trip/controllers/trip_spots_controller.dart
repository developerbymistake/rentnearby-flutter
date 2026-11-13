import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../data/trip_repository.dart';
import '../models/trip_spot_model.dart';
import '../trip_constants.dart';
import '../trip_strings_mca_a2.dart';
import '../utils/trip_spot_picks.dart';
import '../utils/trip_spots_cache.dart';

class TripSpotsController extends GetxController {
  final int cityKey;
  final Set<String> existingIds;
  final int otherSpots;

  TripSpotsController(this.cityKey, {this.existingIds = const {}, this.otherSpots = 0});

  final _repo = const TripRepository();

  final items = <TripSpotModel>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final loadFailed = false.obs;
  final plannerOff = false.obs;
  final loadError = ''.obs;
  final status = TripSpotStatus.ready.obs;
  final hasMore = false.obs;
  final total = 0.obs;
  final cityName = ''.obs;
  final selected = <String>{}.obs;
  final filter = Rxn<String>();
  final limit = (-1).obs;
  final offline = false.obs;
  final minutesTick = 0.obs;
  final suggestion = Rxn<({String forId, TripNearby nearby})>();
  final book = TripMinutesBook();
  final _suggested = <String>{};
  final _askedMinutes = <String>{};
  bool _minutesOff = false;
  Worker? _routeWorker;
  String? nextCursor;
  int _seq = 0;
  bool _loadingAll = false;
  bool _moreInFlight = false;

  @override
  void onInit() {
    super.onInit();
    _routeWorker = debounce(selected, (_) => _syncRoute(), time: const Duration(milliseconds: 400));
    load();
  }

  @override
  void onClose() {
    _routeWorker?.dispose();
    super.onClose();
  }

  List<TripSpotModel> get mustSee => TripSpotPicks.mustSee(items);


  TripRouteEstimate? get route {
    minutesTick.value;
    return TripSpotPicks.route(chosen, book);
  }

  Future<void> _fetchMinutes(List<String> ids) async {
    final list = ids.toSet().take(TripSpotPicks.minutesMax).toList();
    if (_minutesOff || list.length < 2) return;
    final key = (list.toList()..sort()).join(',');
    if (!_askedMinutes.add(key)) return;
    try {
      final m = await _repo.spotMinutes(cityKey, list);
      if (m == null) {
        _minutesOff = true;
        return;
      }
      book.put(m);
      minutesTick.value++;
    } catch (_) {
      _askedMinutes.remove(key);
    }
  }

  void _syncRoute() {
    final ids = selected.toList();
    if (ids.length >= 2 && ids.length <= TripSpotPicks.minutesMax) _fetchMinutes(ids);
  }

  Future<void> _suggestFor(String id) async {
    if (!_suggested.add(id)) return;
    final from = items.firstWhereOrNull((s) => s.id == id);
    if (from == null) return;
    final pool = items.where((s) => !selected.contains(s.id) && !existingIds.contains(s.id)).toList();
    final near = TripSpotPicks.candidatesNear(from, pool);
    if (near.isEmpty) return;
    await _fetchMinutes([id, ...near.map((s) => s.id)]);
    if (!selected.contains(id) || atLimit || selected.length + existingIds.length + otherSpots >= TripConstants.maxSpots) return;
    final left = near.where((s) => !selected.contains(s.id)).toList();
    final n = TripSpotPicks.nearest(from, left, book);
    suggestion.value = n == null ? null : (forId: id, nearby: n);
  }

  void dismissSuggestion() => suggestion.value = null;

  bool get isNotReady => status.value == TripSpotStatus.notReady;

  List<String> get categories {
    final seen = <String>{};
    return [for (final s in items) if (seen.add(s.category)) s.category];
  }

  List<TripSpotModel> get visible {
    final f = filter.value;
    return TripSpotModel.photoFirst(f == null ? items.toList() : items.where((s) => s.category == f).toList());
  }

  bool get atLimit => limit.value >= 0 && selected.length >= limit.value;

  List<TripSpotModel> get chosen => items.where((s) => selected.contains(s.id)).toList();

  Future<void> load() async {
    final seq = ++_seq;
    isLoading.value = true;
    loadFailed.value = false;
    loadError.value = '';
    plannerOff.value = false;
    try {
      final page = await _repo.spots(cityKey);
      if (seq != _seq) return;
      items.assignAll(page.items);
      offline.value = false;
      _saveCache(page);
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
      } else if (items.isEmpty && _useCache()) {
        offline.value = true;
      } else if (!(e is DioException && e.response?.statusCode == 401)) {
        loadFailed.value = true;
        loadError.value = DioErrorMapper.isNetworkError(e) ? '' : DioErrorMapper.toMessage(e, '');
      }
    } finally {
      if (seq == _seq) isLoading.value = false;
    }
  }

  void _saveCache(TripSpotsPage page) {
    if (page.isNotReady || page.items.isEmpty) return;
    try {
      TripSpotsCache.save(cityKey, page.items);
    } catch (_) {}
  }

  bool _useCache() {
    List<TripSpotModel>? cached;
    try {
      cached = TripSpotsCache.load(cityKey);
    } catch (_) {
      return false;
    }
    if (cached == null || cached.isEmpty) return false;
    items.assignAll(cached);
    status.value = TripSpotStatus.ready;
    total.value = cached.length;
    hasMore.value = false;
    nextCursor = null;
    return true;
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

  // Picks restored from a saved draft may sit on a page that is not loaded yet.
  Future<void> ensureSelectedLoaded() async {
    while (isLoading.value) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    while (hasMore.value && selected.any((id) => !items.any((s) => s.id == id))) {
      if (_moreInFlight) {
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }
      if (!await loadMore()) break;
    }
  }

  void setFilter(String? c) {
    filter.value = c;
    if (c != null && hasMore.value) loadAll();
  }

  bool toggle(String id) {
    if (selected.contains(id)) {
      selected.remove(id);
      if (suggestion.value?.forId == id) suggestion.value = null;
      return true;
    }
    if (atLimit) return false;
    if (selected.length + existingIds.length + otherSpots >= TripConstants.maxSpots) {
      AppToast.warning(TripStringsMcaA2.maxPlaces);
      return false;
    }
    selected.add(id);
    suggestion.value = null;
    _suggestFor(id);
    return true;
  }
}
