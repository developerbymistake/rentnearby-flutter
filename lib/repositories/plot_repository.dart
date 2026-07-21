import '../services/api_service.dart';
import '../utils/ttl_cache.dart';

class PlotRepository {
  List<Map<String, dynamic>>? _plansCache;
  DateTime? _plansCacheTime;

  static const _longTtl = Duration(minutes: 5);

  Future<List<Map<String, dynamic>>> getPlotPlans() async {
    if (_plansCache != null && isCacheValid(_plansCacheTime, _longTtl)) {
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
