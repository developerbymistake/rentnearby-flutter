import 'dart:convert';
import 'dart:io';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/repositories/plan_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class FakeTabs extends TabConfigController {
  FakeTabs({Set<String>? off}) : off = off ?? <String>{};

  Set<String> off;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  bool isActive(String tabKey) {
    version.value;
    return !off.contains(tabKey);
  }

  void setOff(Set<String> keys) {
    off = keys;
    version.value++;
  }
}

class FakeAuth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}

  void signIn({required String role, String? stayStatus, String? taxiStatus, bool listingDeleted = false, String id = 'user-a'}) {
    roleKey.value = role;
    canListStays.value = role == 'STAY_OWNER';
    canListTaxis.value = role == 'TAXI_DRIVER';
    user.value = UserModel(
      id: id,
      phoneNumber: '9000000000',
      createdAt: DateTime(2026),
      role: role,
      roleConfirmed: true,
      stayStatus: stayStatus,
      taxiStatus: taxiStatus,
      listingDeleted: listingDeleted,
    );
    syncShell();
  }
}

abstract final class OwnerPlans {
  static const free = MyPlanModel(paymentEnabled: true, trialAvailable: true);
  static const freeNoTrial = MyPlanModel(paymentEnabled: true);
  static const trial = MyPlanModel(paymentEnabled: true, isPaid: true, isDefault: false, source: 'Trial', limits: plusLimits);
  static const plus = MyPlanModel(paymentEnabled: true, isPaid: true, isDefault: false, limits: plusLimits);
  static const paymentOff = MyPlanModel(paymentEnabled: false, limits: plusLimits);
  static const grant = MyPlanModel(paymentEnabled: false, isPaid: true, isDefault: false, source: 'AdminGrant', limits: plusLimits);

  static const plusLimits = PlanLimitsModel(
    photos: 8,
    roomTypes: 6,
    routes: 5,
    ringWeight: 2,
    calendarEntries: 50,
    blockedRanges: 10,
    upcomingDays: 183,
    monthsAhead: 6,
    monthSummary: true,
    reminders: true,
    specialPrices: 5,
    jobsPosts: 4,
    priority: 1,
    featured: true,
  );
}

class FakeTransport extends OwnerTransport {
  FakeTransport(this.handler);

  final Future<Map<String, dynamic>> Function(String method, String path, Map<String, dynamic>? body) handler;
  final List<String> calls = [];

  @override
  Future<Map<String, dynamic>> get(String path, Map<String, dynamic>? params) {
    calls.add('GET $path');
    return handler('GET', path, params);
  }

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) {
    calls.add('POST $path');
    return handler('POST', path, body);
  }

  @override
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) {
    calls.add('PUT $path');
    return handler('PUT', path, body);
  }

  @override
  Future<Map<String, dynamic>> delete(String path, Map<String, dynamic>? params) {
    calls.add('DELETE $path');
    return handler('DELETE', path, params);
  }
}

Future<void> initTestStorage(String name) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => Directory.systemTemp.createTempSync(name).path,
  );
  await GetStorage.init();
  await GetStorage.init(OwnerCache.container);
}

Map<String, dynamic> loadSample(String name) =>
    jsonDecode(File('test/features/owner_core/samples/$name.json').readAsStringSync()) as Map<String, dynamic>;

/// The sample plus: each key removed, each value null, each value of a wrong type, an extra key, an empty map.
/// Nested maps are varied too, one level deep.
Iterable<Map<String, dynamic>> jsonVariants(Map<String, dynamic> sample) sync* {
  yield sample;
  yield const <String, dynamic>{};
  yield {...sample, 'unknownExtraKey': {'x': 1}};
  const wrong = <Object?>[null, 'x', 7, <Object?>[], <String, Object?>{}, true];
  for (final key in sample.keys) {
    yield {...sample}..remove(key);
    for (final w in wrong) {
      yield {...sample, key: w};
    }
    final v = sample[key];
    if (v is Map<String, dynamic>) {
      for (final inner in jsonVariants(v).take(40)) {
        yield {...sample, key: inner};
      }
    }
    if (v is List && v.isNotEmpty && v.first is Map<String, dynamic>) {
      final first = v.first as Map<String, dynamic>;
      for (final innerKey in first.keys) {
        for (final w in wrong) {
          yield {...sample, key: [{...first, innerKey: w}]};
        }
      }
      yield {...sample, key: ['x', 7, null]};
    }
  }
}

List<T> rows<T>(int n, T Function(int i) build) => [for (var i = 0; i < n; i++) build(i)];

void resetOwnerTestState() {
  OwnerApi.debugReset();
  Get.reset();
}

/// `/plans/me` from a queue of server bodies; the last body repeats. Counts the calls.
class FakePlanRepository extends PlanRepository {
  FakePlanRepository([List<Map<String, dynamic>>? bodies]) : bodies = bodies ?? [<String, dynamic>{}];

  final List<Map<String, dynamic>> bodies;
  int meCalls = 0;
  Object? failWith;

  void push(Map<String, dynamic> body) => bodies.add(body);

  @override
  Future<MyPlanModel> getMe({bool forceRefresh = false}) async {
    meCalls++;
    final f = failWith;
    if (f != null) throw f;
    final body = bodies.length > 1 ? bodies.removeAt(0) : bodies.first;
    return MyPlanModel.fromJson(body);
  }

  @override
  void invalidateMe() {}
}
