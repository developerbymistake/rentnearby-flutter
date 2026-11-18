import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/taxi/leads/trip_leads_controller.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_bookings_controller.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_rating_controller.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_ready_controller.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_requests_controller.dart';
import 'package:bakhli/features/taxi/requests/data/driver_request_repository.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/taxi/setup/taxi_setup_controller.dart';
import 'package:bakhli/features/taxi/taxi_option_sets.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:bakhli/services/taxi_ring_service.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../e2e_journeys/nearby/nearby_support.dart';

class WireAuth extends JAuth {
  WireAuth({this.driver = true});
  final bool driver;

  @override
  // ignore: must_call_super
  void onInit() {
    canListTaxis.value = driver;
  }

  @override
  bool get taxisEnabled {
    user.value;
    return driver;
  }

  @override
  Future<void> refreshProfile() async {}
}

class WirePlan extends PlanController {
  @override
  // ignore: must_call_super
  void onInit() {
    myPlan.value = const MyPlanModel(paymentEnabled: true, featureKey: 'Taxi');
  }
}

class WireTaxi extends TaxiSetupController {
  WireTaxi(this.model);
  final TaxiOwnerModel? model;
  final List<bool> availableCalls = [];

  @override
  Future<bool> load() {
    taxi.value = model;
    hasLoaded.value = true;
    return Future.value(true);
  }

  @override
  Future<bool> setAvailable(bool available) async {
    availableCalls.add(available);
    return true;
  }
}

class WireLeads extends TripLeadsController {
  WireLeads({int news = 0}) {
    newCount.value = news;
  }

  @override
  void reset() {}
  @override
  Future<void> loadBadge({bool force = false}) async {}
  @override
  Future<void> refreshList() async {}
  @override
  Future<void> load() async {}
}

class WireRequests extends DriverRequestsController {
  WireRequests({int news = 0}) {
    counts.value = DriverOfferCounts(newCount: news, booked: 0);
  }

  int pushes = 0;
  int reloads = 0;

  @override
  void onPush() => pushes++;

  @override
  Future<void> reloadList() async => reloads++;
}

class WireBookings extends DriverBookingsController {
  WireBookings() : super(onChanged: () {});
  int reloads = 0;

  @override
  Future<TaxiResult<DriverBookings>> reload() async {
    reloads++;
    return const TaxiFailed<DriverBookings>(message: 'fake');
  }
}

class WireRating extends DriverRatingController {
  int loads = 0;

  @override
  Future<TaxiResult<DriverRating>> load() async {
    loads++;
    return const TaxiFailed<DriverRating>(message: 'fake');
  }
}

class WireReadyRepo extends DriverRequestRepository {
  WireReadyRepo({this.missedRings = false});
  bool missedRings;

  DriverReadiness _readiness({bool notificationsOn = true}) => DriverReadiness.fromJson({
        'approved': true,
        'online': true,
        'ringReady': notificationsOn && !missedRings,
        'notificationsOn': notificationsOn,
        'hasValidToken': true,
        'missedRings': missedRings,
        'routesWithoutCity': 0,
      });

  @override
  Future<TaxiResult<DriverReadiness>> readiness() async => TaxiOk(_readiness());

  @override
  Future<TaxiResult<DriverReadiness>> reportDevice(DriverDeviceState state) async =>
      TaxiOk(_readiness(notificationsOn: state.notificationsOn));
}

class WireReady extends DriverReadyController {
  WireReady({WireReadyRepo? repo, bool notificationsOn = true})
      : super(
          repo: repo ?? WireReadyRepo(),
          deviceProbe: () async => TaxiRingDeviceState(
            notificationsOn: notificationsOn,
            ringChannelOn: true,
            manufacturer: 'Samsung',
            androidSdk: 34,
            appBuild: 69,
          ),
          batteryProbe: () async => true,
        );

  int readinessLoads = 0;
  int onlineReports = 0;

  @override
  Future<TaxiResult<DriverReadiness>> loadReadiness() {
    readinessLoads++;
    return super.loadReadiness();
  }

  @override
  Future<TaxiResult<DriverReadiness>> onOnlineSwitchedOn() {
    onlineReports++;
    return super.onOnlineSwitchedOn();
  }
}

class WireNotif extends GetxService implements NotificationService {
  WireNotif({this.denied = false});
  bool denied;

  @override
  Future<void> onInit() async {
    super.onInit();
  }

  @override
  Future<bool> isPermissionDenied() async => denied;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void wireBase({bool driver = true}) {
  Get.reset();
  Get.testMode = true;
  (Get.put<LocationController>(JLoc()) as JLoc).userLocation.value = const LatLng(29.2, 79.5);
  final auth = Get.put<AuthController>(WireAuth(driver: driver));
  auth.user.value = UserModel.fromJson({'id': 'u1', 'phoneNumber': '9876543210', 'name': 'Pradeep Kumar', 'createdAt': '2026-01-01T00:00:00Z'});
  Get.put<TabConfigController>(JTabs());
  Get.put<PlanController>(WirePlan());
}

TaxiOwnerModel wireTaxi({String status = TaxiStatus.approved, bool available = true}) => TaxiOwnerModel(
      id: 'o1',
      status: status,
      percent: 100,
      step1Done: true,
      routesDone: true,
      vehicleTypeId: 'v1',
      vehicleTypeName: 'Innova Crysta',
      seats: 7,
      plateDisplay: 'UK 07 TA 1234',
      platePhotoUrl: null,
      contactPhone: '9876543210',
      latitude: 29.2,
      longitude: 79.5,
      cityName: 'Haldwani',
      districtName: 'Nainital',
      minFare: 900,
      isAvailable: available,
      slug: 'uk07',
      pendingReportCount: 0,
      createdAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
      hasDrivingLicence: true,
      hasDateOfBirth: true,
      localDayRate: 2500,
      localDayKm: 120,
      routes: const [],
    );
