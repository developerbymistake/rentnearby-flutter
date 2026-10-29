import 'package:get/get.dart';
import '../../../config/app_routes.dart';

class TaxiNavigation {
  static Future<void>? openList({String? fromName, double? fromLat, double? fromLng}) {
    final preset = fromName != null && fromName.isNotEmpty && fromLat != null && fromLng != null;
    return Get.toNamed(
      AppRoutes.taxiList,
      arguments: preset ? {'fromName': fromName, 'fromLat': fromLat, 'fromLng': fromLng} : null,
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
