import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../config/app_tabs.dart';
import '../../controllers/auth_controller.dart';
import '../../services/storage_service.dart';
import '../../utils/app_toast.dart';
import '../buddy/triplimit/trip_limit_gate.dart';
import '../taxi/ways/taxi_ways_navigation.dart';
import 'controllers/my_trips_controller.dart';
import 'controllers/trip_plan_controller.dart';
import 'models/trip_city_model.dart';
import 'models/trip_enquiry_model.dart';
import 'models/trip_plan_model.dart';
import 'screens/trip_dates_sheet.dart';
import 'trip_constants.dart';
import 'trip_strings.dart';
import 'trip_strings_mcb_a1.dart';
import 'trip_strings_steps_a1.dart';
import 'trip_strings_mca_a3.dart';
import 'trip_strings_steps_k3.dart';
import 'trip_strings_v2_find.dart';
import 'utils/trip_easy_rules.dart';
import 'utils/trip_travel_rules.dart';
import 'widgets/trip_city_sheet.dart';
import 'widgets/trip_stay_city_sheet.dart';
import 'widgets/trip_journey_card.dart';

class TripNavigation {
  static void _clearDraftState() {
    StorageService.clearTripNewDraft();
    if (Get.isRegistered<TripPlanController>()) TripPlanController.to.releaseIfIdle();
  }

  static Future<void> startWithCities(List<TripCityModel> cities) async {
    if (cities.isEmpty || Get.currentRoute == AppRoutes.tripSpots) return;
    if (!await TripLimitGate.ensureSlot()) return;
    final draft = cities.length == 1 ? TripNewDraft.read() : null;
    final same = draft?.legs.where((l) => l.city.cityKey == cities.first.cityKey).toList() ?? const <TripDraftLeg>[];
    if (draft != null && same.isNotEmpty) {
      if (Get.isRegistered<TripPlanController>()) TripPlanController.to.releaseIfIdle();
      TripNewDraft.save(same, days: draft.days);
      await openCreate(cities, draftLegs: same);
      return;
    }
    _clearDraftState();
    await openCreate(cities);
  }

  static void enterOverview(String tripId) {
    final c = TripPlanController.to;
    c.openPages++;
    Get.offNamedUntil(
      AppRoutes.tripOverview,
      (r) => r.settings.name == AppRoutes.main || r.isFirst,
      arguments: {'tripId': tripId},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      c.openPages--;
      c.releaseIfIdle();
    });
  }

  static Future<void>? openCustomize(int legIndex) =>
      Get.toNamed(AppRoutes.tripCustomize, arguments: {'legIndex': legIndex});

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

  static Future<void>? openPlan({String? tripId, bool fresh = false}) =>
      Get.toNamed(AppRoutes.tripPlan, arguments: {'tripId': tripId, 'fresh': fresh});

  static Future<void>? openOverview({String? tripId}) =>
      Get.toNamed(AppRoutes.tripOverview, arguments: {'tripId': tripId ?? TripPlanController.to.trip.value?.id});

  static Future<void> continueTrip(String tripId) async {
    if (tripId.isEmpty) return;
    await openOverview(tripId: tripId);
    if (Get.isRegistered<MyTripsController>()) MyTripsController.to.load();
  }

  static Future<void>? openTaxiStatus({required String tripId, required String requestId, bool replace = false}) {
    final args = {'tripId': tripId, 'requestId': requestId};
    return replace
        ? Get.offNamed(AppRoutes.tripTaxiStatus, arguments: args)
        : Get.toNamed(AppRoutes.tripTaxiStatus, arguments: args);
  }

  // An active request opens its status; otherwise dates come first, then the request page.
  static Future<bool> openTaxiFlow(BuildContext context) async {
    final ref = TripPlanController.to.trip.value?.taxiRequest;
    final tripId = TripPlanController.to.trip.value?.id;
    if (tripId != null && ref != null && TripEasyRules.taxiRequestActive(ref)) {
      await openTaxiStatus(tripId: tripId, requestId: ref.requestId);
      return true;
    }
    return openTaxiRequest(context);
  }

  static Future<bool> openTaxiRequest(BuildContext context, {bool keepChoices = true, bool replace = false}) async {
    final c = TripPlanController.to;
    if (c.plan.value == null) return false;
    if (c.isReadOnly) {
      AppToast.info(TripStringsMcaA3.readOnlyBlock);
      return false;
    }
    if (c.netOff) {
      AppToast.warning(TripStringsV2Find.offlineAsk);
      return false;
    }
    final ok = await TripDatesSheet.ensure(context, heading: TripStringsV2Find.datesTitle, cta: TripStringsV2Find.saveDates);
    if (!ok || !c.hasDates) return false;
    c.clearSkip(const TripEasyRowKey(TripEasyRowKind.taxi));
    final saved = await c.flushPendingSave();
    final tripId = c.trip.value?.id;
    if (!saved || tripId == null) {
      AppToast.warning(TripStringsStepsK3.notSavedToTrip);
      return false;
    }
    final args = {'tripId': tripId, 'keepChoices': keepChoices};
    await (replace
        ? Get.offNamed(AppRoutes.tripTaxiRequest, arguments: args)
        : Get.toNamed(AppRoutes.tripTaxiRequest, arguments: args));
    return true;
  }

  static void backToPlan() => Get.until(
      (r) => r.settings.name == AppRoutes.tripPlan || r.settings.name == AppRoutes.tripOverview || r.isFirst);

  // Stay card: a city with an open or booked stay opens its replies; otherwise the shortlist list.
  static Future<bool> openStayFlow(BuildContext context, {int? leg}) async {
    final c = TripPlanController.to;
    final p = c.plan.value;
    if (p == null || c.tripGone.value || c.needsUpdate.value) return false;
    bool alive() => Get.isRegistered<TripPlanController>() && identical(TripPlanController.to, c);
    var k = leg;
    if (k == null) {
      if (p.legCount <= 1) {
        k = 1;
      } else {
        k = await TripStayCitySheet.pick(context);
        if (k == null || !alive()) return false;
      }
    }
    bool hasLeg() => k! >= 1 && k <= (c.plan.value?.legCount ?? 0);
    if (!hasLeg()) return false;
    final first = c.plan.value!.legStart(k);
    if (c.stayEnquiriesOf(k).any((e) => !e.isTaxi && (e.isOpen || e.isConfirmed || e.isBooked))) {
      await openReplies(first);
      return true;
    }
    if (c.isReadOnly) {
      AppToast.info(TripStringsMcaA3.readOnlyBlock);
      return false;
    }
    if (c.netOff) {
      AppToast.warning(TripStringsV2Find.offlineAsk);
      return false;
    }
    if (!context.mounted) return false;
    final ok = await TripDatesSheet.ensure(
      context,
      heading: TripStringsV2Find.datesTitle,
      cta: TripStringsV2Find.showStaysIn(c.plan.value!.cityNameOf(first)),
    );
    if (!alive() || !ok || !c.hasDates) return false;
    return _reopenAndOpen(c, k);
  }

  // Find another, Ask other stays and the problem sheet reopen the city's step like the Stay card.
  static Future<bool> reopenStayShortlist(int leg, {double? nearLat, double? nearLng}) async {
    if (!Get.isRegistered<TripPlanController>()) return false;
    final c = TripPlanController.to;
    final p = c.plan.value;
    if (p == null || c.tripGone.value || c.needsUpdate.value || leg < 1 || leg > p.legCount) return false;
    if (c.isReadOnly) {
      AppToast.info(TripStringsMcaA3.readOnlyBlock);
      return false;
    }
    if (c.netOff) {
      AppToast.warning(TripStringsV2Find.offlineAsk);
      return false;
    }
    return _reopenAndOpen(c, leg, nearLat: nearLat, nearLng: nearLng);
  }

  static Future<bool> _reopenAndOpen(TripPlanController c, int leg, {double? nearLat, double? nearLng}) async {
    bool alive() => Get.isRegistered<TripPlanController>() && identical(TripPlanController.to, c);
    final saved = await c.reopenStayStep(leg);
    if (!alive()) return false;
    if (!saved) {
      AppToast.warning(TripStringsStepsK3.notSavedToTrip);
      return false;
    }
    if (leg > (c.plan.value?.legCount ?? 0)) return false;
    await openStay(leg, nearLat: nearLat, nearLng: nearLng, shortlist: true);
    return true;
  }

  static void backToList() =>
      Get.until((r) => r.settings.name == AppRoutes.tripPlan || r.settings.name == AppRoutes.main || r.isFirst);

  static Future<void>? openStay(
    int legIndex, {
    bool split = false,
    double? nearLat,
    double? nearLng,
    List<int>? onlyDays,
    bool shortlist = false,
  }) =>
      Get.toNamed(AppRoutes.tripStay, arguments: {
        if (shortlist) 'shortlist': true,
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

  static Future<void> openWays(TripStepRole role) async {
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
    );
  }

  static Future<void> openSegmentWays(int legIndex) async {
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
        if (saved && c.hasDates) await openSegmentWays(legIndex);
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
    );
  }

  static Future<void> openJourney(String journeyId) async {
    await TaxiWaysNavigation.openSavedJourney(journeyId);
    if (Get.isRegistered<TripPlanController>()) unawaited(TripPlanController.to.refreshEnquiries());
  }

  static Future<void> openWhereToNext() async {
    if (!await TripLimitGate.ensureSlot()) return;
    await Get.toNamed(AppRoutes.tripWhere);
  }

  static Future<void>? openMyTrips() => Get.toNamed(AppRoutes.myTrips);

  static Future<void>? replaceWithMyTrips() => Get.offNamed(AppRoutes.myTrips);
}
