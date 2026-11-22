import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:get/get.dart';
import '../../../config/app_constants.dart';
import '../../../services/storage_service.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../utils/network_retry.dart';
import '../../map_discovery/data/map_pack_service.dart';
import '../models/trip_city_model.dart';
import '../trip_constants.dart';
import 'trip_repository.dart';

class TripCityCatalog {
  static TripCityCatalog get to =>
      Get.isRegistered<TripCityCatalog>() ? Get.find<TripCityCatalog>() : Get.put(TripCityCatalog(), permanent: true);

  final _repo = const TripRepository();

  List<TripCityModel>? _mem;
  String? _version;
  String? _firstPageTag;
  DateTime? _checkedAt;
  Future<List<TripCityModel>>? _loading;

  @visibleForTesting
  void seedForTest(List<TripCityModel> cities) {
    _mem = cities;
    _version = 'test';
    _checkedAt = DateTime.now();
  }

  void warmFromDisk() {
    if (_mem != null) return;
    final raw = StorageService.getTripCitiesCache();
    if (raw == null) return;
    if (raw.isNotEmpty && !(raw.first.containsKey('isPopularDestination') && raw.first.containsKey('coverUrl'))) return;
    try {
      _mem = raw.map(TripCityModel.fromJson).toList();
      _version = StorageService.getTripCitiesCacheVersion();
    } catch (_) {
      _mem = null;
      _version = null;
    }
  }

  Future<List<TripCityModel>> load({bool force = false}) {
    final pending = _loading;
    if (pending != null) return pending;
    final f = _load(force);
    _loading = f;
    return f.whenComplete(() {
      if (identical(_loading, f)) _loading = null;
    });
  }

  List<TripCityModel> search(String q) {
    final found = TripCitySearch.filter(_mem ?? const [], q);
    return q.trim().isEmpty ? TripCitySearch.popularFirst(found) : found;
  }

  static const int searchCap = 60;

  List<TripCityModel> ready(String q, {String? stateName}) {
    final state = stateName?.trim().toLowerCase() ?? '';
    final out = <TripCityModel>[];
    for (final c in search(q)) {
      if (!c.isReady) continue;
      if (state.isNotEmpty && c.stateName.toLowerCase() != state) continue;
      out.add(c);
      if (out.length >= searchCap && q.trim().isNotEmpty) break;
    }
    return out;
  }

  List<String> liveStates() {
    final seen = <String>{};
    final out = <String>[];
    for (final c in _mem ?? const <TripCityModel>[]) {
      final s = c.stateName.trim();
      if (c.isReady && s.isNotEmpty && seen.add(s.toLowerCase())) out.add(s);
    }
    out.sort();
    return out;
  }

  bool get hasData => _mem != null;

  // Changes identity whenever the city list is replaced; callers memoise derived lists on it.
  Object? get dataKey => _mem;

  List<TripCityModel> popular({String? stateName}) {
    final state = stateName?.trim().toLowerCase();
    return [
      for (final c in _mem ?? const <TripCityModel>[])
        if (c.isReady && c.isPopularDestination && (state == null || state.isEmpty || c.stateName.toLowerCase() == state)) c,
    ];
  }

  Future<List<TripCityModel>> _load(bool force) async {
    warmFromDisk();
    final mem = _mem;
    final now = DateTime.now();
    final checkedAt = _checkedAt;
    if (!force && mem != null && checkedAt != null && now.difference(checkedAt) < AppConstants.tripCitiesRevalidateAfter) {
      return mem;
    }
    final savedAt = StorageService.getTripCitiesCacheSavedAt();
    final fresh = mem != null && savedAt != null && now.difference(savedAt) < AppConstants.tripCitiesCacheTtl;
    if (fresh && !force) {
      try {
        final v = await _repo.citiesVersion(once: true);
        MapPackService.to.onVersion(v);
        if (v.version == _version) {
          _checkedAt = DateTime.now();
          await StorageService.touchTripCitiesCache();
          return mem;
        }
      } catch (e) {
        if (!DioErrorMapper.isNetworkError(e)) rethrow;
        _checkedAt = DateTime.now();
        return mem;
      }
    }
    return _fetchAll();
  }

  Future<List<TripCityModel>> _fetchAll() async {
    final once = _mem == null;
    try {
      final mem = _mem;
      final tag = _firstPageTag;
      TripCityPage? first;
      String? firstTag;
      if (mem != null && tag != null) {
        final r = await withRetry(() => _repo.citiesFirstPage(etag: tag), once: once);
        if (r.page == null) {
          _checkedAt = DateTime.now();
          await StorageService.touchTripCitiesCache();
          return mem;
        }
        first = r.page;
        firstTag = r.etag;
      }
      final items = <TripCityModel>[];
      var version = '';
      var page = 1;
      var restarted = false;
      while (true) {
        final TripCityPage p;
        if (page == 1 && first != null) {
          p = first;
          first = null;
        } else if (page == 1) {
          final r = await withRetry(() => _repo.citiesFirstPage(etag: null), once: once);
          p = r.page!;
          firstTag = r.etag;
        } else {
          p = await _repo.cities(page: page, pageSize: TripConstants.citiesPageSize, once: once);
        }
        if (page > 1 && p.version != version && !restarted) {
          restarted = true;
          items.clear();
          page = 1;
          continue;
        }
        version = p.version;
        items.addAll(p.items);
        if (!p.hasMore || page >= TripConstants.citiesMaxPages) break;
        page++;
      }
      final list = TripCitySearch.dedupe(items);
      _mem = list;
      _version = version;
      _firstPageTag = firstTag;
      _checkedAt = DateTime.now();
      await StorageService.saveTripCitiesCache(list.map((c) => c.toJson()).toList(), version);
      return list;
    } catch (e) {
      final mem = _mem;
      if (mem != null && DioErrorMapper.isNetworkError(e)) return mem;
      rethrow;
    }
  }
}
