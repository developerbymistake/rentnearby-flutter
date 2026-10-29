import '../../../models/browse_item.dart';
import '../../../services/api_service.dart';
import '../models/stay_browse_item.dart';

class StayBrowseRepository {
  Future<BrowsePage> fetch({
    required String districtId,
    String? cityId,
    String? meals,
    String? stayTypeId,
    required String sortBy,
    String? cursor,
    int page = 1,
    required int pageSize,
  }) async {
    final res = await ApiService.get(
      '/stays/browse',
      params: {
        'districtId': districtId,
        if (cityId != null) 'cityId': cityId,
        if (meals != null) 'meals': meals,
        if (stayTypeId != null) 'stayTypeId': stayTypeId,
        'sortBy': sortBy,
        if (cursor != null) 'cursor': cursor else 'page': page,
        'pageSize': pageSize,
      },
    );
    final data = res['data'] as Map<String, dynamic>? ?? const {};
    final list = (data['items'] as List?) ?? const [];
    return BrowsePage(
      items: list.map((e) => StayBrowseItem.fromJson(e as Map<String, dynamic>)).toList(),
      hasMore: data['hasMore'] == true,
      nextCursor: data['nextCursor'] as String?,
    );
  }
}
