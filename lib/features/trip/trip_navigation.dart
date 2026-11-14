import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../config/app_tabs.dart';
import '../../controllers/auth_controller.dart';
import '../../services/storage_service.dart';
import '../../utils/app_toast.dart';
import '../taxi/ways/taxi_ways_controller.dart';
import '../taxi/ways/taxi_ways_navigation.dart';
import 'controllers/trip_plan_controller.dart';
import 'models/trip_city_model.dart';
import 'models/trip_enquiry_model.dart';
import 'models/trip_guide_args.dart';
import 'models/trip_plan_model.dart';
import 'screens/trip_dates_sheet.dart';
import 'trip_constants.dart';
import 'trip_strings.dart';
import 'trip_strings_mcb_a1.dart';
import 'trip_strings_steps_a1.dart';
import 'trip_strings_steps_k3.dart';
import 'trip_strings_v2_find.dart';
import 'utils/trip_travel_rules.dart';
import 'widgets/trip_city_sheet.dart';
import 'widgets/trip_journey_card.dart';

class TripNavigation {
  static void _clearDraftState() {
    StorageService.clearTripNewDraft();
    if (Get.isRegistered<TripPlanController>()) TripPlanController.to.releaseIfIdle();
  }

  static Future<void>? startWithCities(List<TripCityModel> cities) {
    if (cities.length == 1) {
      final draft = TripNewDraft.read();
      final same = draft?.legs.where((l) => l.city.cityKey == cities.first.cityKey).toList() ?? const <TripDraftLeg>[];
      if (draft != null && same.isNotEmpty) {
        if (Get.isRegistered<TripPlanController>()) TripPlanController.to.releaseIfIdle();
        TripNewDraft.save(same, days: draft.days);
        return openCreate(cities, draftLegs: same);
      }
    }
    _clearDraftState();
    return openCreate(cities);
  }

  static void openTripsTab() {
    Get.until((r) => r.settings.name == AppRoutes.main || r.isFirst);
    Get.find<AuthController>().switchToTab(AppTabs.trips);
  }

  static Future<void>? openSpots(
    TripCityModel city, {
    String? tripId,
    Set<String> existingIds = const {},
    int? legIndex,
    bool newLeg = false,
    int? pickDay,
    String? replaceSpotId,
  }) =>
      Get.toNamed(
        AppRoutes.tripSpots,
        arguments: {
          'city': city,
          'tripId': tripId,
          'existingIds': existingIds,
          'adding': true,
          'legIndex': ?legIndex,
          'newLeg': newLeg,
          'pickDay': ?pickDay,
          'replaceSpotId': ?replaceSpotId,
        },
      );

  static Future<TripLegEditBlock?> addCity(BuildContext context) async {
    final c = TripPlanController.to;
    final block = c.canAddLeg(null);
    if (block != TripLegEditBlock.none) {
      c.showLegBlock(block);
      return block;
    }
    final pick = await TripCitySheet.pick(
      context,
      mode: TripCitySheetMode.add,
      afterCity: c.lastCityName,
      inTrip: {for (final l in c.legs) l.cityKey},
    );
    if (pick == null) return null;
    final city = pick.city;
    final again = c.canAddLeg(city);
    if (again != TripLegEditBlock.none) {
      c.showLegBlock(again, city: city.name);
      return again;
    }
    if (!city.isReady) return c.addLeg(city, const []);
    await openSpots(city, tripId: c.trip.value?.id, newLeg: true);
    return c.legs.any((l) => l.cityKey == city.cityKey) ? TripLegEditBlock.none : null;
  }

  static Future<void>? openCreate(List<TripCityModel> cities, {List<TripDraftLeg> draftLegs = const []}) {
    if (cities.isEmpty) return null;
    return Get.toNamed(AppRoutes.tripSpots, arguments: {
      'city': cities.first,
      if (cities.length > 1) 'cities': cities,
      if (draftLegs.isNotEmpty) 'draftLegs': draftLegs,
    });
  }

  static Future<void>? openPlan({
    String? tripId,
    bool fresh = false,
    String? row,
    String? step,
    bool nudge = false,
    bool reopen = false,
    String? name,
  }) =>
      Get.toNamed(AppRoutes.tripPlan, arguments: {
        'tripId': tripId,
        'fresh': fresh,
        'row': ?row,
        'step': ?step,
        if (nudge) 'nudge': true,
        if (reopen) 'reopen': true,
        'name': ?name,
      });

  static void backToPlan() => Get.until((r) => r.settings.name == AppRoutes.tripPlan || r.isFirst);

  static Future<bool> helpMeFind(BuildContext context, TripEasyRowKey key, {GuideArgs? guide}) async {
    final c = TripPlanController.to;
    if (c.isReadOnly) return false;
    if (c.netOff) {
      AppToast.warning(TripStringsV2Find.offlineAsk);
      return false;
    }
    final p = c.plan.value;
    if (p == null) return false;
    final leg = key.legIndex ?? 1;
    final cta = switch (key.kind) {
      TripEasyRowKind.stay => TripStringsV2Find.showStaysIn(p.cityNameOf(p.legStart(leg))),
      TripEasyRowKind.taxi => TripStringsV2Find.showDrivers,
      _ => TripStringsV2Find.showWays,
    };
    final ok = await TripDatesSheet.ensure(context, heading: TripStringsV2Find.datesTitle, cta: cta);
    if (!ok || !c.hasDates) return false;
    switch (key.kind) {
      case TripEasyRowKind.stay:
        await openStay(leg, guide: guide);
      case TripEasyRowKind.taxi:
        await openTaxi(guide: guide);
      case TripEasyRowKind.gettingThere:
        await openWays(TripStepRole.gettingThere, guide: guide);
      case TripEasyRowKind.comingBack:
        await openWays(TripStepRole.comingBack, guide: guide);
      case TripEasyRowKind.between:
        await openSegmentWays(leg, guide: guide);
    }
    return true;
  }

  static Future<void>? openRepliesForRow(TripEasyRowKey key) {
    final c = TripPlanController.to;
    final p = c.plan.value;
    if (p == null) return null;
    switch (key.kind) {
      case TripEasyRowKind.stay:
        return openReplies(p.legStart(key.legIndex ?? 1));
      case TripEasyRowKind.taxi:
        final asked = c.taxiAskedDays;
        final day = asked.isNotEmpty ? asked.first : (c.taxiEnquiries.isEmpty ? null : c.firstPlanDayOf(c.taxiEnquiries.first));
        return openTaxiReplies(day ?? 1);
      case TripEasyRowKind.gettingThere:
        return _openRowJourney(p.steps.gettingThere.journeyId, () => openWays(TripStepRole.gettingThere));
      case TripEasyRowKind.comingBack:
        return _openRowJourney(p.steps.comingBack.journeyId, () => openWays(TripStepRole.comingBack));
      case TripEasyRowKind.between:
        final k = key.legIndex ?? 2;
        return _openRowJourney(p.legAt(k)?.arrival?.journeyId, () => openSegmentWays(k));
    }
  }

  static Future<void>? _openRowJourney(String? id, Future<void> Function() fallback) =>
      id == null || id.isEmpty ? fallback() : openJourney(id);

  static void backToList() =>
      Get.until((r) => r.settings.name == AppRoutes.tripPlan || r.settings.name == AppRoutes.main || r.isFirst);

  static Future<void>? openTaxi({List<int>? days, GuideArgs? guide}) =>
      Get.toNamed(AppRoutes.tripTaxi, arguments: {'days': ?days, if (guide != null) ...guide.toArgs()});

  static Future<void>? openStay(
    int legIndex, {
    bool split = false,
    double? nearLat,
    double? nearLng,
    List<int>? onlyDays,
    GuideArgs? guide,
  }) =>
      Get.toNamed(AppRoutes.tripStay, arguments: {
        if (guide != null) ...guide.toArgs(),
        'legIndex': legIndex,
        'split': split,
        'nearLat': ?nearLat,
        'nearLng': ?nearLng,
        if (onlyDays != null && onlyDays.isNotEmpty) 'onlyDays': onlyDays,
      });

  static Future<void>? openMap({int? day, String? tripId}) =>
      Get.toNamed(AppRoutes.tripMap, arguments: {'day': day, 'tripId': tripId});

  static Future<void>? openReplies(int day, {String? enquiryId}) {
    final tripId = TripPlanController.to.trip.value?.id;
    return Get.toNamed(AppRoutes.tripReplies, arguments: {'tripId': tripId, 'day': day, 'enquiryId': enquiryId});
  }

  static Future<void>? openTaxiReplies(int day, {String? enquiryId}) {
    final tripId = TripPlanController.to.trip.value?.id;
    return Get.toNamed(AppRoutes.tripTaxiReplies, arguments: {'tripId': tripId, 'day': day, 'enquiryId': enquiryId});
  }

  static Future<void>? openChatForEnquiry(TripEnquiryModel e) {
    final id = e.conversationId;
    if (id == null || id.isEmpty) return null;
    return Get.toNamed(AppRoutes.chatConversation, arguments: {
      'conversationId': id,
      'enquiryId': e.id,
      'listingType': 'Stay',
      'listingId': e.listingId,
      'stayTypeId': null,
      'otherPartyId': e.owner.id ?? '',
      'otherPartyName': e.owner.name ?? e.listingName,
      'listingTitle': e.listingName,
      'area': null,
      'isOwner': false,
      'status': 'Active',
      'isBlockedByMe': false,
    });
  }

  static Future<void> openWays(TripStepRole role, {GuideArgs? guide}) async {
    final c = TripPlanController.to;
    if (c.steps.endOf(role) == null) await c.ensureStartFrom();
    if (c.steps.endOf(role) == null) {
      final pickCtx = Get.context;
      if (pickCtx != null && pickCtx.mounted) await TripJourneyCard.pickStart(pickCtx);
    }
    final start = c.steps.endOf(role);
    if (start == null) {
      AppToast.warning(TripStringsStepsA1.pickStartFirst);
      return;
    }
    if (!c.hasDates) {
      final ctx = Get.context;
      if (ctx == null || !ctx.mounted) {
        AppToast.warning(TripStringsMcbA1.addDatesFirst);
        return;
      }
      final saved = await TripDatesSheet.ensure(ctx, heading: TripStringsV2Find.datesTitle, cta: TripStringsV2Find.showWays);
      if (!saved || !c.hasDates) return;
    }
    final going = role == TripStepRole.gettingThere;
    final city = going ? c.cityPlace : c.lastCityPlace;
    if (city == null) return;
    final people = c.settings.peopleCount;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var date = c.stepDate(role);
    if (date != null) {
      if (date.isAfter(today.add(const Duration(days: TripConstants.journeyMaxDaysAhead)))) {
        AppToast.warning(TripStringsMcbA1.pickDateWithinYear);
        return;
      }
      if (date.isBefore(today)) date = today;
    }
    if (c.travelPeopleCapped) AppToast.info(TripStrings.bigGroupCapped);
    await TaxiWaysNavigation.openFeed(
      from: going ? start.place : city,
      to: going ? city : start.place,
      date: date,
      people: people > 0 ? people.clamp(1, TripConstants.maxTravelPeople).toInt() : null,
      fromTrip: true,
      tripId: c.trip.value?.id,
      tripRole: role.name,
      guide: guide,
    );
  }

  static Future<void> openSegmentWays(int legIndex, {GuideArgs? guide}) async {
    final c = TripPlanController.to;
    switch (c.findWayBlock(legIndex)) {
      case TravelFindBlock.none:
        break;
      case TravelFindBlock.noDates:
        final ctx = Get.context;
        if (ctx == null || !ctx.mounted) {
          AppToast.warning(TripStringsMcbA1.addDatesFirst);
          return;
        }
        final saved = await TripDatesSheet.ensure(ctx, heading: TripStringsV2Find.datesTitle, cta: TripStringsV2Find.showWays);
        if (saved && c.hasDates) await openSegmentWays(legIndex, guide: guide);
        return;
      case TravelFindBlock.tooFarAhead:
        AppToast.warning(TripStringsMcbA1.pickDateWithinYear);
        return;
      case TravelFindBlock.taxiOff:
        AppToast.warning(TripStringsMcbA1.taxiOffHere);
        return;
      case TravelFindBlock.offline:
        AppToast.warning(TripStringsMcbA1.connectToFindWay);
        return;
      case TravelFindBlock.readOnly:
        if (c.trip.value == null) AppToast.warning(TripStringsStepsK3.notSavedToTrip);
        return;
    }
    final block = await c.prepareSegmentLink(legIndex);
    if (block != null) {
      AppToast.warning(block);
      return;
    }
    if (!Get.isRegistered<TripPlanController>() || !identical(TripPlanController.to, c)) return;
    final from = c.prevCityPlace(legIndex);
    final to = c.cityPlaceOf(legIndex);
    if (from == null || to == null) return;
    if (c.travelPeopleCapped) AppToast.info(TripStrings.bigGroupCapped);
    await TaxiWaysNavigation.openFeed(
      from: from,
      to: to,
      fromMyLocation: false,
      date: c.travelSearchDateOf(legIndex),
      people: c.travelPeople,
      tripId: c.trip.value?.id,
      tripLegIndex: legIndex,
      guide: guide,
    );
  }

  // The same ways search the feed runs for a car row, built without a screen so the guide can send from it.
  static Future<TaxiWaysController?> carWaysFor(TripEasyRowKey key) async {
    final c = TripPlanController.to;
    if (c.isReadOnly || !c.hasDates) return null;
    final today = DateTime.now();
    final floor = DateTime(today.year, today.month, today.day);
    if (key.kind == TripEasyRowKind.between) {
      final k = key.legIndex ?? 2;
      if (c.findWayBlock(k) != TravelFindBlock.none || await c.prepareSegmentLink(k) != null) return null;
      final from = c.prevCityPlace(k);
      final to = c.cityPlaceOf(k);
      if (from == null || to == null) return null;
      return TaxiWaysController(
        from: from,
        to: to,
        date: c.travelSearchDateOf(k),
        people: c.travelPeople,
        tripId: c.trip.value?.id,
        tripLegIndex: k,
      );
    }
    final role = key.kind == TripEasyRowKind.gettingThere ? TripStepRole.gettingThere : TripStepRole.comingBack;
    final start = c.steps.endOf(role);
    final city = role == TripStepRole.gettingThere ? c.cityPlace : c.lastCityPlace;
    if (start == null || city == null) return null;
    final going = role == TripStepRole.gettingThere;
    final raw = c.stepDate(role);
    final people = c.settings.peopleCount;
    return TaxiWaysController(
      from: going ? start.place : city,
      to: going ? city : start.place,
      date: raw != null && raw.isBefore(floor) ? floor : raw,
      people: people > 0 ? people.clamp(1, TripConstants.maxTravelPeople).toInt() : null,
      fromTrip: true,
      tripId: c.trip.value?.id,
      tripRole: role.name,
    );
  }

  static Future<void> openJourney(String journeyId) async {
    await TaxiWaysNavigation.openSavedJourney(journeyId);
    if (Get.isRegistered<TripPlanController>()) unawaited(TripPlanController.to.refreshEnquiries());
  }

  static Future<void>? openSummary(String tripId) => Get.toNamed(AppRoutes.tripSummary, arguments: {'tripId': tripId});

  static Future<void>? openWhereToNext() => Get.toNamed(AppRoutes.tripWhere);

  static Future<void>? openMyTrips() => Get.toNamed(AppRoutes.myTrips);

  static Future<void>? replaceWithMyTrips() => Get.offNamed(AppRoutes.myTrips);
}
