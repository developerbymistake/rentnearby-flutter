import '../services/api_service.dart';

/// Thin TTL-caching wrapper around GET /config/listing-limits — anonymous,
/// admin-managed, rarely-changing reference data (the flat per-user
/// room/plot listing-creation cap). Long TTL since it almost never changes;
/// mirrors ListingRepository's caching style.
class ConfigRepository {
  ({int roomLimit, int plotLimit})? _cache;
  DateTime? _cacheTime;
  static const _ttl = Duration(hours: 1);

  bool get _isValid =>
      _cache != null && _cacheTime != null && DateTime.now().difference(_cacheTime!) < _ttl;

  Future<({int roomLimit, int plotLimit})> getListingLimits() async {
    if (_isValid) return _cache!;
    try {
      final res = await ApiService.get('/config/listing-limits');
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final result = (
        roomLimit: (data['roomLimit'] as num?)?.toInt() ?? 5,
        plotLimit: (data['plotLimit'] as num?)?.toInt() ?? 5,
      );
      _cache = result;
      _cacheTime = DateTime.now();
      return result;
    } catch (_) {
      return _cache ?? (roomLimit: 5, plotLimit: 5);
    }
  }
}
