import 'package:get/get.dart';

import '../../../buddy/shared/buddy_result.dart';
import '../../shared/post_removal.dart';
import '../../shared/social_error_types.dart';
import '../../shared/social_live.dart';
import '../../shared/social_models.dart';
import '../data/public_trips_api.dart';
import 'feed_filter_sheet.dart';

enum FeedLoad { loading, ready, offline, failed }

class TravelBuddiesController extends GetxController {
  TravelBuddiesController({PublicTripsApi api = const PublicTripsApi()}) : _api = api;

  final PublicTripsApi _api;

  final state = FeedLoad.loading.obs;
  final mine = <PublicTrip>[].obs;
  final items = <PublicTrip>[].obs;
  final filter = FeedFilter.none.obs;
  final loadingMore = false.obs;
  final nearFailed = RxnString();
  String? _cursor;
  double? _lat;
  double? _lng;
  int _gen = 0;
  int _headGen = 0;
  final _workers = <Worker>[];

  bool get hasMore => _cursor != null;

  @override
  void onInit() {
    super.onInit();
    _workers.add(ever<int>(SocialLive.posts, (_) => load()));
    _workers.add(ever<int>(SocialLive.joinRequests, (_) => refreshHead()));
    load();
  }

  void setLocation(double? lat, double? lng) {
    _lat = lat;
    _lng = lng;
  }

  Future<void> applyFilter(FeedFilter f) async {
    if (f == filter.value) return;
    filter.value = f;
    await load();
  }

  Future<void> setQuery(String q) => applyFilter(filter.value.copyWith(q: q.trim()));

  Future<void> load() async {
    final gen = ++_gen;
    final f = filter.value;
    if (items.isEmpty && mine.isEmpty) state.value = FeedLoad.loading;
    final near = f.near && _lat != null && _lng != null;
    final r = await _api.feed(q: f.q, who: f.who, travel: f.travel, near: near, lat: near ? _lat : null, lng: near ? _lng : null);
    if (gen != _gen) return;
    loadingMore.value = false;
    switch (r) {
      case BuddyOk<FeedPage>(:final value):
        mine.assignAll(value.mine);
        items.assignAll(value.items);
        _cursor = value.nextCursor;
        state.value = FeedLoad.ready;
      case BuddyRefused(:final message):
        if (f.near) {
          nearFailed.value = message;
          filter.value = f.copyWith(near: false);
          await load();
          return;
        }
        if (items.isEmpty && mine.isEmpty) state.value = FeedLoad.failed;
      case BuddyOffline():
        if (items.isEmpty && mine.isEmpty) state.value = FeedLoad.offline;
      case BuddyFailed():
        if (items.isEmpty && mine.isEmpty) state.value = FeedLoad.failed;
    }
  }

  Future<void> refreshHead() async {
    if (state.value != FeedLoad.ready) return load();
    final gen = _gen;
    final head = ++_headGen;
    final f = filter.value;
    final near = f.near && _lat != null && _lng != null;
    final r = await _api.feed(q: f.q, who: f.who, travel: f.travel, near: near, lat: near ? _lat : null, lng: near ? _lng : null);
    if (gen != _gen || head != _headGen) return;
    if (r case BuddyOk<FeedPage>(:final value)) {
      mine.assignAll(value.mine);
      for (final t in value.items) {
        final i = items.indexWhere((x) => x.tripId == t.tripId);
        if (i != -1) items[i] = t;
      }
    }
  }

  Future<void> loadMore() async {
    final cursor = _cursor;
    if (cursor == null || loadingMore.value || state.value != FeedLoad.ready) return;
    final gen = _gen;
    loadingMore.value = true;
    final f = filter.value;
    final near = f.near && _lat != null && _lng != null;
    final r = await _api.feed(cursor: cursor, q: f.q, who: f.who, travel: f.travel, near: near, lat: near ? _lat : null, lng: near ? _lng : null);
    if (gen != _gen) return;
    loadingMore.value = false;
    if (r case BuddyOk<FeedPage>(:final value)) {
      final known = items.map((t) => t.tripId).toSet();
      items.addAll(value.items.where((t) => !known.contains(t.tripId)));
      _cursor = value.nextCursor;
    }
  }

  void applyMyJoin(String tripId, String myJoin) {
    final i = items.indexWhere((t) => t.tripId == tripId);
    if (i != -1) items[i] = items[i].copyWith(myJoin: myJoin);
  }

  /// A refused request updates the card at once: Full for a post with the most pending requests, no Request for a removed member.
  void applyRefusal(String tripId, String? type) {
    final i = items.indexWhere((t) => t.tripId == tripId);
    if (i == -1) return;
    if (type == SocialErrorTypes.tripRequestsFull) items[i] = items[i].copyWith(requestsFull: true);
    if (type == SocialErrorTypes.cannotRejoin) items[i] = items[i].copyWith(myJoin: 'removed');
  }

  void applyRemovalBlock(String tripId, PostRemovalBlock block) {
    if (block is! PostLockedBlock || block.unlocksAt == null) return;
    final i = mine.indexWhere((t) => t.tripId == tripId);
    if (i != -1) mine[i] = mine[i].copyWith(unlocksAt: block.unlocksAt);
  }

  Future<BuddyResult<void>> removeMyPost(String tripId) async {
    final r = await _api.unpublish(tripId);
    if (r.isOk) {
      mine.removeWhere((t) => t.tripId == tripId);
      SocialLive.posts.value++;
    }
    return r;
  }

    void removeOwner(String userId) {
    items.removeWhere((t) => t.owner.userId == userId);
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }
}
