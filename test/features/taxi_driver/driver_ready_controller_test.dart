import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_ready_controller.dart';
import 'package:bakhli/features/taxi/requests/data/driver_request_repository.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/services/taxi_ring_service.dart';

Map<String, dynamic> _readinessJson() =>
    jsonDecode(File('test/features/taxi_request/samples/driver_readiness.json').readAsStringSync()) as Map<String, dynamic>;

class _FakeRepo extends DriverRequestRepository {
  _FakeRepo();

  final List<DriverDeviceState> reports = [];
  int testRingCalls = 0;
  TaxiResult<void> testRingResult = const TaxiOk<void>(null);
  bool missedRings = false;

  @override
  Future<TaxiResult<DriverReadiness>> reportDevice(DriverDeviceState state) async {
    reports.add(state);
    final ok = state.notificationsOn && state.ringChannelOn;
    final clearsMissed = state.ringTested && ok;
    if (clearsMissed) missedRings = false;
    return TaxiOk(DriverReadiness.fromJson({
      ..._readinessJson(),
      'notificationsOn': state.notificationsOn,
      'ringReady': state.notificationsOn && !missedRings,
      'missedRings': missedRings,
    }));
  }

  @override
  Future<TaxiResult<void>> testRing() async {
    testRingCalls++;
    return testRingResult;
  }
}

class _Phone {
  bool notificationsOn = true;
  bool ringChannelOn = true;
  bool battery = true;

  Future<TaxiRingDeviceState> probe() async => TaxiRingDeviceState(
        notificationsOn: notificationsOn,
        ringChannelOn: ringChannelOn,
        manufacturer: 'Xiaomi',
        androidSdk: 34,
        appBuild: 69,
      );

  Future<bool> batteryProbe() async => battery;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo repo;
  late _Phone phone;
  late Completer<DateTime> ring;

  DriverReadyController make({Duration timeout = const Duration(seconds: 30)}) => DriverReadyController(
        repo: repo,
        deviceProbe: phone.probe,
        batteryProbe: phone.batteryProbe,
        testRingShown: () => ring.future,
        testRingTimeout: timeout,
      );

  setUp(() {
    repo = _FakeRepo();
    phone = _Phone();
    ring = Completer<DateTime>();
  });

  tearDown(Get.reset);

  test('device_state_is_reported_on_start_and_on_change', () async {
    final c = Get.put(make());
    await pumpEventQueue();
    expect(repo.reports, hasLength(1));
    final first = repo.reports.single;
    expect(first.notificationsOn, isTrue);
    expect(first.ringChannelOn, isTrue);
    expect(first.batteryUnrestricted, isTrue);
    expect(first.manufacturer, 'Xiaomi');
    expect(first.androidSdk, 34);
    expect(first.appBuild, 69);
    expect(c.ready, isTrue);

    phone.ringChannelOn = false;
    phone.battery = false;
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(repo.reports, hasLength(2));
    expect(repo.reports.last.ringChannelOn, isFalse);
    expect(repo.reports.last.batteryUnrestricted, isFalse);
    expect(c.isDone(DriverReadyItem.ringSound), isFalse);
    expect(c.isDone(DriverReadyItem.battery), isFalse);
    expect(c.ready, isFalse);

    await c.onOnlineSwitchedOn();
    expect(repo.reports, hasLength(3));
  });

  test('notifications_off_reports_not_ready', () async {
    phone.notificationsOn = false;
    final c = make();
    final r = await c.report();
    expect(r, isA<TaxiOk<DriverReadiness>>());
    expect(repo.reports.single.notificationsOn, isFalse);
    expect(c.isDone(DriverReadyItem.notifications), isFalse);
    expect(c.readiness.value!.ringReady, isFalse);
    expect(c.needsFix, isTrue);
    expect(c.ready, isFalse);
  });

  test('test_ring_shown_reports_ring_tested', () async {
    repo.missedRings = true;
    final c = make();
    await c.report();
    expect(c.missedRings, isTrue);
    expect(c.ready, isFalse);

    final future = c.testRing();
    await pumpEventQueue();
    expect(repo.testRingCalls, 1);
    expect(repo.reports, hasLength(1));
    ring.complete(DateTime.now());
    final r = await future;
    expect((r as TaxiOk<DriverTestRing>).value, DriverTestRing.shown);
    expect(repo.reports, hasLength(2));
    expect(repo.reports.last.ringTested, isTrue);
    expect(c.missedRings, isFalse);
    expect(c.isDone(DriverReadyItem.testRing), isTrue);
    expect(c.ready, isTrue);
  });

  test('test_ring_marker_before_the_d12_reply_still_counts', () async {
    final c = make();
    ring.complete(DateTime.now());
    final r = await c.testRing();
    expect((r as TaxiOk<DriverTestRing>).value, DriverTestRing.shown);
    expect(repo.reports.single.ringTested, isTrue);
  });

  test('test_ring_not_shown_reports_nothing', () async {
    repo.missedRings = true;
    final c = make(timeout: const Duration(milliseconds: 20));
    await c.report();
    final r = await c.testRing();
    expect((r as TaxiOk<DriverTestRing>).value, DriverTestRing.notShown);
    expect(repo.testRingCalls, 1);
    expect(repo.reports, hasLength(1));
    expect(repo.reports.any((s) => s.ringTested), isFalse);
    expect(c.isDone(DriverReadyItem.testRing), isFalse);
    expect(c.missedRings, isTrue);
  });

  test('test_ring_refused_returns_the_typed_result', () async {
    repo.testRingResult = const TaxiRefused<void>(type: 'TooManyRequests', statusCode: 429);
    final c = make();
    final r = await c.testRing();
    expect(r, isA<TaxiRefused<DriverTestRing>>());
    expect((r as TaxiRefused<DriverTestRing>).statusCode, 429);
    expect(repo.reports, isEmpty);
    expect(c.hasFailed(DriverReadyAction.testRing), isTrue);
  });

  test('start_and_resume_reports_never_claim_ring_tested', () async {
    final c = Get.put(make());
    await pumpEventQueue();
    ring.complete(DateTime.now());
    await c.testRing();
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();
    await c.onOnlineSwitchedOn();
    expect(repo.reports.map((s) => s.ringTested).toList(), [false, true, false, false]);
    final src = File('lib/features/taxi/requests/controllers/driver_ready_controller.dart').readAsStringSync();
    expect('ringTested: true'.allMatches(src), hasLength(1));
  });
}
