import 'package:get/get.dart';
import '../../../config/app_routes.dart';

class TaxiNavigation {
  static Future<void>? openList({
    String? fromName,
    double? fromLat,
    double? fromLng,
    String? fromCityId,
    String? fromDistrictId,
    String? toName,
    double? toLat,
    double? toLng,
    String? toCityId,
  }) {
    final preset = fromName != null && fromName.isNotEmpty && fromLat != null && fromLng != null;
    final toPreset = toName != null && toName.isNotEmpty && toLat != null && toLng != null;
    return Get.toNamed(
      AppRoutes.taxiList,
      arguments: preset || toPreset
          ? {
              if (preset) ...{
                'fromName': fromName,
                'fromLat': fromLat,
                'fromLng': fromLng,
                'fromCityId': fromCityId,
                'fromDistrictId': fromDistrictId,
              },
              if (toPreset) ...{'toName': toName, 'toLat': toLat, 'toLng': toLng, 'toCityId': toCityId},
            }
          : null,
    );
  }

  static Future<void>? openDetail(String id, {int? matchedFare, String? matchedToName}) => Get.toNamed(
        AppRoutes.taxiDetail,
        arguments: {
          'id': id,
          'matchedFare': ?matchedFare,
          'matchedToName': ?matchedToName,
        },
      );
}
