import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../models/place_result_model.dart';

class TaxiWaysNavigation {
  static Future<void>? openFeed({
    required PlaceResult from,
    required PlaceResult to,
    bool fromMyLocation = false,
    DateTime? date,
    int? people,
    bool fromTrip = false,
  }) =>
      Get.toNamed(AppRoutes.taxiWays, arguments: {
        'from': from,
        'to': to,
        'fromMyLocation': fromMyLocation,
        'date': ?date,
        'people': ?people,
        'fromTrip': fromTrip,
      });

  static Future<void>? openPlan({required String planKey, required String controllerTag}) =>
      Get.toNamed(AppRoutes.journeyPlan, arguments: {'planKey': planKey, 'tag': controllerTag});

  static Future<void>? openRoad({required String planKey, required String controllerTag}) =>
      Get.toNamed(AppRoutes.journeyRoad, arguments: {'planKey': planKey, 'tag': controllerTag});

  static Future<void>? openMyJourneys({String? journeyId}) =>
      Get.toNamed(AppRoutes.myJourneys, arguments: journeyId == null ? null : {'journeyId': journeyId});

  static Future<void>? openSavedJourney(String id) =>
      Get.toNamed(AppRoutes.savedJourney, arguments: {'journeyId': id, 'id': id});

  static ({String planKey, String tag})? planArgs(Object? args) {
    if (args is! Map) return null;
    final key = args['planKey'];
    final tag = args['tag'];
    if (key is! String || key.isEmpty || tag is! String || tag.isEmpty) return null;
    return (planKey: key, tag: tag);
  }
}
