import 'dart:async';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart';
import 'package:bakhli/features/taxi/setup/taxi_setup_controller.dart';
import 'package:bakhli/features/taxi/taxi_option_sets.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../e2e_journeys/nearby/nearby_support.dart';

class SetupAuth extends JAuth {
  @override
  bool get taxisEnabled {
    user.value;
    return true;
  }

  @override
  Future<void> refreshProfile() async {}
}

class SetupPlan extends PlanController {
  SetupPlan(this.plan);
  final MyPlanModel plan;

  @override
  // ignore: must_call_super
  void onInit() {
    myPlan.value = plan;
  }
}

class SetupTaxi extends TaxiSetupController {
  SetupTaxi(this.model, {this.submitOk = true}) {
    taxi.value = model;
    hasLoaded.value = model != null;
  }
  final TaxiOwnerModel? model;
  final bool submitOk;
  int submits = 0;

  @override
  Future<bool> load() {
    taxi.value = model;
    hasLoaded.value = true;
    return Future.value(true);
  }

  @override
  Future<bool> submit() async {
    submits++;
    return submitOk;
  }
}

TaxiRouteModel setupRoute(String id, String from, String to, int fare, {String trip = 'OneWay'}) => TaxiRouteModel(
      id: id,
      routeIndex: 0,
      fromName: from,
      fromLatitude: 29.22,
      fromLongitude: 79.51,
      toName: to,
      toLatitude: 29.39 + id.length * 0.01,
      toLongitude: 79.45,
      fare: fare,
      tripType: trip,
      fromCityKey: 1,
      toCityKey: 2,
    );

TaxiOwnerModel setupTaxi({
  String status = TaxiStatus.draft,
  int percent = 0,
  bool step1 = false,
  bool identity = false,
  List<TaxiRouteModel> routes = const [],
  int? rate,
  int? km,
  String? plateUrl,
  String? displayUrl,
  bool everApproved = false,
  bool platePhotoLocked = false,
}) =>
    TaxiOwnerModel(
      id: 'o1',
      status: status,
      percent: percent,
      step1Done: step1,
      routesDone: routes.isNotEmpty,
      vehicleTypeId: step1 ? 'v3' : null,
      vehicleTypeName: step1 ? 'Maruti Ertiga' : null,
      seats: step1 ? 6 : null,
      plateDisplay: step1 ? 'UK 04 TA 2231' : null,
      platePhotoUrl: plateUrl,
      displayPhotoUrl: displayUrl,
      platePhotoLocked: platePhotoLocked,
      everApproved: everApproved,
      contactPhone: step1 ? '9876511223' : null,
      latitude: 29.22,
      longitude: 79.51,
      cityName: step1 ? 'Haldwani' : null,
      districtName: 'Nainital',
      minFare: routes.isEmpty ? null : routes.first.fare,
      isAvailable: true,
      slug: 'uk04',
      createdAt: DateTime.now().toUtc(),
      hasDrivingLicence: identity,
      hasDateOfBirth: identity,
      localDayRate: rate,
      localDayKm: km,
      routes: routes,
    );

const setupFree = MyPlanModel(paymentEnabled: true, trialAvailable: true, featureKey: 'Taxi');

void setUpTaxiSetup(TaxiOwnerModel? model, {MyPlanModel plan = setupFree, bool canCorrect = false}) {
  Get.reset();
  Get.testMode = true;
  (Get.put<LocationController>(JLoc()) as JLoc).userLocation.value = const LatLng(29.22, 79.51);
  final auth = Get.put<AuthController>(SetupAuth());
  auth.user.value = UserModel.fromJson({
    'id': 'u1',
    'phoneNumber': '9876511223',
    'name': 'Pradeep Kumar',
    'createdAt': '2026-01-01T00:00:00Z',
    'role': 'TAXI_DRIVER',
    'roleConfirmed': true,
    'canCorrectRole': canCorrect,
  });
  Get.put<TabConfigController>(JTabs());
  Get.put<PlanController>(SetupPlan(plan));
  PlanGate.debugPlan = plan;
  Get.put<TaxiSetupController>(SetupTaxi(model));
}

void tearDownTaxiSetup() {
  PlanGate.debugPlan = null;
  Get.reset();
}
