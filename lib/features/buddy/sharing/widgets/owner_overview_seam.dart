import 'package:flutter/widgets.dart';

import '../../../../utils/app_toast.dart';
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
  const OverviewMenuItem({required this.label, required this.onTap, this.danger = false});

  final String label;
  final VoidCallback onTap;
  final bool danger;
}

class OwnerOverviewExtras {
  const OwnerOverviewExtras({
    this.subtitle,
    this.travellerCount,
    this.extraCards = const [],
    this.extraMenuItems = const [],
    this.compactCards = false,
    this.progressLine,
    this.showProgress = true,
  });

  static const OwnerOverviewExtras none = OwnerOverviewExtras();

  final String? subtitle;
  final int? travellerCount;
  final List<Widget> extraCards;
  final List<OverviewMenuItem> extraMenuItems;
  final bool compactCards;
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

  static OwnerOverviewExtras of(BuildContext context, TripModel trip, {int? progressPercent}) {
    final initial = trip.sharing;
    if (initial == null) return OwnerOverviewExtras.none;
    final c = OwnerSharingController.ensure(trip.id, initial);
    final s = c.sharing.value ?? initial;
    return build(context, trip, s, progressPercent: progressPercent, controller: c);
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
      compactCards: true,
      showProgress: !shared,
      progressLine: alone && progressPercent == 100 ? SharingStrings.allSetInvite : null,
      extraCards: [
        OverviewTravellersCard(
          sharing: s,
          onInvite: () {
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
            await BuddyNavigation.openExpenses(trip.id, add: true);
            reload();
          },
          onView: () async {
            await BuddyNavigation.openMoneyHome(trip.id, tripEnded: ended, settled: OverviewExpensesCard.isSettled(s.expenses));
            reload();
          },
        ),
      ],
      extraMenuItems: [
        OverviewMenuItem(label: SharingStrings.deleteTrip, danger: true, onTap: () => TripDeleteFlow.start(context, trip, s)),
      ],
    );
  }

  static void release(String? tripId) => OwnerSharingController.release(tripId);
}
