import 'package:get/get.dart';

import '../../trip/controllers/my_trips_controller.dart';
import 'social_me_controller.dart';

abstract final class SocialLive {
  static const String hubEvent = 'SocialChanged';

  static final RxInt followers = 0.obs;
  static final RxInt followRequests = 0.obs;
  static final RxInt joinRequests = 0.obs;
  static final RxInt posts = 0.obs;

  /// Last follow change made from any FollowButton: (userId, iFollow, requested). Use trigger() so a repeat still fires.
  static final followChange = Rxn<(String, bool, bool)>();

  static void onHubEvent(List<Object?>? args) {
    final first = args == null || args.isEmpty ? null : args.first;
    final scope = first is Map ? first['scope'] : null;
    if (scope is String) onScope(scope);
  }

  static void onScope(String scope) {
    switch (scope) {
      case 'followers':
        followers.value++;
      case 'followRequests':
        followRequests.value++;
      case 'joinRequests':
      case 'myJoinRequests':
        joinRequests.value++;
      case 'posts':
        posts.value++;
      case 'limits':
        if (Get.isRegistered<MyTripsController>()) MyTripsController.to.load();
    }
    SocialMeController.maybe?.refreshQuiet();
  }

  static void reset() {
    followers.value = 0;
    followRequests.value = 0;
    joinRequests.value = 0;
    posts.value = 0;
    followChange.value = null;
  }
}
