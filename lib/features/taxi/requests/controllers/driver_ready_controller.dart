import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../services/taxi_ring_service.dart';
import '../../../trip/utils/taxi_result.dart';
import '../data/driver_request_repository.dart';
import '../models/driver_request_models.dart';

enum DriverReadyItem { notifications, ringSound, battery, testRing }

enum DriverReadyAction { report, readiness, testRing }

enum DriverTestRing { shown, notShown }

typedef DriverBatteryProbe = Future<bool> Function();
typedef DriverTestRingWaiter = Future<DateTime> Function();

class DriverReadyController extends GetxController with WidgetsBindingObserver {
  DriverReadyController({
    this._repo = const DriverRequestRepository(),
    TaxiRingDeviceProbe? deviceProbe,
    DriverBatteryProbe? batteryProbe,
    DriverTestRingWaiter? testRingShown,
    this.testRingTimeout = const Duration(seconds: 30),
  })  : _deviceProbe = deviceProbe ?? _pluginProbe,
        _batteryProbe = batteryProbe ?? _batteryUnrestricted,
        _testRingShown = testRingShown ?? (() => TaxiRingService.testRingShown);

  static DriverReadyController get to =>
      Get.isRegistered<DriverReadyController>() ? Get.find<DriverReadyController>() : Get.put(DriverReadyController());

  static Future<TaxiRingDeviceState> _pluginProbe() => TaxiRingDevice.read(FlutterLocalNotificationsPlugin());

  static Future<bool> _batteryUnrestricted() => Permission.ignoreBatteryOptimizations.isGranted;

  final DriverRequestRepository _repo;
  final TaxiRingDeviceProbe _deviceProbe;
  final DriverBatteryProbe _batteryProbe;
  final DriverTestRingWaiter _testRingShown;
  final Duration testRingTimeout;

  final device = Rxn<DriverDeviceState>();
  final readiness = Rxn<DriverReadiness>();
  final ringShownHere = false.obs;
  final busy = <DriverReadyAction>{}.obs;
  final failed = <DriverReadyAction>{}.obs;

  final Map<DriverReadyAction, Future<Object>> _inFlight = {};
  bool _observing = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
    unawaited(report());
  }

  bool isBusy(DriverReadyAction a) => busy.contains(a);

  bool hasFailed(DriverReadyAction a) => failed.contains(a);

  bool get missedRings => readiness.value?.missedRings ?? false;

  bool isDone(DriverReadyItem item) {
    final d = device.value;
    final r = readiness.value;
    return switch (item) {
      DriverReadyItem.notifications => d?.notificationsOn ?? false,
      DriverReadyItem.ringSound => d?.ringChannelOn ?? false,
      DriverReadyItem.battery => d?.batteryUnrestricted ?? false,
      DriverReadyItem.testRing => ringShownHere.value || (r != null && r.ringReady && !r.missedRings),
    };
  }

  Map<DriverReadyItem, bool> get items => {for (final i in DriverReadyItem.values) i: isDone(i)};

  bool get needsFix => missedRings || !isDone(DriverReadyItem.notifications) || !isDone(DriverReadyItem.ringSound);

  bool get ready => !needsFix && (readiness.value?.ringReady ?? false);

  Future<TaxiResult<T>> _run<T>(DriverReadyAction a, Future<TaxiResult<T>> Function() body) {
    final running = _inFlight[a];
    if (running != null) return running as Future<TaxiResult<T>>;
    final future = _guarded(a, body);
    _inFlight[a] = future;
    return future.whenComplete(() => _inFlight.remove(a));
  }

  Future<TaxiResult<T>> _guarded<T>(DriverReadyAction a, Future<TaxiResult<T>> Function() body) async {
    busy.add(a);
    failed.remove(a);
    try {
      final r = await body();
      if (r is! TaxiOk<T>) failed.add(a);
      return r;
    } finally {
      busy.remove(a);
    }
  }

  Future<DriverDeviceState> _probe() async {
    final d = await _deviceProbe();
    final battery = await _batteryProbe();
    return DriverDeviceState(
      appBuild: d.appBuild,
      notificationsOn: d.notificationsOn,
      ringChannelOn: d.ringChannelOn,
      batteryUnrestricted: battery,
      manufacturer: d.manufacturer ?? '',
      androidSdk: d.androidSdk,
    );
  }

  Future<TaxiResult<DriverReadiness>> _send(DriverDeviceState state) async {
    final r = await _repo.reportDevice(state);
    if (r case TaxiOk<DriverReadiness>(:final value)) readiness.value = value;
    return r;
  }

  Future<TaxiResult<DriverReadiness>> report() => _run(DriverReadyAction.report, () async {
        final DriverDeviceState state;
        try {
          state = await _probe();
        } catch (e) {
          return TaxiFailed<DriverReadiness>(message: e.toString());
        }
        device.value = state;
        return _send(state);
      });

  Future<TaxiResult<DriverReadiness>> onOnlineSwitchedOn() => report();

  Future<TaxiResult<DriverReadiness>> loadReadiness() => _run(DriverReadyAction.readiness, () async {
        final r = await _repo.readiness();
        if (r case TaxiOk<DriverReadiness>(:final value)) readiness.value = value;
        return r;
      });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(report());
  }

  Future<TaxiResult<DriverTestRing>> testRing() => _run(DriverReadyAction.testRing, () async {
        final shownSignal = _testRingShown().then((_) => true);
        final asked = await _repo.testRing();
        if (asked is! TaxiOk<void>) return _retype<DriverTestRing>(asked);
        final shown = await shownSignal.timeout(testRingTimeout, onTimeout: () => false);
        if (!shown) return const TaxiOk(DriverTestRing.notShown);
        ringShownHere.value = true;
        final DriverDeviceState state;
        try {
          state = await _probe();
        } catch (e) {
          return TaxiFailed<DriverTestRing>(message: e.toString());
        }
        final tested = state.copyWith(ringTested: true);
        device.value = tested;
        final sent = await _send(tested);
        if (sent is! TaxiOk<DriverReadiness>) return _retype<DriverTestRing>(sent);
        return const TaxiOk(DriverTestRing.shown);
      });

  static TaxiResult<T> _retype<T>(TaxiResult<Object?> r) => switch (r) {
        TaxiOk() => TaxiFailed<T>(message: 'unexpected ok'),
        TaxiPaused(:final message) => TaxiPaused<T>(message: message),
        TaxiNotFound(:final message) => TaxiNotFound<T>(message: message),
        TaxiStateInvalid(:final state, :final version, :final message) =>
          TaxiStateInvalid<T>(state: state, version: version, message: message),
        TaxiRefused(:final type, :final statusCode, :final message) =>
          TaxiRefused<T>(type: type, statusCode: statusCode, message: message),
        TaxiOffline() => TaxiOffline<T>(),
        TaxiFailed(:final message) => TaxiFailed<T>(message: message),
        TaxiPlanLocked(:final reason, :final requestId, :final message) =>
          TaxiPlanLocked<T>(reason: reason, requestId: requestId, message: message),
        TaxiAlreadyActive(:final requestId, :final message) => TaxiAlreadyActive<T>(requestId: requestId, message: message),
        TaxiLegacyActive(:final rows, :final message) => TaxiLegacyActive<T>(rows: rows, message: message),
        TaxiAllDriversBusy(:final message) => TaxiAllDriversBusy<T>(message: message),
        TaxiOverlap(:final tripId, :final tripName, :final message) => TaxiOverlap<T>(tripId: tripId, tripName: tripName, message: message),
      };

  @override
  void onClose() {
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    super.onClose();
  }
}
