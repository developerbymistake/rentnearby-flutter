import '../services/api_service.dart';

class PlotRepository {
  Map<String, dynamic>? _featureConfigCache;
  DateTime? _featureConfigCacheTime;

  List<Map<String, dynamic>>? _plansCache;
  DateTime? _plansCacheTime;

  Map<String, dynamic>? _membershipCache;
  DateTime? _membershipCacheTime;

  static const _longTtl = Duration(minutes: 5);
  static const _shortTtl = Duration(seconds: 60);

  bool _isValid(DateTime? time, Duration ttl) =>
      time != null && DateTime.now().difference(time) < ttl;

  Future<Map<String, dynamic>> getPlotPaymentFeatureConfig() async {
    if (_featureConfigCache != null &&
        _isValid(_featureConfigCacheTime, _longTtl)) {
      return _featureConfigCache!;
    }
    try {
      final res = await ApiService.get('/admin/features/plot_payment');
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

  Future<List<Map<String, dynamic>>> getPlotPlans() async {
    if (_plansCache != null && _isValid(_plansCacheTime, _longTtl)) {
      return _plansCache!;
    }
    try {
      final res = await ApiService.get('/plots/plans');
      _plansCache = List<Map<String, dynamic>>.from(res['data'] ?? []);
      _plansCacheTime = DateTime.now();
      return _plansCache!;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getPlotMembershipStatus() async {
    if (_membershipCache != null &&
        _isValid(_membershipCacheTime, _shortTtl)) {
      return _membershipCache;
    }
    try {
      final res = await ApiService.get('/plots/payment/status');
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
