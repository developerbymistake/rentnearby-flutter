import '../config/app_constants.dart';
import '../models/city_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Fetches and caches the states/districts/cities reference data used by the
/// location-switch picker. This is pure reference data (admin-managed, rarely
/// changes) — cached in-memory for the session and on-disk across app
/// restarts. It is unrelated to (and never stores) which district/city the
/// user is currently browsing.
class LocationsRepository {
  List<DistrictModel>? _districtsMemCache;
  final Map<String, List<CityModel>> _citiesMemCache = {};

  bool _isFresh(DateTime? savedAt) =>
      savedAt != null && DateTime.now().difference(savedAt) < AppConstants.locationsCacheTtl;

  Future<List<DistrictModel>> getAllDistricts({bool forceRefresh = false}) async {
    if (!forceRefresh && _districtsMemCache != null) return _districtsMemCache!;

    if (!forceRefresh && _isFresh(StorageService.getDistrictsCacheSavedAt())) {
      final cached = StorageService.getDistrictsCache();
      if (cached != null) {
        final items = cached.map(DistrictModel.fromJson).toList();
        _districtsMemCache = items;
        return items;
      }
    }

    try {
      final res = await ApiService.get('/listings/locations/districts');
      final items = (res['data'] as List)
          .map((e) => DistrictModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _districtsMemCache = items;
      await StorageService.saveDistrictsCache(items.map((d) => d.toJson()).toList());
      return items;
    } catch (e) {
      // Network failed right as the TTL expired — a stale copy on disk is
      // still far more useful than a hard error for reference data that
      // rarely changes.
      final stale = StorageService.getDistrictsCache();
      if (stale != null) {
        final items = stale.map(DistrictModel.fromJson).toList();
        _districtsMemCache = items;
        return items;
      }
      rethrow;
    }
  }

  Future<List<CityModel>> getCitiesForDistrict(String districtId, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final memCached = _citiesMemCache[districtId];
      if (memCached != null) return memCached;

      if (_isFresh(StorageService.getCitiesCacheSavedAt(districtId))) {
        final cached = StorageService.getCitiesCache(districtId);
        if (cached != null) {
          final items = cached.map(CityModel.fromJson).toList();
          _citiesMemCache[districtId] = items;
          return items;
        }
      }
    }

    try {
      final res = await ApiService.get('/listings/locations/cities', params: {'districtId': districtId});
      final items = (res['data'] as List)
          .map((e) => CityModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _citiesMemCache[districtId] = items;
      await StorageService.saveCitiesCache(districtId, items.map((c) => c.toJson()).toList());
      return items;
    } catch (e) {
      final stale = StorageService.getCitiesCache(districtId);
      if (stale != null) {
        final items = stale.map(CityModel.fromJson).toList();
        _citiesMemCache[districtId] = items;
        return items;
      }
      rethrow;
    }
  }

  /// Unique state names across all districts, alphabetically sorted.
  List<String> statesFrom(List<DistrictModel> districts) {
    final seen = <String>{};
    final states = <String>[];
    for (final d in districts) {
      final s = d.stateName;
      if (s != null && s.isNotEmpty && seen.add(s)) states.add(s);
    }
    states.sort();
    return states;
  }
}
