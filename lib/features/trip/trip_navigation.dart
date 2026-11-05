import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../utils/app_toast.dart';
import '../taxi/ways/taxi_ways_navigation.dart';
import 'controllers/trip_plan_controller.dart';
import 'models/trip_city_model.dart';
import 'models/trip_enquiry_model.dart';
import 'models/trip_plan_model.dart';
import 'screens/trip_details_sheet.dart';
import 'trip_strings_mcb_a1.dart';
import 'trip_strings_steps_a1.dart';
import 'utils/trip_travel_rules.dart';
import 'widgets/trip_city_sheet.dart';

class TripNavigation {
  static Future<void> start(BuildContext context) async {
    final pick = await TripCitySheet.pick(context);
    if (pick == null) return;
    await startWith(pick.city, next: pick.next);
  }

  static Future<void>? startWith(TripCityModel city, {TripCityModel? next}) =>
      Get.toNamed(AppRoutes.tripSpots, arguments: {'city': city, 'next': ?next});

  static Future<void>? openSpots(
    TripCityModel city, {
    String? tripId,
    Set<String> existingIds = const {},
    int? legIndex,
    bool newLeg = false,
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

  static Future<void>? openPlan({String? tripId, bool fresh = false}) =>
      Get.toNamed(AppRoutes.tripPlan, arguments: {'tripId': tripId, 'fresh': fresh});

  static Future<void>? openTaxi(int day, {double? nearLat, double? nearLng}) => Get.toNamed(
        AppRoutes.tripTaxi,
        arguments: {'day': day, 'nearLat': ?nearLat, 'nearLng': ?nearLng},
      );

  static Future<void>? openStay(int day, {double? nearLat, double? nearLng}) => Get.toNamed(
        AppRoutes.tripStay,
        arguments: {'day': day, 'nearLat': ?nearLat, 'nearLng': ?nearLng},
      );

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
      'roomTypeId': null,
      'plotTypeId': null,
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

  static Future<void>? openWays(TripStepRole role) {
    final c = TripPlanController.to;
    final start = c.startFrom;
    if (start == null) {
      AppToast.warning(TripStringsStepsA1.pickStartFirst);
      return null;
    }
    final going = role == TripStepRole.gettingThere;
    final city = going ? c.cityPlace : c.lastCityPlace;
    if (city == null) return null;
    final people = c.settings.peopleCount;
    return TaxiWaysNavigation.openFeed(
      from: going ? start.place : city,
      to: going ? city : start.place,
      date: c.stepDate(role),
      people: people > 0 ? people : null,
      fromTrip: true,
      tripId: c.trip.value?.id,
      tripRole: role.name,
    );
  }

  static Future<void>? openSegmentWays(int legIndex) {
    final c = TripPlanController.to;
    switch (c.findWayBlock(legIndex)) {
      case TravelFindBlock.none:
        break;
      case TravelFindBlock.noDates:
        final ctx = Get.context;
        if (ctx == null) {
          AppToast.warning(TripStringsMcbA1.addDatesFirst);
          return null;
        }
        return TripDetailsSheet.edit(ctx, heading: TripStringsMcbA1.addDatesFirst);
      case TravelFindBlock.tooFarAhead:
        AppToast.warning(TripStringsMcbA1.pickDateWithinYear);
        return null;
      case TravelFindBlock.taxiOff:
        AppToast.warning(TripStringsMcbA1.taxiOffHere);
        return null;
      case TravelFindBlock.offline:
        AppToast.warning(TripStringsMcbA1.connectToFindWay);
        return null;
      case TravelFindBlock.readOnly:
        return null;
    }
    final from = c.prevCityPlace(legIndex);
    final to = c.cityPlaceOf(legIndex);
    if (from == null || to == null) return null;
    return TaxiWaysNavigation.openFeed(
      from: from,
      to: to,
      fromMyLocation: false,
      date: c.travelDateOf(legIndex),
      people: c.travelPeople,
      tripId: c.trip.value?.id,
      tripLegIndex: legIndex,
    );
  }

  static Future<void>? openJourney(String journeyId) => TaxiWaysNavigation.openSavedJourney(journeyId);

  static Future<void>? openSummary(String tripId) => Get.toNamed(AppRoutes.tripSummary, arguments: {'tripId': tripId});

  static Future<void>? openMyTrips() => Get.toNamed(AppRoutes.myTrips);

  static Future<void>? replaceWithMyTrips() => Get.offNamed(AppRoutes.myTrips);
}
