import 'package:get/get.dart';

import '../../../buddy/shared/buddy_result.dart';
import '../../shared/social_error_types.dart';
import '../../shared/social_live.dart';
import '../../shared/social_models.dart';
import '../data/join_api.dart';
import '../data/public_trips_api.dart';

enum TripPostLoad { loading, ready, gone, offline, failed }

class TripPostController extends GetxController {
  TripPostController({required this.tripId, PublicTripsApi api = const PublicTripsApi(), JoinApi join = const JoinApi()})
      : _api = api,
        _join = join;

  final String tripId;
  final PublicTripsApi _api;
  final JoinApi _join;

  final state = TripPostLoad.loading.obs;
  final trip = Rxn<PublicTrip>();
  final busy = false.obs;
  int _gen = 0;
  final _workers = <Worker>[];

  @override
  void onInit() {
    super.onInit();
    _workers.add(ever<int>(SocialLive.joinRequests, (_) => load()));
    _workers.add(ever<int>(SocialLive.posts, (_) => load()));
    load();
  }

  Future<void> load() async {
    final gen = ++_gen;
    if (trip.value == null) state.value = TripPostLoad.loading;
    final r = await _api.post(tripId);
    if (gen != _gen) return;
    switch (r) {
      case BuddyOk<PublicTrip>(:final value):
        trip.value = value;
        state.value = TripPostLoad.ready;
      case BuddyRefused(:final statusCode, :final type):
        final gone = statusCode == 404 || type == SocialErrorTypes.tripPostNotFound;
        if (gone) {
          trip.value = null;
          state.value = TripPostLoad.gone;
        } else if (trip.value == null) {
          state.value = TripPostLoad.failed;
        }
      case BuddyOffline():
        if (trip.value == null) state.value = TripPostLoad.offline;
      case BuddyFailed():
        if (trip.value == null) state.value = TripPostLoad.failed;
    }
  }

  void markRequested() {
    final t = trip.value;
    if (t != null) trip.value = t.copyWith(myJoin: 'requested');
  }

  void applyRefusal(String? type) {
    final t = trip.value;
    if (t == null) return;
    if (type == SocialErrorTypes.tripRequestsFull) trip.value = t.copyWith(requestsFull: true);
    if (type == SocialErrorTypes.cannotRejoin) trip.value = t.copyWith(myJoin: 'removed');
  }

  Future<BuddyResult<void>> cancelRequest() async {
    final t = trip.value;
    if (t == null || busy.value) return const BuddyFailed(message: '');
    busy.value = true;
    trip.value = t.copyWith(myJoin: 'none');
    try {
      final r = await _join.cancel(tripId);
      if (r.isOk) {
        _gen++;
        SocialLive.joinRequests.value++;
      } else {
        trip.value = trip.value?.copyWith(myJoin: 'requested');
      }
      return r;
    } finally {
      busy.value = false;
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
