import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:get/get.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../../taxi/journeys/journey_actions.dart';
import '../../taxi/journeys/journeys_controller.dart';
import '../../taxi/ways/trip_strings_journey_card.dart';
import '../../taxi/ways/widgets/travel_confirm_sheet.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_navigation.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_travel_rules.dart';
import 'trip_arrange_confirm.dart';
import 'trip_journey_strip.dart';

class TripJourneyCard {
  TripJourneyCard._();

  static TripJourney? journeyOf(TripPlanController c, {TripStepRole? role, int? legIndex}) =>
      role != null ? c.journeyFor(role) : (legIndex == null ? null : c.segmentJourney(legIndex));

  static List<TripEnquiryModel> rowsOf(TripPlanController c, TripJourney j, {int? legIndex}) =>
      legIndex != null ? c.segmentRows(legIndex) : TripTravelRules.liveRowsOf(j.id, c.enquiryList);

  static bool canActOn(TripPlanController c, TripJourney j, {TripStepRole? role, int? legIndex}) {
    if (c.isReadOnly || c.needsUpdate.value) return false;
    final k = legIndex;
    if (k != null) {
      final day = c.plan.value?.legStart(k) ?? 1;
      return c.canEditDay(day) && c.travelStateOf(k) != TripTravelState.dateChanged;
    }
    return role != null && c.stepCanAsk(role);
  }

  static void setCarOwn({TripStepRole? role, int? legIndex, required int car, required bool own}) =>
      TripPlanController.to.setOwnCar(role, legIndex, car, own);

  static void _refreshLinked(String journeyId) {
    final saved = JourneysController.ensure().journeys.firstWhereOrNull((x) => x.id == journeyId);
    if (saved != null && Get.isRegistered<TripPlanController>()) TripPlanController.to.refreshLinkedJourney(saved);
  }

  static Future<void> useBackup(TripJourney j, int car, String taxiId) async {
    await JourneysController.ensure().replaceDriver(j.id, car, taxiId);
    _refreshLinked(j.id);
  }

  static Future<void> findAnotherCar(BuildContext context, TripJourney j, int car) async {
    final saved = JourneysController.ensure().journeys.firstWhereOrNull((x) => x.id == j.id);
    final leg = saved?.legs.firstWhereOrNull((l) => l.legIndex == car);
    if (saved == null || leg == null) {
      await TripNavigation.openJourney(j.id);
      return;
    }
    await JourneyActions.changeDriver(context, saved, leg);
    _refreshLinked(j.id);
  }

  static Future<bool> _closeRows(Iterable<TripEnquiryModel> rows) async {
    final enq = TripEnquiryController.to;
    for (final e in rows) {
      if (!TripTravelRules.isLive(e)) continue;
      final ok = TripTravelRules.bookedStatuses.contains(e.status)
          ? await enq.cancel(e.id)
          : (e.isWithdrawable ? await enq.withdraw(e.id) : true);
      if (!ok) return false;
    }
    return true;
  }

  static Future<void> cancelCarBooking(BuildContext context, {TripStepRole? role, int? legIndex, required int car}) async {
    final c = TripPlanController.to;
    final j = journeyOf(c, role: role, legIndex: legIndex);
    if (j == null || c.isReadOnly) return;
    final rows = [
      for (final e in rowsOf(c, j, legIndex: legIndex))
        if (e.context.journeyLegIndex == car && TripTravelRules.isLive(e)) e,
    ];
    final booked = TripTravelRules.carBooking(car, rows);
    if (booked == null) return;
    final driver = TripJourneyStrip.driverOf(j.legs.firstWhereOrNull((l) => l.legIndex == car)?.driverName ?? '');
    final ok = await TravelConfirmSheet.show(
      context,
      title: TripStringsJourneyCard.cancelBookingQ(driver),
      body: TripStringsJourneyCard.cancelBookingBody,
      confirm: TripStringsJourneyCard.cancelBooking,
    );
    if (!ok) return;
    if (!await _closeRows([booked])) {
      AppToast.warning(TripStringsJourneyCard.carClosedFailed);
      return;
    }
    unawaited(c.refreshEnquiries());
  }

  static Future<void> arrangeCar(BuildContext context, {TripStepRole? role, int? legIndex, required int car}) async {
    final c = TripPlanController.to;
    final j = journeyOf(c, role: role, legIndex: legIndex);
    if (j == null || c.isReadOnly) return;
    final rows = [
      for (final e in rowsOf(c, j, legIndex: legIndex))
        if (e.context.journeyLegIndex == car && TripTravelRules.isLive(e)) e,
    ];
    final booked = TripTravelRules.carBooking(car, rows);
    if (booked != null) {
      final driver = TripJourneyStrip.driverOf(j.legs.firstWhereOrNull((l) => l.legIndex == car)?.driverName ?? '');
      final ok = await TravelConfirmSheet.show(
        context,
        title: TripStringsJourneyCard.cancelBookingQ(driver),
        body: TripStringsJourneyCard.cancelBookingBody,
        confirm: TripStringsJourneyCard.cancelBooking,
      );
      if (!ok) return;
    }
    if (!await _closeRows(rows)) {
      AppToast.warning(TripStringsJourneyCard.carClosedFailed);
      return;
    }
    c.setOwnCar(role, legIndex, car, true);
  }

  static TripEasyRowKey _rowKey(TripStepRole? role, int? legIndex) => legIndex != null
      ? TripEasyRowKey(TripEasyRowKind.between, legIndex)
      : TripEasyRowKey(role == TripStepRole.comingBack ? TripEasyRowKind.comingBack : TripEasyRowKind.gettingThere);

  static Future<bool> arrangeMyself(BuildContext context, {TripStepRole? role, int? legIndex}) async {
    final c = TripPlanController.to;
    if (c.isReadOnly) return false;
    final key = _rowKey(role, legIndex);
    if (!await TripArrangeConfirm.show(context, key)) return false;
    if (!context.mounted) return false;
    final res = await TripArrangeConfirm.mark(context, key);
    if (res == null) return false;
    if (res is TripMarkBlocked) {
      AppToast.warning(TripStringsV2Find.cancelFirstTravel);
      return false;
    }
    return true;
  }

  static bool skipTravel({TripStepRole? role, int? legIndex}) {
    final c = TripPlanController.to;
    if (c.isReadOnly) return false;
    final key = _rowKey(role, legIndex);
    if (c.openRowsOf(key).isNotEmpty || c.confirmedRowOf(key) != null) {
      AppToast.warning(TripStringsV2Find.cancelFirstTravel);
      return false;
    }
    c.skipRow(key);
    return true;
  }

  static Future<void> pickStart(BuildContext context) async {
    final c = TripPlanController.to;
    if (c.isReadOnly) return;
    final p = await LocationSwitchSheet.pick(context, palette: templateModulePalette, title: TripStringsJourneyCard.pickStart);
    if (p == null) return;
    final moved = await c.setStartFrom(TripStartFrom(name: p.name, lat: p.latitude, lon: p.longitude));
    if (moved && context.mounted) await askSearchAgain(context);
  }

  static Future<void> askSearchAgain(BuildContext context) async {
    final c = TripPlanController.to;
    final city = c.startFrom?.name ?? '';
    final again = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: CardRadius.tile),
        title: const Text(
          TripStringsJourneyCard.startChanged,
          style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontWeight: FontWeight.w600, fontSize: 17),
        ),
        content: Text(
          TripStringsJourneyCard.searchFromAgain(city),
          style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, color: FitnessAppTheme.darkText),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 4,
        actions: [
          TextLink(label: TripStringsJourneyCard.later, onTap: () => Navigator.pop(ctx, false), tone: KitTone.trip),
          TextLink(label: TripStringsJourneyCard.searchAgain, onTap: () => Navigator.pop(ctx, true), tone: KitTone.trip),
        ],
      ),
    );
    if (again != true) return;
    final first = TripStepRole.values.firstWhere(
      (r) => c.journeyFor(r)?.startChanged == true,
      orElse: () => TripStepRole.gettingThere,
    );
    TripNavigation.openWays(first);
  }
}
