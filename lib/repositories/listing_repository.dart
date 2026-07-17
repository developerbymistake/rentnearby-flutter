import '../services/api_service.dart';

class ListingRepository {
  Map<String, Map<String, dynamic>>? _plansCache;
  DateTime? _plansCacheTime;

  static const _longTtl = Duration(minutes: 5);

  bool _isValid(DateTime? time, Duration ttl) =>
      time != null && DateTime.now().difference(time) < ttl;

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

  void invalidateAll() {
    _plansCache = null;
    _plansCacheTime = null;
  }
}
