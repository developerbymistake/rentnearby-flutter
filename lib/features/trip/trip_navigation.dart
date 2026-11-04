import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../config/app_routes.dart';
import 'controllers/trip_plan_controller.dart';
import 'models/trip_city_model.dart';
import 'models/trip_enquiry_model.dart';
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

  static Future<void>? openPlan({String? tripId}) => Get.toNamed(AppRoutes.tripPlan, arguments: {'tripId': tripId});

  static Future<void>? openTaxi(int day) => Get.toNamed(AppRoutes.tripTaxi, arguments: {'day': day});

  static Future<void>? openStay(int day) => Get.toNamed(AppRoutes.tripStay, arguments: {'day': day});

  static Future<void>? openMap({int? day}) => Get.toNamed(AppRoutes.tripMap, arguments: {'day': day});

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

  static Future<void>? openSummary(String tripId) => Get.toNamed(AppRoutes.tripSummary, arguments: {'tripId': tripId});

  static Future<void>? openMyTrips() => Get.toNamed(AppRoutes.myTrips);

  static Future<void>? replaceWithMyTrips() => Get.offNamed(AppRoutes.myTrips);
}
