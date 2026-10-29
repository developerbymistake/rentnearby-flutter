import '../models/home_feed_model.dart';
import '../services/api_service.dart';

class HomeRepository {
  const HomeRepository();

  Future<HomeFeedModel> fetchFeed({
    required String districtId,
    String? cityId,
    required Iterable<String> sections,
    int limit = 5,
    int recentLimit = 10,
  }) async {
    final res = await ApiService.get('/home/feed', params: {
      'districtId': districtId,
      'cityId': ?cityId,
      'limit': limit,
      'recentLimit': recentLimit,
      'sections': sections.join(','),
    });
    final data = res['data'];
    return HomeFeedModel.fromJson(data is Map<String, dynamic> ? data : const {});
  }
}
