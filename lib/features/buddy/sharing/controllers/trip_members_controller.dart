import 'package:get/get.dart';

import '../../buddy_error_types.dart';
import '../../buddy_live.dart';
import '../../shared/buddy_result.dart';
import '../data/trip_members_api.dart';
import '../models/sharing_models.dart';

class TripMembersController extends GetxController {
  TripMembersController(this.tripId, {required TripMembers initial, this.api = const TripMembersApi()}) : members = initial.obs;

  final String tripId;
  final TripMembersApi api;
  final Rx<TripMembers> members;
  final RxSet<String> cancelling = <String>{}.obs;
  final RxBool gone = false.obs;
  Worker? _worker;
  Future<void>? _loading;

  static TripMembersController of(String tripId) => Get.find<TripMembersController>(tag: tripId);

  @override
  void onInit() {
    super.onInit();
    _worker = ever(BuddyLive.tripView(tripId), (_) => reload());
  }

  @override
  void onClose() {
    _worker?.dispose();
    super.onClose();
  }

  Future<void> reload() => _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    final r = await api.members(tripId);
    if (isClosed) return;
    switch (r) {
      case BuddyOk<TripMembers>(:final value):
        members.value = value;
      case BuddyRefused<TripMembers>(:final type) when type == BuddyErrorTypes.tripNotFound:
        gone.value = true;
      default:
        break;
    }
  }

  Future<BuddyResult<void>> cancelInvite(String userId) async {
    if (cancelling.contains(userId)) return const BuddyFailed(message: 'busy');
    cancelling.add(userId);
    try {
      final r = await api.cancelInvite(tripId, userId);
      if (r is BuddyOk<void>) {
        final m = members.value;
        members.value = TripMembers(
          tripId: m.tripId,
          title: m.title,
          role: m.role,
          ownerName: m.ownerName,
          travellerCount: m.travellerCount,
          maxTravellers: m.maxTravellers,
          pendingInvites: m.pendingInvites > 0 ? m.pendingInvites - 1 : 0,
          seatsLeft: m.seatsLeft + 1,
          joined: m.joined,
          invited: [for (final i in m.invited) if (i.userId != userId) i],
          canInvite: m.canInvite,
          canLeave: m.canLeave,
        );
        await reload();
      } else if (r is BuddyRefused<void> && r.type == BuddyErrorTypes.tripNotFound) {
        gone.value = true;
      }
      return r;
    } finally {
      cancelling.remove(userId);
    }
  }
}
