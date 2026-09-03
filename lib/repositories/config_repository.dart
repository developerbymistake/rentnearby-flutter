import '../models/app_tab_config_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
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

  List<AppTabConfigModel>? _appTabsCache;
  DateTime? _appTabsCacheTime;
  static const _appTabsTtl = Duration(minutes: 5);

  bool get _isAppTabsCacheValid =>
      _appTabsCache != null && isCacheValid(_appTabsCacheTime, _appTabsTtl);

  /// GET /config/app-tabs — anonymous, admin-managed master list of the 5 bottom-nav tabs
  /// (TabConfigController is the one caller; MainScreen fetches this before deciding which
  /// tab-scoped controllers/hubs to connect). Fails toward "everything active" on any
  /// parse/network error or missing row — same fail-open polarity as the backend's own
  /// ConfigHandlers.IsTabActiveCachedAsync, so a network hiccup can never silently hide a real
  /// tab. forceRefresh bypasses the TTL — used on app-resume so a live admin change is picked
  /// up promptly rather than waiting out the cache.
  Future<List<AppTabConfigModel>> getAppTabs({bool forceRefresh = false}) async {
    if (!forceRefresh && _isAppTabsCacheValid) return _appTabsCache!;
    try {
      final res = await ApiService.get('/config/app-tabs');
      final data = res['data'] as List? ?? [];
      final result = data.map((e) => AppTabConfigModel.fromJson(e)).toList();
      _appTabsCache = result;
      _appTabsCacheTime = DateTime.now();
      StorageService.saveAppTabsCache(
        data.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
      return result;
    } catch (_) {
      return _appTabsCache ?? [];
    }
  }

  /// Synchronous — reads back the last successfully-persisted app-tabs response so
  /// TabConfigController.onInit() can seed its state before the first frame, without waiting
  /// on the network. Returns null if nothing has ever been persisted (first-ever launch).
  List<AppTabConfigModel>? getPersistedAppTabs() {
    final raw = StorageService.getAppTabsCache();
    if (raw == null) return null;
    try {
      return raw.map((e) => AppTabConfigModel.fromJson(e)).toList();
    } catch (_) {
      return null;
    }
  }
}
