import '../services/api_service.dart';
import '../utils/ttl_cache.dart';

/// Thin TTL-caching wrapper around GET /config/listing-limits — anonymous,
/// admin-managed, rarely-changing reference data (the flat per-user
/// room/plot listing-creation cap). Long TTL since it almost never changes;
/// mirrors ListingRepository's caching style.
class ConfigRepository {
  ({int roomLimit, int plotLimit})? _cache;
  DateTime? _cacheTime;
  static const _ttl = Duration(hours: 1);

  bool get _isValid => _cache != null && isCacheValid(_cacheTime, _ttl);

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

  ({bool enabled, int freeGoLiveDurationDays})? _paymentCache;
  DateTime? _paymentCacheTime;
  static const _paymentTtl = Duration(minutes: 5);

  bool get _isPaymentCacheValid =>
      _paymentCache != null && isCacheValid(_paymentCacheTime, _paymentTtl);

  /// GET /config/payment-feature — anonymous, admin-managed kill switch for
  /// the entire credit/payment economy. Unlike getListingLimits() above, this
  /// must fail toward payment-required (enabled: true) on any parse/network
  /// error — a slow or failed fetch should never silently hide payment UI
  /// from users who should still see it. Kept on its own, much shorter TTL
  /// since an admin flipping this switch is expected to take effect quickly,
  /// not the "almost never changes" assumption behind the 1h listing-limits
  /// cache above.
  Future<({bool enabled, int freeGoLiveDurationDays})> getPaymentFeature() async {
    if (_isPaymentCacheValid) return _paymentCache!;
    try {
      final res = await ApiService.get('/config/payment-feature');
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final result = (
        enabled: data['enabled'] as bool? ?? true,
        freeGoLiveDurationDays: (data['freeGoLiveDurationDays'] as num?)?.toInt() ?? 30,
      );
      _paymentCache = result;
      _paymentCacheTime = DateTime.now();
      return result;
    } catch (_) {
      return _paymentCache ?? (enabled: true, freeGoLiveDurationDays: 30);
    }
  }
}
