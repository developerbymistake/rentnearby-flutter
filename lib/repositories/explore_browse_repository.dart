import '../models/browse_item.dart';
import '../models/explore_kind.dart';
import '../services/api_service.dart';

class ExploreBrowseRepository {
  Future<BrowsePage> fetch(
    ExploreKind kind, {
    required String districtId,
    String? cityId,
    String? typeId,
    required String sortBy,
    String? cursor,
    int page = 1,
    required int pageSize,
  }) async {
    final isRooms = kind == ExploreKind.rooms;
    final res = await ApiService.get(
      isRooms ? '/home/rooms/browse' : '/home/plots/browse',
      params: {
        'districtId': districtId,
        if (cityId != null) 'cityId': cityId,
        if (typeId != null) (isRooms ? 'roomTypeId' : 'plotTypeId'): typeId,
        'sortBy': sortBy,
        if (cursor != null) 'cursor': cursor else 'page': page,
        'pageSize': pageSize,
      },
    );
    final data = res['data'] as Map<String, dynamic>? ?? const {};
    final list = (data['items'] as List?) ?? const [];
    final parse = isRooms ? BrowseItem.fromRoomJson : BrowseItem.fromPlotJson;
    return BrowsePage(
      items: list.map((e) => parse(e as Map<String, dynamic>)).toList(),
      hasMore: data['hasMore'] == true,
      nextCursor: data['nextCursor'] as String?,
    );
  }
}
