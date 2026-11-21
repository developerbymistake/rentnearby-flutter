import 'package:get/get.dart';

import '../../../../utils/app_toast.dart';
import '../../buddy_error_types.dart';
import '../../buddy_live.dart';
import '../../buddy_navigation.dart';
import '../../shared/buddy_result.dart';
import '../../shared/strings_shared.dart';
import '../../triplimit/trip_limit_gate.dart';
import '../../triplimit/trip_limit_models.dart';
import '../data/trip_viewer_api.dart';
import '../models/viewer_models.dart';
import '../viewer_deps.dart';
import '../viewer_strings.dart';
import '../widgets/joined_snack.dart';

enum TripInviteState { loading, ready, ended, failed }

class TripInviteController extends GetxController {
  TripInviteController(this.memberId, {TripViewerApi? api, Future<bool> Function(TripSlots slots)? limitPrompt})
      : _api = api ?? ViewerDeps.viewer,
        _limitPrompt = limitPrompt ?? TripLimitGate.promptInvite;

  final String memberId;
  final TripViewerApi _api;
  final Future<bool> Function(TripSlots slots) _limitPrompt;

  final state = TripInviteState.loading.obs;
  final preview = Rxn<InvitePreview>();
  final ended = Rxn<InviteEnded>();
  final full = false.obs;
  final joining = false.obs;
  final declining = false.obs;

  bool get busy => joining.value || declining.value;

  String? get ownerName => preview.value?.owner.name ?? ended.value?.ownerName;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    state.value = TripInviteState.loading;
    final r = await _api.invitePreview(memberId);
    if (isClosed) return;
    switch (r) {
      case BuddyOk(:final value):
        preview.value = value;
        final tripId = value.tripId;
        if (value.alreadyMember && tripId != null) {
          state.value = TripInviteState.ready;
          BuddyNavigation.openTripView(tripId, replace: true);
          return;
        }
        state.value = TripInviteState.ready;
      case BuddyRefused<InvitePreview> refused:
        final e = TripViewerApi.inviteEndedOf(refused.cast<Object?>());
        if (e != null || refused.statusCode == 404) {
          ended.value = e ?? const InviteEnded(reason: 'Unknown');
          state.value = TripInviteState.ended;
        } else {
          state.value = TripInviteState.failed;
        }
      case BuddyOffline():
        AppToast.error(BuddySharedStrings.needOnline);
        state.value = TripInviteState.failed;
      case BuddyFailed():
        state.value = TripInviteState.failed;
    }
  }

  Future<void> join() async {
    if (busy) return;
    joining.value = true;
    var retry = false;
    try {
      final r = await _api.acceptInvite(memberId);
      if (isClosed) return;
      switch (r) {
        case BuddyOk(:final value):
          BuddyLive.sharedTrips.value++;
          ViewerDeps.toMyTrips();
          JoinedSnack.show(value);
        case BuddyRefused<String> refused:
          if (refused.type == BuddyErrorTypes.tripFull) {
            full.value = true;
            ended.value = InviteEnded(reason: 'Full', title: preview.value?.title, ownerName: preview.value?.owner.name);
            state.value = TripInviteState.ended;
          } else if (refused.type == BuddyErrorTypes.tripLimitReached) {
            retry = await _limitPrompt(TripSlots.fromRefusal(refused.data));
          } else if (refused.type == BuddyErrorTypes.inviteEnded || refused.statusCode == 404) {
            ended.value = TripViewerApi.inviteEndedOf(refused.cast<Object?>()) ?? const InviteEnded(reason: 'Unknown');
            state.value = TripInviteState.ended;
          } else {
            ViewerDeps.toastError(r);
          }
        default:
          ViewerDeps.toastError(r);
      }
    } finally {
      if (!isClosed) joining.value = false;
    }
    if (retry && !isClosed) await join();
  }

  Future<void> decline() async {
    if (busy) return;
    declining.value = true;
    try {
      final r = await _api.declineInvite(memberId);
      if (isClosed) return;
      switch (r) {
        case BuddyOk():
          BuddyLive.sharedTrips.value++;
          BuddyLive.notices.value++;
          ViewerDeps.toMyTrips();
          ViewerDeps.snack(ViewerStrings.inviteDeclined);
        case BuddyRefused<void> refused when refused.type == BuddyErrorTypes.inviteEnded || refused.statusCode == 404:
          ended.value = TripViewerApi.inviteEndedOf(refused.cast<Object?>()) ?? const InviteEnded(reason: 'Unknown');
          state.value = TripInviteState.ended;
        default:
          ViewerDeps.toastError(r);
      }
    } finally {
      if (!isClosed) declining.value = false;
    }
  }
}
