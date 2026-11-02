import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../config/app_routes.dart';
import 'models/trip_city_model.dart';
import 'widgets/trip_city_sheet.dart';

class TripNavigation {
  static Future<void> start(BuildContext context) async {
    final city = await TripCitySheet.pick(context);
    if (city == null) return;
    await Get.toNamed(AppRoutes.tripSpots, arguments: {'city': city});
  }

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

  static Future<void>? openMap({int day = 1}) => Get.toNamed(AppRoutes.tripMap, arguments: {'day': day});

  static Future<void>? openMyTrips() => Get.toNamed(AppRoutes.myTrips);

  static Future<void>? replaceWithMyTrips() => Get.offNamed(AppRoutes.myTrips);
}
