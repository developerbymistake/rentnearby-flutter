import 'package:get/get.dart';

import '../../../buddy/shared/buddy_result.dart';
import '../../../trip/controllers/my_trips_controller.dart';
import '../../shared/social_error_types.dart';
import '../../shared/social_live.dart';
import '../../shared/social_models.dart';
import '../../shared/social_strings.dart';
import '../data/join_api.dart';
import '../social_strings_b.dart';

enum JoinRequestsLoad { loading, ready, gone, offline, failed }

class JoinRequestsController extends GetxController {
  JoinRequestsController({required this.tripId, JoinApi api = const JoinApi()}) : _api = api;

  final String tripId;
  final JoinApi _api;

  final state = JoinRequestsLoad.loading.obs;
  final trip = Rxn<PublicTrip>();
  final items = <JoinRequestItem>[].obs;
  final addToBuddies = <String>{}.obs;
  int _gen = 0;
  Worker? _live;

  @override
  void onInit() {
    super.onInit();
    _live = ever<int>(SocialLive.joinRequests, (_) => load());
    load();
  }

  List<JoinRequestItem> tier(int t) => [for (final i in items) if (i.tier == t) i];

  Future<void> load() async {
    final gen = ++_gen;
    if (trip.value == null) state.value = JoinRequestsLoad.loading;
    final r = await _api.list(tripId);
    if (gen != _gen) return;
    switch (r) {
      case BuddyOk<JoinRequestsPage>(:final value):
        trip.value = value.trip;
        items.assignAll(value.items);
        state.value = JoinRequestsLoad.ready;
      case BuddyRefused(:final statusCode):
        if (statusCode == 404) {
          trip.value = null;
          items.clear();
          state.value = JoinRequestsLoad.gone;
        } else if (trip.value == null) {
          state.value = JoinRequestsLoad.failed;
        }
      case BuddyOffline():
        if (trip.value == null) state.value = JoinRequestsLoad.offline;
      case BuddyFailed():
        if (trip.value == null) state.value = JoinRequestsLoad.failed;
    }
  }

  void toggleBuddy(String id) {
    if (addToBuddies.contains(id)) {
      addToBuddies.remove(id);
    } else {
      addToBuddies.add(id);
    }
  }

  (int, JoinRequestItem)? _take(String id) {
    final i = items.indexWhere((e) => e.id == id);
    if (i == -1) return null;
    final item = items.removeAt(i);
    _gen++;
    return (i, item);
  }

  void _putBack((int, JoinRequestItem) taken) {
    if (items.any((e) => e.id == taken.$2.id)) return;
    items.insert(taken.$1.clamp(0, items.length), taken.$2);
  }

  String _message(BuddyResult<Object?> r) => switch (r) {
        BuddyRefused(:final message) => message ?? SocialStrings.failed,
        BuddyOffline() => SocialStrings.offline,
        _ => SocialStrings.failed,
      };

  // Returns (ok, line for the snack).
  Future<(bool, String)> accept(JoinRequestItem item) async {
    final taken = _take(item.id);
    if (taken == null) return (false, SocialStringsB.requestGone);
    final buddy = item.tier == JoinRequestItem.tierFollower && addToBuddies.contains(item.id);
    final r = await _api.accept(item.id, addToBuddies: buddy);
    switch (r) {
      case BuddyOk<JoinAccepted>(:final value):
        final t = trip.value;
        if (t != null) trip.value = t.copyWith(seatsLeft: value.seatsLeft, waitingRequests: items.length);
        SocialLive.posts.value++;
        if (Get.isRegistered<MyTripsController>()) MyTripsController.to.load();
        return (true, SocialStringsB.joinedTrip(item.person.person.shortName));
      case BuddyRefused(:final type) when type == SocialErrorTypes.joinRequestGone:
        return (false, SocialStringsB.requestGone);
      default:
        _putBack(taken);
        return (false, _message(r));
    }
  }

  Future<(bool, String)> decline(JoinRequestItem item) async {
    final taken = _take(item.id);
    if (taken == null) return (false, SocialStringsB.requestGone);
    final r = await _api.decline(item.id);
    switch (r) {
      case BuddyOk():
        final t = trip.value;
        if (t != null) trip.value = t.copyWith(waitingRequests: items.length);
        return (true, SocialStringsB.declined(item.person.person.shortName));
      case BuddyRefused(:final type) when type == SocialErrorTypes.joinRequestGone:
        return (false, SocialStringsB.requestGone);
      default:
        _putBack(taken);
        return (false, _message(r));
    }
  }

  void removePerson(String userId) => items.removeWhere((e) => e.person.person.userId == userId);

  @override
  void onClose() {
    _live?.dispose();
    super.onClose();
  }
}
