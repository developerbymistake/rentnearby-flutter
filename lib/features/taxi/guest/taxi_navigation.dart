import 'package:get/get.dart';
import '../../../config/app_routes.dart';

class TaxiNavigation {
  static Future<void>? openList({
    String? fromName,
    double? fromLat,
    double? fromLng,
    String? toName,
    double? toLat,
    double? toLng,
  }) {
    final preset = fromName != null && fromName.isNotEmpty && fromLat != null && fromLng != null;
    final toPreset = toName != null && toName.isNotEmpty && toLat != null && toLng != null;
    return Get.toNamed(
      AppRoutes.taxiList,
      arguments: preset
          ? {
              'fromName': fromName,
              'fromLat': fromLat,
              'fromLng': fromLng,
              if (toPreset) ...{'toName': toName, 'toLat': toLat, 'toLng': toLng},
            }
          : null,
    );
  }

  static Future<void>? openDetail(String id, {int? matchedFare, String? matchedToName}) => Get.toNamed(
        AppRoutes.taxiDetail,
        arguments: {
          'id': id,
          if (matchedFare != null) 'matchedFare': matchedFare,
          if (matchedToName != null) 'matchedToName': matchedToName,
        },
      );
}
