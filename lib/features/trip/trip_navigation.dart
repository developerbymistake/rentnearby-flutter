import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../utils/app_toast.dart';
import '../taxi/ways/taxi_ways_navigation.dart';
import 'controllers/trip_plan_controller.dart';
import 'models/trip_city_model.dart';
import 'models/trip_enquiry_model.dart';
import 'models/trip_plan_model.dart';
import 'trip_strings_steps_a1.dart';
import 'widgets/trip_city_sheet.dart';

class TripNavigation {
  static Future<void> start(BuildContext context) async {
    final city = await TripCitySheet.pick(context);
    if (city == null) return;
    await Get.toNamed(AppRoutes.tripSpots, arguments: {'city': city});
  }

  static Future<void>? startWith(TripCityModel city) => Get.toNamed(AppRoutes.tripSpots, arguments: {'city': city});

  static Future<void>? openSpots(TripCityModel city, {String? tripId, Set<String> existingIds = const {}}) =>
      Get.toNamed(
        AppRoutes.tripSpots,
        arguments: {
          'city': city,
          'tripId': tripId,
          'existingIds': existingIds,
          'adding': true,
        },
      );

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
    final city = c.cityPlace;
    if (city == null) return null;
    final going = role == TripStepRole.gettingThere;
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

  static Future<void>? openJourney(String journeyId) => TaxiWaysNavigation.openSavedJourney(journeyId);

  static Future<void>? openSummary(String tripId) => Get.toNamed(AppRoutes.tripSummary, arguments: {'tripId': tripId});

  static Future<void>? openMyTrips() => Get.toNamed(AppRoutes.myTrips);

  static Future<void>? replaceWithMyTrips() => Get.offNamed(AppRoutes.myTrips);
}
