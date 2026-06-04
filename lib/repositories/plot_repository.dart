import '../services/api_service.dart';

class PlotRepository {
  List<Map<String, dynamic>>? _plansCache;
  DateTime? _plansCacheTime;

  Map<String, dynamic>? _membershipCache;
  DateTime? _membershipCacheTime;

  static const _longTtl = Duration(minutes: 5);
  static const _shortTtl = Duration(seconds: 60);

  bool _isValid(DateTime? time, Duration ttl) =>
      time != null && DateTime.now().difference(time) < ttl;

  Future<List<Map<String, dynamic>>> getPlotPlans() async {
    if (_plansCache != null && _isValid(_plansCacheTime, _longTtl)) {
      return _plansCache!;
    }
    try {
      final res = await ApiService.get('/plots/plans');
      _plansCache = List<Map<String, dynamic>>.from((res['data'] as List?) ?? []);
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
    _plansCache = null;
    _plansCacheTime = null;
    _membershipCache = null;
    _membershipCacheTime = null;
  }
}
