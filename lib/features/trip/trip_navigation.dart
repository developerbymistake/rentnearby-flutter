import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../config/module_palette.dart';
import '../../widgets/location_switch_sheet.dart';
import 'trip_strings.dart';

class TripNavigation {
  static Future<void> start(BuildContext context) async {
    final picked = await LocationSwitchSheet.pick(context, palette: ModulePalette.trip, title: TripStrings.planATrip);
    if (picked == null) return;
    await Get.toNamed(AppRoutes.tripSpots, arguments: {'picked': picked});
  }

  static Future<void>? openSpots(PickedPlace picked, {String? tripId, Set<String> existingIds = const {}}) =>
      Get.toNamed(
        AppRoutes.tripSpots,
        arguments: {
          'picked': picked,
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
