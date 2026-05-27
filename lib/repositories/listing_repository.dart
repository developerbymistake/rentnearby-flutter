import '../services/api_service.dart';

class ListingRepository {
  Map<String, dynamic>? _featureConfigCache;
  DateTime? _featureConfigCacheTime;

  Map<String, Map<String, dynamic>>? _plansCache;
  DateTime? _plansCacheTime;

  Map<String, dynamic>? _membershipCache;
  DateTime? _membershipCacheTime;

  static const _longTtl = Duration(minutes: 5);
  static const _shortTtl = Duration(seconds: 60);

  bool _isValid(DateTime? time, Duration ttl) =>
      time != null && DateTime.now().difference(time) < ttl;

  Future<Map<String, dynamic>> getPaymentFeatureConfig() async {
    if (_featureConfigCache != null &&
        _isValid(_featureConfigCacheTime, _longTtl)) {
      return _featureConfigCache!;
    }
    try {
      final res = await ApiService.get('/admin/features/room_payment');
      final data = res['data'];
      if (data != null && data is Map<String, dynamic>) {
        _featureConfigCache = {
          'isEnabled': data['isEnabled'] == true,
          'freeLimit': (data['freeLimit'] as num?)?.toInt() ?? 1,
          'freeDays': (data['freeDays'] as num?)?.toInt() ?? 2,
        };
        _featureConfigCacheTime = DateTime.now();
        return _featureConfigCache!;
      }
    } catch (_) {}
    return {'isEnabled': false, 'freeLimit': 1, 'freeDays': 2};
  }

  Future<Map<String, Map<String, dynamic>>> getPlans() async {
    if (_plansCache != null && _isValid(_plansCacheTime, _longTtl)) {
      return _plansCache!;
    }
    try {
      final res = await ApiService.get('/listings/plans');
      final list = res['data'] as List;
      final result = <String, Map<String, dynamic>>{};
      for (final item in list) {
        final p = Map<String, dynamic>.from(item as Map);
        result[p['planType'] as String] = p;
      }
      _plansCache = result;
      _plansCacheTime = DateTime.now();
      return _plansCache!;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>?> getMembershipStatus() async {
    if (_membershipCache != null &&
        _isValid(_membershipCacheTime, _shortTtl)) {
      return _membershipCache;
    }
    try {
      final res = await ApiService.get('/listings/payment/status');
      _membershipCache = res['data'] as Map<String, dynamic>?;
      _membershipCacheTime = DateTime.now();
      return _membershipCache;
    } catch (_) {
      return null;
    }
  }

  void invalidateMembership() {
    _membershipCache = null;
    _membershipCacheTime = null;
  }

  void invalidateAll() {
    _featureConfigCache = null;
    _featureConfigCacheTime = null;
    _plansCache = null;
    _plansCacheTime = null;
    _membershipCache = null;
    _membershipCacheTime = null;
  }
}
