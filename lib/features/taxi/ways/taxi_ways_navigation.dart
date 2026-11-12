import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../config/app_routes.dart';
import '../../../models/place_result_model.dart';
import '../../trip/models/trip_guide_args.dart';
import 'models/taxi_ways_models.dart';

class TaxiWaysNavigation {
  static Future<void>? openFeed({
    required PlaceResult from,
    required PlaceResult to,
    bool fromMyLocation = false,
    DateTime? date,
    int? people,
    bool fromTrip = false,
    String? tripId,
    String? tripRole,
    int? tripLegIndex,
    GuideArgs? guide,
  }) =>
      Get.toNamed(AppRoutes.taxiWays, arguments: {
        if (guide != null) ...guide.toArgs(),
        'from': from,
        'to': to,
        'fromMyLocation': tripLegIndex == null && fromMyLocation,
        'date': ?date,
        'people': ?people,
        'fromTrip': fromTrip || tripLegIndex != null,
        'tripId': ?tripId,
        'tripRole': ?tripRole,
        'tripLegIndex': ?tripLegIndex,
      });

  static Future<dynamic>? openPlan(JourneyOpenArgs args) => Get.toNamed(AppRoutes.journeyPlan, arguments: args);

  static Future<dynamic>? openRoad(JourneyOpenArgs args) => Get.toNamed(AppRoutes.journeyRoad, arguments: args);

  static Future<dynamic>? replaceWithFeed(WayFeedArgs a) => Get.offNamed(AppRoutes.taxiWays, arguments: {
        'from': _place(a.from),
        'to': _place(a.to),
        'date': ?a.date,
        'people': ?a.people,
        'fromTrip': a.tripId != null,
        'tripId': ?a.tripId,
        'tripRole': ?a.tripRole,
        'tripLegIndex': ?a.tripLegIndex,
      });

  static PlaceResult _place(WayPlace p) => PlaceResult(name: p.name, subtitle: '', latLng: LatLng(p.lat, p.lng));

  static Future<void>? openMyJourneys({String? journeyId}) =>
      Get.toNamed(AppRoutes.myJourneys, arguments: journeyId == null ? null : {'journeyId': journeyId});

  static Future<void>? openSavedJourney(String id) =>
      Get.toNamed(AppRoutes.savedJourney, arguments: {'journeyId': id, 'id': id});
}
