import 'package:flutter/widgets.dart';

import '../buddy_live.dart';
import '../shared/buddy_result.dart';
import '../sharing/widgets/trip_delete_flow.dart';
import '../viewer/data/viewer_trip_cache.dart';
import '../viewer/viewer_deps.dart';
import '../viewer/viewer_strings.dart';
import '../viewer/widgets/leave_trip_dialog.dart';
import 'trip_limit_models.dart';

abstract class TripLimitActions {
  const TripLimitActions();

  Future<bool> deleteOwned(BuildContext context, TripSlotTrip trip);

  Future<bool> leave(BuildContext context, TripSlotTrip trip);
}

class DefaultTripLimitActions extends TripLimitActions {
  const DefaultTripLimitActions();

  @override
  Future<bool> deleteOwned(BuildContext context, TripSlotTrip trip) => TripDeleteFlow.startById(context, trip.id);

  @override
  Future<bool> leave(BuildContext context, TripSlotTrip trip) async {
    if (!await LeaveTripDialog.ask(context)) return false;
    final r = await ViewerDeps.viewer.leave(trip.id);
    switch (r) {
      case BuddyOk():
        ViewerTripCache.remove(trip.id);
        BuddyLive.sharedTrips.value++;
        ViewerDeps.snack(ViewerStrings.youLeft);
        return true;
      case BuddyRefused(:final statusCode) when statusCode == 404:
        ViewerTripCache.remove(trip.id);
        BuddyLive.sharedTrips.value++;
        return true;
      default:
        ViewerDeps.toastError(r);
        return false;
    }
  }
}
