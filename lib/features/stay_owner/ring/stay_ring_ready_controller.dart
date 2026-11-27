import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../services/taxi_ring_service.dart';
import '../../owner_core/data/owner_result.dart';
import 'stay_ring_api.dart';

enum StayRingReadyItem { notifications, ringSound, battery, testRing }

typedef StayRingBatteryProbe = Future<bool> Function();
typedef StayRingTestRequest = Future<OwnerResult<void>> Function();
typedef StayRingTestWaiter = Future<DateTime> Function();

/// The phone checks for the stay enquiry ring and the test ring (the server sends it, this phone shows it).
class StayRingReadyController extends GetxController with WidgetsBindingObserver {
  StayRingReadyController({
    TaxiRingDeviceProbe? deviceProbe,
    StayRingBatteryProbe? batteryProbe,
    StayRingTestRequest? requestTest,
    StayRingTestWaiter? testRingShown,
    this.testRingTimeout = const Duration(seconds: 30),
  })  : _deviceProbe = deviceProbe ?? _pluginProbe,
        _batteryProbe = batteryProbe ?? _batteryUnrestricted,
        _requestTest = requestTest ?? StayRingApi.testRing,
        _testRingShown = testRingShown ?? (() => TaxiRingService.testRingShown);

  static StayRingReadyController get to =>
      Get.isRegistered<StayRingReadyController>() ? Get.find<StayRingReadyController>() : Get.put(StayRingReadyController());

  static Future<TaxiRingDeviceState> _pluginProbe() => TaxiRingDevice.read(FlutterLocalNotificationsPlugin(), role: RingRole.stay);

  static Future<bool> _batteryUnrestricted() => Permission.ignoreBatteryOptimizations.isGranted;

  final TaxiRingDeviceProbe _deviceProbe;
  final StayRingBatteryProbe _batteryProbe;
  final StayRingTestRequest _requestTest;
  final StayRingTestWaiter _testRingShown;
  final Duration testRingTimeout;

  final notificationsOn = false.obs;
  final ringChannelOn = false.obs;
  final batteryOk = false.obs;
  final checked = false.obs;
  final checkFailed = false.obs;
  final testing = false.obs;
  final rangHere = false.obs;
  final testNotShown = false.obs;
  final testFailed = false.obs;

  bool _observing = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
    unawaited(check());
  }

  bool isDone(StayRingReadyItem item) => switch (item) {
        StayRingReadyItem.notifications => notificationsOn.value,
        StayRingReadyItem.ringSound => ringChannelOn.value,
        StayRingReadyItem.battery => batteryOk.value,
        StayRingReadyItem.testRing => rangHere.value,
      };

  bool get needsFix => !notificationsOn.value || !ringChannelOn.value;

  Future<void> check() async {
    try {
      final d = await _deviceProbe();
      final battery = await _batteryProbe();
      if (isClosed) return;
      notificationsOn.value = d.notificationsOn;
      ringChannelOn.value = d.ringChannelOn;
      batteryOk.value = battery;
      checked.value = true;
      checkFailed.value = false;
    } catch (_) {
      if (!isClosed) checkFailed.value = !checked.value;
    }
  }

  Future<void> testRing() async {
    if (testing.value) return;
    testing.value = true;
    testNotShown.value = false;
    testFailed.value = false;
    try {
      final shownSignal = _testRingShown().then((_) => true);
      final asked = await _requestTest();
      if (isClosed) return;
      if (asked is! OwnerOk<void>) {
        testFailed.value = true;
        return;
      }
      final shown = await shownSignal.timeout(testRingTimeout, onTimeout: () => false);
      if (isClosed) return;
      rangHere.value = rangHere.value || shown;
      testNotShown.value = !shown;
      if (shown) unawaited(check());
    } catch (_) {
      if (!isClosed) testFailed.value = true;
    } finally {
      if (!isClosed) testing.value = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(check());
  }

  @override
  void onClose() {
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    super.onClose();
  }
}
