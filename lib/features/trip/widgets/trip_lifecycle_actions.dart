import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../controllers/my_trips_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../data/trip_repository.dart';
import '../data/trip_today_cache.dart';
import '../models/trip_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_v2_plan.dart';

class TripLifecycleActions {
  static const _repo = TripRepository();
  static bool _busy = false;

  static Future<bool> markComplete(BuildContext context) async {
    final c = TripPlanController.to;
    final id = c.trip.value?.id;
    if (id == null) return false;
    final ok = await _confirmComplete(context, early: c.hasDates && !c.isLastDayOrAfter);
    if (ok != true || _busy) return false;
    _busy = true;
    try {
      final result = await _repo.complete(id);
      c.trip.value = result;
      TripTodayCache.saveTrip(result);
      AppToast.success(TripStrings.tripCompleted);
      return true;
    } catch (e) {
      if (DioErrorMapper.errorType(e) == TripErrorTypes.tripNotEnded) {
        AppToast.error(TripStrings.tripNotEnded);
      } else if (DioErrorMapper.isNetworkError(e)) {
        AppToast.error(TripStrings.noNetwork);
      } else {
        AppToast.error(DioErrorMapper.toMessage(e, TripStrings.couldNotLoad));
      }
      return false;
    } finally {
      _busy = false;
    }
  }

  static Future<bool?> _confirmComplete(BuildContext context, {required bool early}) => Dialog3D.show<bool>(
        context,
        builder: (ctx) => Dialog3D(
          tone: ListingTone.indigo,
          art: ListingArt.star,
          title: early ? TripStringsA5.completeNowQ : TripStrings.markCompleteQ,
          body: early ? TripStringsA5.completeNowBody : TripStrings.markCompleteBody,
          secondaryLabel: TripStrings.cancelAction,
          onSecondary: () => Navigator.pop(ctx, false),
          primaryLabel: TripStrings.markComplete,
          onPrimary: () => Navigator.pop(ctx, true),
        ),
      );

  static Future<bool> markCompleteFromList(BuildContext context, TripSummaryModel trip) async {
    final ok = await _confirmComplete(context, early: false);
    if (ok != true || _busy) return false;
    _busy = true;
    try {
      return await MyTripsController.to.markComplete(trip.id);
    } finally {
      _busy = false;
    }
  }

  static Future<bool> toggleMute(BuildContext context) async {
    final c = TripPlanController.to;
    final trip = c.trip.value;
    if (trip == null || _busy) return false;
    _busy = true;
    try {
      final result = await _repo.mute(trip.id, muted: !trip.isMuted);
      c.trip.value = result;
      TripTodayCache.saveTrip(result);
      AppToast.success(result.isMuted ? TripStrings.remindersMuted : TripStrings.remindersOn);
      return true;
    } catch (e) {
      AppToast.error(DioErrorMapper.isNetworkError(e)
          ? TripStrings.noNetwork
          : DioErrorMapper.toMessage(e, TripStrings.couldNotLoad));
      return false;
    } finally {
      _busy = false;
    }
  }

  static Future<bool> confirmDelete(BuildContext context, {required int open, required int confirmed, int confirmedTaxis = 0}) async {
    final lines = [
      if (open > 0) TripStringsV2Plan.openEnquiries(open),
      if (confirmed > 0) TripStringsV2Plan.confirmedStays(confirmed),
      if (confirmedTaxis > 0) TripStringsV2Plan.confirmedTaxis(confirmedTaxis),
    ];
    final ok = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => Dialog3D(
        tone: ListingTone.indigo,
        art: ListingArt.luggage,
        title: TripStringsV2Plan.deleteTitle,
        body: [TripStringsV2Plan.deleteBody, ...lines].join('\n'),
        secondaryLabel: TripStringsV2Plan.keepTrip,
        onSecondary: () => Navigator.pop(ctx, false),
        primaryLabel: TripStringsV2Plan.delete,
        primaryDanger: true,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
    return ok == true;
  }

  static Future<bool> deleteFromPlan(BuildContext context) async {
    final c = TripPlanController.to;
    final id = c.trip.value?.id;
    if (id == null || _busy) return false;
    final rows = c.enquiryList;
    final open = rows.where((e) => e.isWithdrawable).length;
    final stays = rows.where((e) => e.isBooked && !e.isTaxi).length;
    final taxis = rows.where((e) => e.isBooked && e.isTaxi).length;
    final ok = await confirmDelete(context, open: open, confirmed: stays, confirmedTaxis: taxis);
    if (!ok) return false;
    _busy = true;
    try {
      final done = await MyTripsController.to.delete(id);
      if (done) TripNavigation.replaceWithMyTrips();
      return done;
    } finally {
      _busy = false;
    }
  }

  static Future<bool> saveAndExit(BuildContext context) async {
    final c = TripPlanController.to;
    final ok = await c.flushPendingSave();
    if (!ok && c.saveFailed.value) {
      AppToast.error(TripStringsV2Plan.saveFailed);
      return false;
    }
    if (!context.mounted) return false;
    final leave = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => Dialog3D(
        tone: ListingTone.indigo,
        art: ListingArt.luggage,
        title: TripStringsV2Plan.savedTitle,
        body: TripStringsV2Plan.savedBody,
        secondaryLabel: TripStringsV2Plan.keepPlanning,
        onSecondary: () => Navigator.pop(ctx, false),
        primaryLabel: TripStringsV2Plan.goToMyTrips,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
    if (leave == true) TripNavigation.replaceWithMyTrips();
    return leave == true;
  }

  static Future<void>? openSummary(String tripId) => TripNavigation.openSummary(tripId);
}
