import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../../design/tokens/listing_palette.dart';
import '../../../../utils/app_toast.dart';
import '../../../social/b/social_strings_b.dart';
import '../../../social/b/widgets/find_buddies_post_card.dart';
import '../../../social/shared/post_removal.dart';
import '../../../social/shared/social_error_types.dart';
import '../../../social/shared/social_me_controller.dart';
import '../../../social/shared/social_nav.dart';
import '../../../social/shared/widgets/plus_widgets.dart';
import '../../../trip/models/trip_model.dart';
import '../../buddy_navigation.dart';
import '../controllers/owner_sharing_controller.dart';
import '../models/sharing_models.dart';
import '../sharing_strings.dart';
import 'invite_sheet.dart';
import 'overview_expenses_card.dart';
import 'overview_travellers_card.dart';
import 'trip_delete_flow.dart';

class OverviewMenuItem {
  const OverviewMenuItem({required this.label, required this.onTap, this.danger = false, this.subtitle, this.art, this.blocked = false});

  final String label;
  final VoidCallback onTap;
  final bool danger;
  final String? subtitle;
  final String? art;

  /// Greyed with its reason as the subtitle; the tap explains instead of acting.
  final bool blocked;
}

class OwnerOverviewExtras {
  const OwnerOverviewExtras({
    this.subtitle,
    this.travellerCount,
    this.extraCards = const [],
    this.extraMenuItems = const [],
    this.progressLine,
    this.showProgress = true,
  });

  static const OwnerOverviewExtras none = OwnerOverviewExtras();

  final String? subtitle;
  final int? travellerCount;
  final List<Widget> extraCards;
  final List<OverviewMenuItem> extraMenuItems;
  final String? progressLine;
  final bool showProgress;
}

abstract final class OwnerOverviewSeam {
  static bool tripEnded(TripModel trip, {DateTime? now}) {
    if (trip.isCompleted) return true;
    final end = trip.endDate;
    if (end == null) return false;
    final n = now ?? DateTime.now();
    return DateTime(end.year, end.month, end.day).isBefore(DateTime(n.year, n.month, n.day));
  }

  // Only the owner overview calls this. The cards never depend on the write answers carrying
  // the block (D-02): real block, else the trip's block, else "owner alone" with one fetch.
  static OwnerOverviewExtras of(BuildContext context, TripModel trip, {int? progressPercent}) {
    final c = OwnerSharingController.ensure(trip.id, trip.sharing);
    final known = c.sharing.value ?? trip.sharing;
    if (known == null) {
      c.fetchOnceIfMissing();
      if (c.unsupported.value) return OwnerOverviewExtras.none;
    }
    final s = known ?? _ownerAlone();
    return build(context, trip, s, progressPercent: progressPercent, controller: c);
  }

  static TripSharingBlock _ownerAlone() {
    final user = Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value : null;
    return TripSharingBlock.ownerAlone(userId: user?.id ?? '', ownerName: user?.name ?? user?.username ?? '');
  }

  static OwnerOverviewExtras build(BuildContext context, TripModel trip, TripSharingBlock s,
      {int? progressPercent, OwnerSharingController? controller}) {
    final shared = s.viewerCount > 0;
    final alone = s.travellerCount <= 1 && s.pendingInvites == 0;
    final ended = tripEnded(trip);
    void reload() => controller?.reload();
    return OwnerOverviewExtras(
      subtitle: shared ? SharingStrings.sharedWith(s.viewerCount) : null,
      travellerCount: s.travellerCount,
      showProgress: !shared,
      progressLine: alone && progressPercent == 100 ? SharingStrings.allSetInvite : null,
      extraCards: [
        OverviewTravellersCard(
          sharing: s,
          onInvite: () {
            if (trip.inactiveByPlan) {
              PlusSheets.limitReached(context, errorType: SocialErrorTypes.tripLimitReached, from: 'trip');
              return;
            }
            if (trip.spotCount <= 0) {
              AppToast.error(SharingStrings.addPlacesFirst);
              return;
            }
            InviteSheet.show(context, trip.id, onChanged: reload);
          },
          onManage: () async {
            await BuddyNavigation.openTravellers(trip.id);
            reload();
          },
        ),
        OverviewExpensesCard(
          expenses: s.expenses,
          tripEnded: ended,
          onAdd: () async {
            await BuddyNavigation.openExpenses(trip.id);
            reload();
          },
          onView: () async {
            await BuddyNavigation.openMoneyHome(trip.id, tripEnded: ended, settled: OverviewExpensesCard.isSettled(s.expenses));
            reload();
          },
        ),
      ],
      extraMenuItems: [
        ?_socialItem(context, trip),
        _deleteItem(context, trip, s, ended: ended, reload: reload),
      ],
    );
  }

  /// Delete trip: greyed during the 72-hour post lock, or while other travellers are on a posted trip (CONTRACT_SOCIAL 11.9).
  static PostRemovalBlock? deleteBlock(TripModel trip, TripSharingBlock s, {required bool ended, DateTime? now}) => PostRemovalRule.forDelete(
        unlocksAt: trip.postUnlocksAt,
        posted: trip.isPublic || trip.deleteNeedsAlone,
        otherMembers: s.viewerCount,
        ended: ended,
        now: now,
      );

  static OverviewMenuItem _deleteItem(BuildContext context, TripModel trip, TripSharingBlock s, {required bool ended, VoidCallback? reload}) {
    final block = deleteBlock(trip, s, ended: ended);
    if (block == null) return OverviewMenuItem(label: SharingStrings.deleteTrip, danger: true, onTap: () => TripDeleteFlow.start(context, trip, s));
    return OverviewMenuItem(label: SharingStrings.deleteTrip, subtitle: block.line, blocked: true, onTap: () async {
          await PostRemovalNotice.show(context, trip.id, block);
          reload?.call();
        });
  }

  static OverviewMenuItem? _socialItem(BuildContext context, TripModel trip) {
    final auth = Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    if (auth == null || !auth.canUseTravellerFeatures || trip.isCompleted || trip.inactiveByPlan || trip.id.isEmpty) return null;
    final live = trip.isPublic || (SocialMeController.maybe?.profile?.publicTrips.any((t) => t.tripId == trip.id) ?? false);
    if (live) return OverviewMenuItem(label: SocialStringsB.openJoinRequests, onTap: () => SocialNav.openJoinRequests(trip.id));
    final hint = SocialStringsB.postEntryHint(SocialMeController.maybe?.me.value?.limits);
    return OverviewMenuItem(
      label: SocialStringsB.postToFindBuddies,
      subtitle: hint.isEmpty ? SocialStringsB.postToFindBuddiesLine : hint,
      art: ListingArt.backpack,
      onTap: () => PostTripEntry.open(context, tripId: trip.id),
    );
  }

  static void release(String? tripId) => OwnerSharingController.release(tripId);
}
