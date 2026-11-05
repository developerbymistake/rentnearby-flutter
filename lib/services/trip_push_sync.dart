import 'dart:async';
import 'package:get/get.dart';
import '../config/app_routes.dart';
import '../features/stay/enquiries/stay_enquiries_controller.dart';
import '../features/taxi/journeys/journeys_controller.dart';
import '../features/taxi/leads/trip_leads_controller.dart';
import '../features/trip/controllers/my_trips_controller.dart';
import '../features/trip/controllers/trip_plan_controller.dart';

class TripPushSync {
  const TripPushSync._();

  static const _tripRoutes = {
    AppRoutes.tripPlan,
    AppRoutes.tripReplies,
    AppRoutes.tripTaxiReplies,
    AppRoutes.myTrips,
    AppRoutes.tripSummary,
    AppRoutes.stayEnquiries,
    AppRoutes.tripLeads,
    AppRoutes.myJourneys,
    AppRoutes.savedJourney,
  };

  static const _journeyRoutes = {AppRoutes.myJourneys, AppRoutes.savedJourney};

  static Timer? _debounce;
  static bool _journeys = false;
  static String? _focusRoute;
  static String? _focusId;

  static bool isTripType(String? type) =>
      type != null &&
      (type.startsWith('Trip') || type.startsWith('trip_') || type.startsWith('Journey') || type.startsWith('journey_'));

  // Hub and FCM both deliver the same event in foreground; one refresh covers both.
  static void onPush(String? type, String? actionRoute) {
    if (!isTripType(type) && !_tripRoutes.contains(actionRoute)) return;
    if ((type?.startsWith('Journey') ?? false) || _journeyRoutes.contains(actionRoute)) _journeys = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _run);
  }

  static void refreshNow(String route, {String? enquiryId}) {
    if (_journeyRoutes.contains(route)) _journeys = true;
    if (enquiryId != null && enquiryId.isNotEmpty) {
      _focusRoute = route;
      _focusId = enquiryId;
    }
    _debounce?.cancel();
    _run();
  }

  static Future<void> _focusStay(StayEnquiriesController c, String enquiryId) async {
    final target = await c.bucketFor(enquiryId);
    if (target != null && target != c.bucket.value) {
      await c.selectBucket(target);
    } else {
      await c.refreshList();
    }
  }

  static void _run() {
    _debounce = null;
    final journeys = _journeys;
    _journeys = false;
    final focusRoute = _focusRoute;
    final focusId = _focusId;
    _focusRoute = null;
    _focusId = null;
    final route = Get.currentRoute;
    if (Get.isRegistered<StayEnquiriesController>()) {
      final c = Get.find<StayEnquiriesController>();
      if (focusId != null && focusRoute == AppRoutes.stayEnquiries && route == AppRoutes.stayEnquiries) {
        unawaited(_focusStay(c, focusId));
      } else if (route == AppRoutes.stayEnquiries || c.items.isNotEmpty) {
        if (!c.loading.value) c.refreshList();
      } else {
        c.loadBadge();
      }
    }
    if (Get.isRegistered<TripLeadsController>()) {
      final c = Get.find<TripLeadsController>();
      if (focusId != null && focusRoute == AppRoutes.tripLeads && route == AppRoutes.tripLeads) {
        unawaited(c.focus(focusId));
      } else if (route == AppRoutes.tripLeads || c.items.isNotEmpty) {
        if (!c.loading.value) c.refreshList();
      } else {
        c.loadBadge(force: true);
      }
    }
    if (Get.isRegistered<TripPlanController>()) Get.find<TripPlanController>().refreshEnquiries();
    if (Get.isRegistered<MyTripsController>()) Get.find<MyTripsController>().load();
    if (Get.isRegistered<JourneysController>() && (journeys || _journeyRoutes.contains(route))) {
      Get.find<JourneysController>().load(force: true);
    }
  }
}
