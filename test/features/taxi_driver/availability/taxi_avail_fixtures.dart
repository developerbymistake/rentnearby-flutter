import 'dart:async';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_api.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_controller.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_store.dart';
import 'package:bakhli/features/taxi_driver/taxi_driver_deps.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../support/owner_fakes.dart';

final DateTime availToday = DateTime(2026, 11, 26);

const String daysOffPath = '/taxis/me/days-off';

Map<String, dynamic> availJson({
  List<Map<String, dynamic>> daysOff = const [
    {'date': '2026-11-27', 'reason': 'Family function in Almora'},
    {'date': '2026-11-30', 'reason': null},
  ],
  List<String> booked = const ['2026-11-28'],
  bool plus = false,
  bool switchOn = true,
  int bookings = 3,
  int? daysOffCount,
  String today = '2026-11-26',
}) =>
    {
      'today': today,
      'window': {
        'upcomingTo': plus ? '2027-05-26' : '2026-12-06',
        'monthFrom': '2026-11-01',
        'monthTo': plus ? '2027-05-31' : '2026-11-30',
        'manualFrom': '2026-11-19',
        'manualTo': plus ? '2027-05-31' : '2026-12-06',
        'locked': !plus,
      },
      'monthsAhead': plus ? 6 : 0,
      'switchOn': switchOn,
      'daysOff': daysOff,
      'bookedDays': booked,
      'counts': {'month': '2026-11', 'bookings': bookings, 'daysOff': daysOffCount ?? daysOff.length},
    };

Map<String, dynamic> dayRow(String date, [String? reason]) => {'date': date, 'reason': reason};

DioException refusal(String path, int status, Map<String, dynamic> body, {Map<String, List<String>>? headers}) => DioException(
      requestOptions: RequestOptions(path: path),
      response: Response(
        requestOptions: RequestOptions(path: path),
        statusCode: status,
        data: body,
        headers: Headers.fromMap(headers ?? const {}),
      ),
      type: DioExceptionType.badResponse,
    );

DioException offlineError(String path) => DioException(requestOptions: RequestOptions(path: path), type: DioExceptionType.connectionError);

Map<String, dynamic> bucket429({String bucket = 'availability', int seconds = 1520}) => {
      'status': '429',
      'code': 429,
      'data': {'retryAfterSeconds': seconds, 'bucket': bucket, 'limit': 3},
      'error': {'message': 'You can change this 3 times an hour.', 'type': 'TooManyRequests'},
    };

class AvailFake {
  AvailFake({this.read, this.save});

  Map<String, dynamic>? read;
  Future<Map<String, dynamic>> Function(Map<String, dynamic> body)? save;
  bool readOffline = false;
  bool hangRead = false;
  bool hangSave = false;
  final List<Map<String, dynamic>> saves = [];
  Completer<Map<String, dynamic>>? readGate;

  late final FakeTransport transport = FakeTransport(_handle);

  int count(String prefix) => transport.calls.where((c) => c.startsWith(prefix)).length;

  Future<Map<String, dynamic>> _handle(String method, String path, Map<String, dynamic>? body) async {
    if (method == 'GET' && path == daysOffPath) {
      if (hangRead) return Completer<Map<String, dynamic>>().future;
      final gate = readGate;
      if (gate != null) return gate.future;
      final r = read;
      if (readOffline || r == null) throw refusal(path, 503, {'error': {'message': 'down'}});
      return {'data': r};
    }
    if (method == 'PUT' && path == daysOffPath) {
      saves.add(body ?? const {});
      if (hangSave) return Completer<Map<String, dynamic>>().future;
      final s = save;
      if (s != null) return s(body ?? const {});
      return {'data': read ?? availJson()};
    }
    throw offlineError(path);
  }
}

class AvailHarness {
  AvailHarness(this.fake, this.store, this.controller);

  final AvailFake fake;
  final TaxiAvailabilityStore store;
  final TaxiAvailabilityController controller;
}

TaxiAvailabilityStore availStore(AvailFake fake, {MyPlanModel plan = OwnerPlans.free, String user = 'user-a'}) {
  OwnerApi.transport = fake.transport;
  PlanGate.debugPlan = plan;
  return Get.put(TaxiAvailabilityStore(userId: () => user, clock: () => availToday));
}

void availBase() {
  Get.reset();
  Get.testMode = true;
  OwnerCache.clearAll();
  TaxiDriverDeps.debugReset();
  TaxiHourlyLimit.reset();
  Get.put<TabConfigController>(FakeTabs());
  final auth = FakeAuth();
  Get.put<AuthController>(auth);
  auth.signIn(role: 'TAXI_DRIVER', taxiStatus: 'Approved');
}

Future<AvailHarness> availSetUp(AvailFake fake, {MyPlanModel plan = OwnerPlans.free, bool load = true}) async {
  availBase();
  final store = availStore(fake, plan: plan);
  if (load) await store.refresh();
  final c = Get.put(TaxiAvailabilityController(store: store, clock: () => availToday), tag: TaxiAvailabilityController.tag);
  return AvailHarness(fake, store, c);
}

void availTearDown() {
  PlanGate.debugPlan = null;
  TaxiDriverDeps.debugReset();
  TaxiHourlyLimit.reset();
  resetOwnerTestState();
}
