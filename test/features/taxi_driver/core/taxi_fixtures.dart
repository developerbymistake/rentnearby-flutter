import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/home/owner_home_api.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_controller.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_controller.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';

class FakeHomeApi implements OwnerHomeApi {
  FakeHomeApi(this.result);

  Future<OwnerResult<OwnerHomeDto>> Function() result;
  int calls = 0;

  @override
  Future<OwnerResult<OwnerHomeDto>> load() {
    calls++;
    return result();
  }
}

class TaxiFakeAuth extends FakeAuth {
  @override
  Future<void> refreshProfile() async {}
}

Map<String, dynamic> att(String code, int priority, [Map<String, dynamic> args = const {}]) => {'code': code, 'priority': priority, 'args': args};

Map<String, dynamic> homeJson({
  String status = 'Approved',
  bool switchOn = true,
  bool takenDown = false,
  bool everApproved = true,
  bool areaPaused = false,
  bool plannerOff = false,
  bool featured = false,
  String? reason,
  List<Map<String, dynamic>> attention = const [],
  int? attentionCount,
  Map<String, dynamic>? taxi,
  int badge = 0,
  Map<String, dynamic>? routesMeter = const {'key': 'Routes', 'used': 1, 'limit': 1},
  String plate = 'UK 04 TA 2231',
  Map<String, dynamic>? planCard,
  String? vehicleName = 'Maruti Ertiga',
  int? seats = 6,
  String? photo,
}) =>
    {
      'role': 'TAXI_DRIVER',
      'today': '2026-11-21',
      'paymentEnabled': true,
      'listing': {
        'id': 't1',
        'kind': 'Taxi',
        'status': status,
        'everApproved': everApproved,
        'name': plate,
        'plate': plate,
        'vehicleName': vehicleName,
        'seats': seats,
        'displayPhotoUrl': photo,
        'switchOn': switchOn,
        'isFeatured': featured,
        'takenDown': takenDown,
        'rejectedReason': reason,
        'areaPaused': areaPaused,
        'plannerOff': plannerOff,
        'routesMeter': routesMeter,
      },
      'attention': attention,
      'attentionCount': attentionCount ?? attention.length,
      'numbers': {'taxi': taxi ?? {'newRequests': 0}, 'centreBadge': badge},
      'planCard': ?planCard,
    };

Map<String, dynamic> taxiJson({
  String status = 'Approved',
  int routes = 1,
  int hidden = 0,
  bool featured = false,
  int reports = 0,
  int bookings = 0,
  bool localRate = true,
  bool submitted = true,
  Map<String, dynamic>? routesMeter,
}) {
  const names = ['Nainital', 'Mukteshwar', 'Almora', 'Ranikhet', 'Kausani', 'Bhimtal', 'Binsar'];
  const fares = [1800, 2600, 3200, 3000, 3800, 1500, 2100];
  Map<String, dynamic> route(int i) => {
        'id': 'r$i',
        'routeIndex': i + 1,
        'fromName': 'Haldwani',
        'toName': names[i % names.length],
        'fare': fares[i % fares.length],
        'tripType': 'OneWay',
        'fromCityKey': 1,
        'toCityKey': i + 2,
      };
  return {
    'id': 't1',
    'status': status,
    'percent': 100,
    'step1Done': true,
    'routesDone': true,
    'submitted': submitted,
    'vehicleTypeName': 'Maruti Ertiga',
    'seats': 6,
    'numberPlate': 'UK04TA2231',
    'plateDisplay': 'UK 04 TA 2231',
    'contactPhone': '9876511223',
    'cityName': 'Haldwani',
    'districtName': 'Nainital',
    'routes': [for (var i = 0; i < routes; i++) route(i)],
    'hiddenRoutes': [for (var i = 0; i < hidden; i++) route(routes + i)],
    'minFare': 1800,
    'slug': 'ramesh-ertiga',
    'createdAt': '2026-11-01T10:00:00Z',
    'everApproved': true,
    'localDayRate': localRate ? 2500 : null,
    'localDayKm': localRate ? 120 : null,
    'isFeatured': featured,
    'reportCount': reports,
    'activeBookingCount': bookings,
    'routesMeter': routesMeter,
  };
}

class TaxiHarness {
  TaxiHarness._(this.auth, this.home, this.api);

  final FakeAuth auth;
  final TaxiDriverHomeController home;
  final FakeHomeApi api;

  static TaxiHarness setUp(
    Map<String, dynamic> json, {
    bool denied = false,
    String name = 'Ramesh Negi',
    bool registerHome = true,
    bool offline = false,
    DateTime Function()? clock,
    Future<OwnerResult<void>> Function(bool on)? switchCall,
  }) {
    Get.reset();
    Get.testMode = true;
    Get.put<TabConfigController>(FakeTabs());
    final auth = TaxiFakeAuth();
    Get.put<AuthController>(auth);
    auth.signIn(role: 'TAXI_DRIVER', taxiStatus: 'Approved');
    auth.profileName.value = name;
    final api = FakeHomeApi(() async => offline ? OwnerOffline<OwnerHomeDto>() : OwnerOk<OwnerHomeDto>(OwnerHomeDto.fromJson(json)));
    final home = TaxiDriverHomeController(api: api, deniedProbe: () async => denied, userId: () => 'user-a', clock: clock, switchCall: switchCall);
    if (registerHome) Get.put<TaxiDriverHomeController>(home);
    return TaxiHarness._(auth, home, api);
  }
}

abstract final class TaxiHarnessProbe {
  static TaxiDriverHomeController? home;
}

TaxiHubController hubFor(Map<String, dynamic>? taxi, {MyPlanModel plan = OwnerPlans.free, Future<OwnerResult<void>> Function()? deleteTaxiCall, Future<OwnerResult<void>> Function(String routeId)? deleteRouteCall}) {
  Get.reset();
  Get.testMode = true;
  Get.put<TabConfigController>(FakeTabs());
  final auth = TaxiFakeAuth();
  Get.put<AuthController>(auth);
  auth.signIn(role: 'TAXI_DRIVER', taxiStatus: 'Approved');
  PlanGate.debugPlan = plan;
  return Get.put(TaxiHubController(userId: () => 'user-a', fetch: () async => {'data': taxi}, deleteTaxiCall: deleteTaxiCall, deleteRouteCall: deleteRouteCall), tag: TaxiHubController.tag);
}
