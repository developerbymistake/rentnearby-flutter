import '../services/api_service.dart';

/// Fetches the real district polygon (GeoJSON `FeatureCollection`) used to
/// render and validate pin placement in Add Room/Add Plot's Location step.
/// In-memory only, keyed by district id — this is per-session boundary data,
/// not the districts/cities reference list `LocationsRepository` already
/// caches to disk.
class DistrictBoundaryRepository {
  final Map<String, Map<String, dynamic>> _memCache = {};

  Future<Map<String, dynamic>?> getBoundary(String districtId) async {
    final cached = _memCache[districtId];
    if (cached != null) return cached;
    try {
      final res = await ApiService.get('/listings/locations/districts/$districtId/boundary');
      final data = res['data'];
      if (data is! Map<String, dynamic>) return null;
      _memCache[districtId] = data;
      return data;
    } catch (_) {
      return null;
    }
  }
}
