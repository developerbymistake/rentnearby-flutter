import 'package:get/get.dart';

import '../../buddy_live.dart';
import '../../shared/buddy_result.dart';
import '../data/trip_viewer_api.dart';
import '../data/viewer_trip_cache.dart';
import '../models/viewer_models.dart';
import '../viewer_deps.dart';

class SharedTripsController extends GetxController {
  SharedTripsController({TripViewerApi? api}) : _api = api ?? ViewerDeps.viewer;

  final TripViewerApi _api;

  static SharedTripsController get to => Get.isRegistered<SharedTripsController>() ? Get.find<SharedTripsController>() : Get.put(SharedTripsController());

  final items = <SharedTripCard>[].obs;
  final invites = <SharedInvite>[].obs;
  final former = <FormerTripCard>[].obs;
  final past = <SharedTripCard>[].obs;
  final pastCount = 0.obs;
  final pastOpen = false.obs;
  final loaded = false.obs;
  final loadingMore = false.obs;
  String? _cursor;
  String? _pastCursor;
  int _seq = 0;
  Worker? _worker;

  bool get isEmpty => items.isEmpty && invites.isEmpty && former.isEmpty && pastCount.value == 0;
  bool get hasMore => _cursor != null;

  @override
  void onInit() {
    super.onInit();
    ViewerTripCache.watchGone();
    _worker = ever<int>(BuddyLive.sharedTrips, (_) => load());
    load();
  }

  @override
  void onClose() {
    _worker?.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final seq = ++_seq;
    final r = await _api.shared();
    if (seq != _seq || isClosed) return;
    if (r case BuddyOk(:final value)) {
      items.assignAll(value.items);
      invites.assignAll(value.invites);
      former.assignAll(value.former);
      pastCount.value = value.counts.past;
      _cursor = value.nextCursor;
      loaded.value = true;
      if (pastOpen.value) await loadPast();
    }
  }

  Future<void> loadMore() async {
    final c = _cursor;
    if (c == null || loadingMore.value) return;
    loadingMore.value = true;
    final seq = _seq;
    try {
      final r = await _api.shared(cursor: c);
      if (seq != _seq || isClosed) return;
      if (r case BuddyOk(:final value)) {
        final known = {for (final i in items) i.tripId};
        items.addAll(value.items.where((i) => !known.contains(i.tripId)));
        _cursor = value.nextCursor;
      }
    } finally {
      if (!isClosed) loadingMore.value = false;
    }
  }

  Future<void> loadPast({bool more = false}) async {
    pastOpen.value = true;
    final r = await _api.shared(state: 'past', cursor: more ? _pastCursor : null);
    if (isClosed) return;
    if (r case BuddyOk(:final value)) {
      if (more) {
        past.addAll(value.items);
      } else {
        past.assignAll(value.items);
      }
      _pastCursor = value.nextCursor;
    }
  }

  void togglePast() {
    if (pastOpen.value) {
      pastOpen.value = false;
    } else {
      loadPast();
    }
  }
}
