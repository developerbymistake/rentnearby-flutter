import '../../../services/api_service.dart';
import '../models/taxi_browse_item.dart';
import '../models/taxi_detail_model.dart';

typedef TaxiBrowsePage = ({List<TaxiBrowseItem> items, bool hasMore});

class TaxiBrowseRepository {
  const TaxiBrowseRepository();

  Map<String, dynamic> _data(Map<String, dynamic> res) {
    final data = res['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  TaxiBrowsePage _page(Map<String, dynamic> res) {
    final data = _data(res);
    final list = (data['items'] as List?) ?? const [];
    return (
      items: list.map((e) => TaxiBrowseItem.fromJson(e as Map<String, dynamic>)).toList(),
      hasMore: data['hasMore'] == true,
    );
  }

  Future<TaxiBrowsePage> browseLocal({
    required String districtId,
    String? cityId,
    String? category,
    int page = 1,
    int pageSize = 20,
  }) async =>
      _page(await ApiService.get('/taxis/browse', params: {
        'districtId': districtId,
        if (cityId != null) 'cityId': cityId,
        if (category != null) 'category': category,
        'page': page,
        'pageSize': pageSize,
      }));

  Future<TaxiBrowsePage> search({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String? category,
    int page = 1,
    int pageSize = 20,
  }) async =>
      _page(await ApiService.get('/taxis/search', params: {
        'fromLat': fromLat,
        'fromLng': fromLng,
        'toLat': toLat,
        'toLng': toLng,
        if (category != null) 'category': category,
        'page': page,
        'pageSize': pageSize,
      }));

  Future<TaxiDetailModel> getById(String id) async =>
      TaxiDetailModel.fromJson(_data(await ApiService.get('/taxis/$id')));
}
