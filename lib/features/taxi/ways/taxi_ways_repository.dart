import '../../../services/api_service.dart';
import 'models/taxi_ways_models.dart';

class TaxiWaysRepository {
  const TaxiWaysRepository();

  Map<String, dynamic> _data(Map<String, dynamic> res) {
    final data = res['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<TaxiWaysResult> ways({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required DateTime date,
    required int people,
    bool fromMyLocation = false,
    String? fromName,
    String? toName,
  }) async =>
      TaxiWaysResult.fromJson(_data(await ApiService.get('/taxis/ways', params: {
        'fromLat': fromLat,
        'fromLng': fromLng,
        'toLat': toLat,
        'toLng': toLng,
        'date': _date(date),
        'people': people,
        'fromMyLocation': ?(fromMyLocation ? 'true' : null),
        'fromName': ?fromName,
        'toName': ?toName,
      })));

  Future<WayPlanDetail> plan(
    String planKey, {
    required int people,
    DateTime? date,
    String? fromName,
    String? toName,
  }) async =>
      WayPlan.fromJson(_data(await ApiService.get(
        '/taxis/ways/plans/${Uri.encodeComponent(planKey)}',
        params: {
          'people': people,
          'date': ?(date == null ? null : _date(date)),
          'fromName': ?_name(fromName),
          'toName': ?_name(toName),
        },
      )));

  static String? _name(String? n) {
    final t = n?.trim() ?? '';
    return t.isEmpty ? null : (t.length > 80 ? t.substring(0, 80) : t);
  }

  Future<WayDriverPage> legDrivers(
    String legKey, {
    required int people,
    int? minSeats,
    String? category,
    bool repliesInApp = false,
    String sort = 'bestFit',
    int page = 1,
    int pageSize = 8,
  }) async {
    final data = _data(await ApiService.get(
      '/taxis/ways/legs/${Uri.encodeComponent(legKey)}/drivers',
      params: {
        'people': people,
        'minSeats': ?minSeats,
        'category': ?category,
        'repliesInApp': ?(repliesInApp ? 'true' : null),
        'sort': sort,
        'page': page,
        'pageSize': pageSize,
      },
    ));
    final list = data['items'];
    final items = list is List
        ? list.whereType<Map<String, dynamic>>().map(WayDriver.fromJson).toList()
        : <WayDriver>[];
    return (
      items: items,
      hasMore: data['hasMore'] == true,
      total: (data['total'] as num?)?.toInt() ?? items.length,
    );
  }
}
