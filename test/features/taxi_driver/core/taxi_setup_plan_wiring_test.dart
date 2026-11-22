import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/owner_core/plan/plan_bindings.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart';
import 'package:bakhli/features/taxi/setup/taxi_repository.dart';
import 'package:bakhli/features/taxi/setup/taxi_route_strings.dart';
import 'package:bakhli/features/taxi/setup/taxi_routes_screen.dart';
import 'package:bakhli/features/taxi/setup/taxi_setup_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/repositories/plan_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import '../../../e2e_journeys/nearby/nearby_support.dart';
import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';

// FT-01: a Draft driver reaches /taxi-setup without MainScreen. The plan is the real PlanController
// fed by a fake /plans/me, never PlanGate.debugPlan.

class _Auth extends JAuth {
  @override
  bool get taxisEnabled {
    user.value;
    return true;
  }

  @override
  Future<void> refreshProfile() async {}
}

class _Repo extends TaxiRepository {
  _Repo({this.refuse});

  final Map<String, dynamic>? refuse;
  final List<List<Map<String, dynamic>>> saved = [];

  @override
  Future<TaxiOwnerModel?> saveRoutes(List<Map<String, dynamic>> routes) async {
    final r = refuse;
    if (r != null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/taxis/me/routes'),
        response: Response(requestOptions: RequestOptions(path: '/taxis/me/routes'), statusCode: 409, data: r),
        type: DioExceptionType.badResponse,
      );
    }
    saved.add(routes);
    return _taxi([for (final x in routes) {...x, 'id': 'n${saved.length}'}]);
  }
}

const _haldwani = TripCityModel(cityKey: 210108988, name: 'Haldwani', districtName: 'Nainital', stateName: 'Uttarakhand', latitude: 29.22, longitude: 79.51);
const _nainital = TripCityModel(cityKey: 210109088, name: 'Nainital', districtName: 'Nainital', stateName: 'Uttarakhand', latitude: 29.39, longitude: 79.45);
const _almora = TripCityModel(cityKey: 210003898, name: 'Almora', districtName: 'Almora', stateName: 'Uttarakhand', latitude: 29.6, longitude: 79.66);

Map<String, dynamic> _route(String id, String to, int toKey) => {
      'id': id,
      'routeIndex': 1,
      'fromName': 'Haldwani',
      'fromLatitude': 29.22,
      'fromLongitude': 79.51,
      'toName': to,
      'toLatitude': 29.39,
      'toLongitude': 79.45,
      'fare': 1500,
      'tripType': 'OneWay',
      'fromCityKey': 210108988,
      'toCityKey': toKey,
    };

TaxiOwnerModel _taxi(List<Map<String, dynamic>> routes) => TaxiOwnerModel.fromJson({
      'id': 't1',
      'status': 'Draft',
      'step1Done': true,
      'localDayRate': 2500,
      'localDayKm': 120,
      'cityName': 'Haldwani',
      'latitude': 29.22,
      'longitude': 79.51,
      'routes': routes,
    });

Future<(TaxiSetupController, _Repo, FakePlanRepository)> _setup({required Map<String, dynamic> me, bool planFails = false, Map<String, dynamic>? refuse}) async {
  Get.reset();
  PlanGate.debugPlan = null;
  final plans = FakePlanRepository([me]);
  if (planFails) plans.failWith = Exception('offline');
  Get.put<PlanRepository>(plans, permanent: true);
  Get.put<LocationController>(JLoc());
  Get.put<AuthController>(_Auth()).user.value =
      UserModel.fromJson({'id': 'u1', 'phoneNumber': '9876543210', 'name': 'Pradeep', 'createdAt': '2026-01-01T00:00:00Z'});
  Get.put<TabConfigController>(JTabs());
  Get.put<TripCityCatalog>(TripCityCatalog()..seedForTest(const [_haldwani, _nainital, _almora]), permanent: true);
  final repo = _Repo(refuse: refuse);
  final c = Get.put<TaxiSetupController>(TaxiSetupController(repo: repo));
  c.taxi.value = _taxi([_route('r1', 'Nainital', 210109088)]);
  return (c, repo, plans);
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).first);
  await t.pump();
  await t.tap(find.text(text).first, warnIfMissed: false);
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _addSecondRoute(WidgetTester t) async {
  if (find.text(TaxiRouteStrings.chooseCity).evaluate().isEmpty) await _tapText(t, 'Add another route');
  await _tapText(t, TaxiRouteStrings.chooseCity);
  await settlePhone(t);
  await t.tap(find.text('Almora').last);
  await settlePhone(t);
  await _tapText(t, 'One way');
  await t.enterText(find.byType(EditableText).first, '2400');
  await t.pump();
  await t.tap(find.text('Save route').last);
  await t.pump(const Duration(milliseconds: 700));
  await settlePhone(t);
}

Future<void> _open(WidgetTester t) async {
  await pumpPhone(t, const TaxiRoutesScreen(), size: const Size(392, 1500), toastHost: true);
  await settlePhone(t);
}

Future<void> _clear(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 5));
}

void main() {
  tearDown(() {
    PlanBindings.dispose();
    PlanGate.debugPlan = null;
    Get.reset();
  });

  testWidgets('Free, payment ON: saving route 2 opens G1 (See Plus / Not now), nothing is sent', (t) async {
    final (_, repo, plans) = await _setup(me: {'paymentEnabled': true, 'limits': {'routes': 1}});
    await _open(t);
    expect(plans.meCalls, 1, reason: 'the routes screen registers the plan without MainScreen');
    expect(Get.isRegistered<PlanController>(), isTrue);
    expect(PlanGate.loaded, isTrue);
    await _addSecondRoute(t);
    expect(find.text('See Plus'), findsWidgets);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('1 route on Free'), findsOneWidget);
    expect(repo.saved, isEmpty);
    expect(find.textContaining('You can add up to'), findsNothing);
    await _clear(t);
  });

  testWidgets('payment OFF: route 2 saves and the meter reads 2 of 5', (t) async {
    final (_, repo, _) = await _setup(me: {'paymentEnabled': false, 'limits': {'routes': 5}});
    await _open(t);
    await _addSecondRoute(t);
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single, hasLength(2));
    expect(find.text('Not now'), findsNothing);
    expect(find.text('2 of 5'), findsWidgets);
    await _clear(t);
  });

  testWidgets('plan not loaded: meter skeleton, no local refusal; server 409 opens G1 from the refusal body', (t) async {
    final (_, repo, _) = await _setup(
      me: {'paymentEnabled': true},
      planFails: true,
      refuse: {
        'error': {'type': 'TaxiRouteLimit', 'message': '1 route on Free. Get Plus for more.'},
        'data': {'key': 'Routes', 'limit': 1, 'used': 1, 'canUpgrade': true},
      },
    );
    await _open(t);
    expect(PlanGate.loaded, isFalse);
    expect(find.byKey(const ValueKey('routes_meter_skeleton')), findsOneWidget);
    await _addSecondRoute(t);
    expect(repo.saved, isEmpty);
    expect(find.text('Not now'), findsOneWidget, reason: 'G1 from the body canUpgrade');
    expect(find.text('1 route on Free'), findsOneWidget);
    expect(find.text('1 route on Free. Get Plus for more.'), findsNothing, reason: 'no double toast');
    await _clear(t);
  });

  testWidgets('409 without canUpgrade: one info toast with the server message, no sheet', (t) async {
    final (c, _, _) = await _setup(
      me: {'paymentEnabled': true},
      planFails: true,
      refuse: {
        'error': {'type': 'TaxiRouteLimit', 'message': 'You can add up to 1 route.'},
        'data': {'key': 'Routes', 'limit': 1, 'used': 1, 'canUpgrade': false},
      },
    );
    await _open(t);
    await _addSecondRoute(t);
    expect(find.text('Not now'), findsNothing);
    expect(c.lastErrorType, 'TaxiRouteLimit');
    expect(c.lastErrorMessage, 'You can add up to 1 route.');
    expect(find.text('2 of 1'), findsNothing, reason: 'no meter from the default plan before /plans/me answers');
    await _clear(t);
  });
}
