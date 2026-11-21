import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/seeker_home/seeker_feed_api.dart';
import 'package:bakhli/features/seeker_home/seeker_feed_model.dart';

class ScriptedFeedApi extends SeekerFeedApi {
  ScriptedFeedApi(this.next);

  Future<OwnerResult<SeekerFeed>> Function() next;
  int calls = 0;

  @override
  Future<OwnerResult<SeekerFeed>> load() {
    calls++;
    return next();
  }
}
