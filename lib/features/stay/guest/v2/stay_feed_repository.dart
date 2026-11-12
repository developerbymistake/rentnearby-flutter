import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../nearby/data/nearby_repository_base.dart';
import '../../../nearby/models/nearby_models.dart';
import 'stay_feed_item.dart';

class StayFeedRepository extends NearbyRepositoryBase<StayFeedItem> {
  static const pageSize = 20;

  Future<NearbyPage<StayFeedItem>> fetch({
    required LatLng centre,
    String? stayTypeId,
    String? token,
  }) =>
      getPage(
        '/stays/feed',
        {
          'lat': centre.latitude,
          'lng': centre.longitude,
          'pageSize': pageSize,
          if (token != null) 'pageToken': token,
          if (stayTypeId != null) 'stayTypeId': stayTypeId,
        },
        StayFeedItem.fromJson,
      );
}
