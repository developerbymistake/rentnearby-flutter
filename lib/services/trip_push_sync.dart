import 'dart:async';
import 'package:get/get.dart';
import '../config/app_routes.dart';
import '../config/notification_types.dart';
import '../features/buddy/buddy_live.dart';
import '../features/stay/enquiries/stay_enquiries_controller.dart';
import '../features/taxi/journeys/journeys_controller.dart';
import '../features/taxi/leads/trip_leads_controller.dart';
import '../features/taxi/requests/controllers/driver_bookings_controller.dart';
import '../features/taxi/requests/controllers/driver_rating_controller.dart';
import '../features/taxi/requests/controllers/driver_ready_controller.dart';
import '../features/taxi/requests/controllers/driver_requests_controller.dart';
import '../features/trip/controllers/my_trips_controller.dart';
import '../features/trip/controllers/trip_plan_controller.dart';
import '../features/trip/controllers/trip_taxi_request_controller.dart';

class TripPushSync {
  const TripPushSync._();

  static const _tripRoutes = {
    AppRoutes.tripPlan,
    AppRoutes.tripReplies,
    AppRoutes.tripOverview,
    AppRoutes.tripTaxiStatus,
    AppRoutes.taxiRequests,
    AppRoutes.taxiBookings,
    AppRoutes.myTrips,
    AppRoutes.tripSummary,
    AppRoutes.stayEnquiries,
    AppRoutes.tripLeads,
    AppRoutes.myJourneys,
    AppRoutes.savedJourney,
  };

  static const _journeyRoutes = {AppRoutes.myJourneys, AppRoutes.savedJourney};

  static const _taxiRoutes = {AppRoutes.tripTaxiStatus, AppRoutes.tripOverview};

  static const _driverRoutes = {
    AppRoutes.taxiRequestRing,
    AppRoutes.taxiRequests,
    AppRoutes.taxiRequestDetail,
    AppRoutes.taxiBookings,
    AppRoutes.taxiRating,
    AppRoutes.taxiReady,
  };

  static Timer? _debounce;
  static bool _driver = false;
  static bool _driverReady = false;
  static bool _driverRating = false;
  static bool _journeys = false;
  static bool _taxi = false;
  static bool _enquiries = false;
  static String? _focusRoute;
  static String? _focusId;

  static bool isTripType(String? type) =>
      type != null &&
      (type.startsWith('Trip') || type.startsWith('trip_') || type.startsWith('Journey') || type.startsWith('journey_'));

  // Hub and FCM both deliver the same event in foreground; one refresh covers both.
  static void onPush(String? type, String? pushRoute, [Map<String, dynamic>? args]) {
    BuddyPushSync.onPush(type, pushRoute, args);
    final actionRoute = AppRoutes.liveTarget(pushRoute)?.route;
    final driver = _markDriver(type, actionRoute);
    final taxi = NotificationTypeKeys.isTravellerTaxi(type);
    final trip = taxi || isTripType(type) || _tripRoutes.contains(actionRoute);
    if (!driver && !trip) return;
    if (trip) {
      if ((type?.startsWith('Journey') ?? false) || _journeyRoutes.contains(actionRoute)) _journeys = true;
      _markTaxi(taxi || _taxiRoutes.contains(actionRoute));
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _run);
  }

  static void refreshNow(String route, {String? enquiryId}) {
    _markDriver(null, route);
    if (_journeyRoutes.contains(route)) _journeys = true;
    _markTaxi(_taxiRoutes.contains(route));
    if (enquiryId != null && enquiryId.isNotEmpty) {
      _focusRoute = route;
      _focusId = enquiryId;
    }
    _debounce?.cancel();
    _run();
  }

  static bool _markDriver(String? type, String? route) {
    if (!NotificationTypeKeys.isDriverTaxi(type) && !_driverRoutes.contains(route)) return false;
    _driver = true;
    if (NotificationTypeKeys.isRingsMissed(type) || route == AppRoutes.taxiReady) _driverReady = true;
    if (type == NotificationTypeKeys.taxiTripEnded || type == NotificationTypeKeys.taxiTripEndedWire || route == AppRoutes.taxiRating) {
      _driverRating = true;
    }
    return true;
  }

  static void _refreshDriver({required bool ready, required bool rating}) {
    DriverRequestsController.onPushIfRegistered();
    DriverBookingsController.onPushIfRegistered();
    if (rating && Get.isRegistered<DriverRatingController>()) unawaited(Get.find<DriverRatingController>().load());
    if (ready && Get.isRegistered<DriverReadyController>()) unawaited(Get.find<DriverReadyController>().loadReadiness());
  }

  // A taxi request push re-reads only the taxi state; anything else re-reads the enquiries.
  static void _markTaxi(bool taxi) {
    if (taxi) {
      _taxi = true;
    } else {
      _enquiries = true;
    }
  }

  static Future<void> _focusStay(StayEnquiriesController c, String enquiryId) async {
    final target = await c.bucketFor(enquiryId);
    if (target != null && target != c.bucket.value) {
      await c.selectBucket(target);
    } else {
      await c.refreshList();
    }
    c.focusId.value = enquiryId;
  }

  static void _run() {
    _debounce = null;
    final journeys = _journeys;
    _journeys = false;
    final taxi = _taxi;
    final enquiries = _enquiries;
    _taxi = false;
    _enquiries = false;
    final focusRoute = _focusRoute;
    final focusId = _focusId;
    _focusRoute = null;
    _focusId = null;
    final driver = _driver;
    final driverReady = _driverReady;
    final driverRating = _driverRating;
    _driver = false;
    _driverReady = false;
    _driverRating = false;
    if (driver) _refreshDriver(ready: driverReady, rating: driverRating);
    if (!journeys && !taxi && !enquiries) return;
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
    if (Get.isRegistered<TripPlanController>()) {
      final c = Get.find<TripPlanController>();
      if (enquiries) c.refreshEnquiries();
      if (taxi) unawaited(c.refreshTaxiState());
    }
    if (taxi) TripTaxiRequestController.onTaxiPushIfRegistered();
    if (Get.isRegistered<MyTripsController>()) Get.find<MyTripsController>().load();
    if (Get.isRegistered<JourneysController>() && (journeys || _journeyRoutes.contains(route))) {
      Get.find<JourneysController>().load(force: true);
    }
  }
}
