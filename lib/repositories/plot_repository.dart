import '../services/api_service.dart';

class PlotRepository {
  List<Map<String, dynamic>>? _plansCache;
  DateTime? _plansCacheTime;

  static const _longTtl = Duration(minutes: 5);

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

  void invalidateAll() {
    _plansCache = null;
    _plansCacheTime = null;
  }
}
