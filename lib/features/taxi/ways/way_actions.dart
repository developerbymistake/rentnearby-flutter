import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../utils/app_toast.dart';
import '../../trip/controllers/trip_plan_controller.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/models/trip_plan_model.dart';
import '../../trip/trip_strings_steps_a1.dart';
import '../../trip/trip_strings_steps_k3.dart';
import '../../trip/utils/trip_travel_rules.dart';
import '../journeys/journey_models.dart';
import '../journeys/journeys_controller.dart';
import 'ask_drivers_sheet.dart';
import 'models/taxi_ways_models.dart';
import 'taxi_ways_navigation.dart';
import 'widgets/travel_confirm_sheet.dart';

enum WaySegmentLink { linked, plain, failed }

class WayActions {
  WayActions({
    required this.tripId,
    this.tripRole,
    this.tripLegIndex,
    required this.date,
    required this.people,
    required this.chosenOf,
    required this.busy,
  });

  final String? tripId;
  final String? tripRole;
  final int? tripLegIndex;
  final DateTime Function() date;
  final int Function() people;
  final Map<int, WayDriver> Function(String planKey) chosenOf;
  final RxSet<String> busy;

  TripStepRole? get role => TripStepRole.parse(tripRole);

  bool get forTrip => tripId != null && role != null;

  bool get forSegment => tripId != null && tripLegIndex != null;

  TripPlanController? get trip =>
      Get.isRegistered<TripPlanController>() && TripPlanController.to.trip.value?.id == tripId ? TripPlanController.to : null;

  static void backToPlan() => Get.until((r) => r.settings.name == AppRoutes.tripPlan || r.isFirst);

  void back() => backToPlan();

  int? roadMinutesOf(WayPlan plan) {
    var total = 0;
    for (final leg in plan.legs) {
      final m = leg.driverFor(chosenOf(plan.planKey)[leg.index])?.minutes;
      if (m == null || m <= 0) return null;
      total += m;
    }
    return plan.legs.isEmpty ? null : total;
  }

  Future<SavedJourney?> saveIfNeeded(WayPlan plan, {bool quiet = false}) => JourneysController.ensure().saveIfNeeded(
        quiet: quiet,
        plan: plan,
        chosen: chosenOf(plan.planKey),
        date: date(),
        people: people(),
        fromName: plan.from.name,
        fromLat: plan.from.lat,
        fromLng: plan.from.lng,
        toName: plan.to.name,
        toLat: plan.to.lat,
        toLng: plan.to.lng,
        forTripId: forTrip || forSegment ? tripId : null,
        forTripLegIndex: forSegment && trip != null ? tripLegIndex : null,
      );

  Future<({bool go, bool replaceBooked})> segmentGate(BuildContext? context, WayPlan plan) async {
    final c = trip;
    final k = tripLegIndex;
    if (c == null || k == null) return (go: true, replaceBooked: false);
    final block = await c.prepareSegmentLink(k);
    if (block != null) {
      AppToast.warning(block);
      return (go: false, replaceBooked: false);
    }
    final booked = c.travelImpact(k).bookedRows;
    if (booked == 0 || c.travelMatches(k, plan.planKey, date(), people())) {
      return (go: true, replaceBooked: false);
    }
    if (context == null || !context.mounted) return (go: false, replaceBooked: false);
    final ok = await TravelConfirmSheet.replaceTravel(context, booked);
    return (go: ok, replaceBooked: ok);
  }

  // Confirms replacing the step's journey; the old rows are closed only after the new journey is saved.
  Future<({bool go, bool close})> stepGate(BuildContext? context, WayPlan plan) async {
    final c = trip;
    final r = role;
    if (c == null || r == null) return (go: true, close: false);
    final oldId = c.journeyIdOf(role: r);
    if (oldId == null) return (go: true, close: false);
    final same = JourneysController.ensure().findByPlan(plan.planKey, date(), people: people(), forTripId: tripId);
    if (same?.id == oldId) return (go: true, close: false);
    final impact = c.stepImpact(r);
    if (impact.isEmpty) return (go: true, close: false);
    if (impact.hasBooked) {
      if (context == null || !context.mounted) return (go: false, close: false);
      if (!await TravelConfirmSheet.replaceTravel(context, impact.bookedRows)) return (go: false, close: false);
    }
    return (go: true, close: true);
  }

  List<TripEnquiryModel> _oldStepRows(SavedJourney saved) {
    final c = trip;
    final r = role;
    if (c == null || r == null || c.journeyIdOf(role: r) == saved.id) return const [];
    return c.journeyRowsOf(role: r);
  }

  Future<WaySegmentLink> _linkStep(SavedJourney saved, bool closeOld) async {
    final old = closeOld ? _oldStepRows(saved) : const <TripEnquiryModel>[];
    final link = await linkToTrip(saved);
    if (link == WaySegmentLink.linked && old.isNotEmpty && !await trip!.closeRows(old)) {
      AppToast.warning(TripStringsStepsK3.notSavedToTrip);
    }
    return link;
  }

  Future<void> releaseUnsaved(WayPlan plan) async {
    final c = trip;
    final j = JourneysController.ensure().findByPlan(plan.planKey, date(), people: people(), forTripId: tripId);
    if (c != null && j != null && j.tripId == tripId) await c.releaseJourneyLink(j.id);
  }

  Future<WaySegmentLink> linkToTrip(SavedJourney saved) async {
    final r = role;
    final c = trip;
    if (r != null && c != null) {
      c.linkJourney(r, saved);
      if (c.stepOf(r).journeyId == saved.id) {
        if (await c.flushPendingSave()) {
          AppToast.success(TripStringsStepsA1.savedToTrip);
          return WaySegmentLink.linked;
        }
        AppToast.warning(TripStringsStepsK3.notSavedTryAgain);
        return WaySegmentLink.failed;
      }
    }
    AppToast.success(TripStringsStepsA1.savedToJourneys);
    return WaySegmentLink.plain;
  }

  Future<WaySegmentLink> linkSegment(
    BuildContext? context,
    SavedJourney saved,
    WayPlan plan, {
    bool replaceBooked = false,
  }) async {
    final c = trip;
    final k = tripLegIndex;
    if (c == null || k == null) {
      AppToast.success(TripStringsStepsA1.savedToJourneys);
      return WaySegmentLink.plain;
    }
    final minutes = roadMinutesOf(plan);
    var r = await c.linkSegmentJourney(k, saved, replaceBooked: replaceBooked, roadMinutes: minutes);
    if (r == TripLinkResult.needsConfirm && context != null && context.mounted) {
      final booked = c.travelImpact(k).bookedRows;
      if (await TravelConfirmSheet.replaceTravel(context, booked)) {
        r = await c.linkSegmentJourney(k, saved, replaceBooked: true, roadMinutes: minutes);
      }
    }
    switch (r) {
      case TripLinkResult.saved:
        AppToast.success(TripStringsStepsA1.savedToTrip);
        return WaySegmentLink.linked;
      case TripLinkResult.notSaved:
        AppToast.warning(TripStringsStepsK3.notSavedToTrip);
        await c.releaseJourneyLink(saved.id);
        return WaySegmentLink.failed;
      case TripLinkResult.needsConfirm:
        await c.releaseJourneyLink(saved.id);
        return WaySegmentLink.failed;
    }
  }

  Future<void> saveJourney(WayPlan plan) async {
    if (busy.contains(plan.planKey)) return;
    busy.add(plan.planKey);
    try {
      final saved = await saveIfNeeded(plan);
      if (saved != null) TaxiWaysNavigation.openSavedJourney(saved.id);
    } finally {
      busy.remove(plan.planKey);
    }
  }

  Future<void> arrangedMyself() async {
    if (Get.isRegistered<TripPlanController>()) await TripPlanController.to.flushPendingSave();
    back();
  }

  Future<void> useForTrip(WayPlan plan, {BuildContext? context}) async {
    if (busy.contains(plan.planKey)) return;
    busy.add(plan.planKey);
    try {
      var replaceBooked = false;
      var closeOld = false;
      if (forSegment) {
        final gate = await segmentGate(context, plan);
        if (!gate.go) return;
        replaceBooked = gate.replaceBooked;
      } else if (forTrip) {
        final gate = await stepGate(context, plan);
        if (!gate.go) return;
        closeOld = gate.close;
      }
      final saved = await saveIfNeeded(plan, quiet: true);
      if (saved == null) {
        if (forSegment) await releaseUnsaved(plan);
        return;
      }
      if (forSegment) {
        final link = await linkSegment(context?.mounted == true ? context : null, saved, plan, replaceBooked: replaceBooked);
        if (link == WaySegmentLink.linked) {
          back();
        } else if (link == WaySegmentLink.plain) {
          TaxiWaysNavigation.openSavedJourney(saved.id);
        }
        return;
      }
      final link = await _linkStep(saved, closeOld);
      if (link == WaySegmentLink.plain) {
        TaxiWaysNavigation.openSavedJourney(saved.id);
      } else if (link == WaySegmentLink.linked) {
        back();
      }
    } finally {
      busy.remove(plan.planKey);
    }
  }

  Future<void> askDrivers(BuildContext context, WayPlan plan) async {
    if (busy.contains(plan.planKey)) return;
    busy.add(plan.planKey);
    try {
      var replaceBooked = false;
      var closeOld = false;
      if (forSegment) {
        final gate = await segmentGate(context, plan);
        if (!gate.go) return;
        replaceBooked = gate.replaceBooked;
      } else if (forTrip) {
        final gate = await stepGate(context, plan);
        if (!gate.go) return;
        closeOld = gate.close;
      }
      final journey = await saveIfNeeded(plan, quiet: forTrip || forSegment);
      if (journey == null) {
        if (forSegment) await releaseUnsaved(plan);
        return;
      }
      final bool linked;
      if (forSegment) {
        if (!context.mounted) {
          await trip?.releaseJourneyLink(journey.id);
          return;
        }
        final link = await linkSegment(context, journey, plan, replaceBooked: replaceBooked);
        if (link == WaySegmentLink.failed) return;
        linked = link == WaySegmentLink.linked;
      } else if (forTrip) {
        final link = await _linkStep(journey, closeOld);
        if (link == WaySegmentLink.failed) return;
        linked = link == WaySegmentLink.linked;
      } else {
        linked = false;
      }
      if (!context.mounted) return;
      final res = await AskDriversSheet.show(
        context,
        plan: plan,
        chosen: chosenOf(plan.planKey),
        date: date(),
        people: people(),
        journeyId: journey.id,
        fromName: plan.from.name,
        toName: plan.to.name,
      );
      if (res == null) return;
      JourneysController.ensure().recordAsk(journey.id, res);
      if (linked) {
        final t = trip;
        if (t != null) unawaited(t.refreshEnquiries());
        back();
      } else {
        TaxiWaysNavigation.openSavedJourney(journey.id);
      }
    } finally {
      busy.remove(plan.planKey);
    }
  }
}
