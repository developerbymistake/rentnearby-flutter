import 'package:get/get.dart';

import '../../../buddy/shared/buddy_result.dart';
import '../../shared/social_live.dart';
import '../../shared/social_models.dart';
import '../data/public_trips_api.dart';
import 'travel_buddies_controller.dart';

class MyPostsController extends GetxController {
  MyPostsController({PublicTripsApi api = const PublicTripsApi()}) : _api = api;

  final PublicTripsApi _api;

  final state = FeedLoad.loading.obs;
  final items = <PublicTrip>[].obs;
  int _gen = 0;
  final _workers = <Worker>[];

  @override
  void onInit() {
    super.onInit();
    _workers.add(ever<int>(SocialLive.posts, (_) => load()));
    _workers.add(ever<int>(SocialLive.joinRequests, (_) => load()));
    load();
  }

  Future<void> load() async {
    final gen = ++_gen;
    if (items.isEmpty) state.value = FeedLoad.loading;
    final r = await _api.mine();
    if (gen != _gen) return;
    switch (r) {
      case BuddyOk<List<PublicTrip>>(:final value):
        items.assignAll(value);
        state.value = FeedLoad.ready;
      case BuddyOffline():
        if (items.isEmpty) state.value = FeedLoad.offline;
      case BuddyRefused() || BuddyFailed():
        if (items.isEmpty) state.value = FeedLoad.failed;
    }
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }
}
