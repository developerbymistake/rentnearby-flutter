import '../owner_core/data/owner_api.dart';
import '../owner_core/data/owner_result.dart';
import 'seeker_feed_model.dart';

class SeekerFeedApi {
  const SeekerFeedApi();

  static const String path = '/home/seeker-feed';

  Future<OwnerResult<SeekerFeed>> load() => OwnerApi.get(path, SeekerFeed.fromJson);
}
