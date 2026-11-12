import '../features/nearby/controllers/nearby_centre_controller.dart';
import '../models/home_feed_model.dart';
import '../models/home_feed_model_v2.dart';
import '../services/api_service.dart';

class HomeRepositoryV2 {
  const HomeRepositoryV2();

  Future<HomeFeedModel> fetchFeed({
    required String districtId,
    String? cityId,
    required Iterable<String> sections,
    int limit = 5,
    int recentLimit = 10,
  }) async {
    final centre = NearbyCentreController.to.centre;
    final res = await ApiService.get('/home/nearby-feed', params: {
      'lat': centre.latitude,
      'lng': centre.longitude,
      'limit': limit,
      'recentLimit': recentLimit,
      'sections': sections.join(','),
    });
    final data = res['data'];
    return HomeFeedModelV2.fromJson(data is Map<String, dynamic> ? data : const {});
  }
}
