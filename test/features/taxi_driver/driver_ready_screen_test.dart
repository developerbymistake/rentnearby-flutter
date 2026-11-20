import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/taxi/requests/controllers/driver_ready_controller.dart';
import 'package:bakhli/features/taxi/requests/data/driver_request_repository.dart';
import 'package:bakhli/features/taxi/requests/driver_ready_screen.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/taxi/requests/strings/driver_ready_strings.dart';
import 'package:bakhli/features/taxi/requests/widgets/driver_ready_strip.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/services/system_settings_channel.dart';
import 'package:bakhli/services/taxi_ring_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';

Map<String, dynamic> _readinessJson() =>
    jsonDecode(File('test/features/taxi_request/samples/driver_readiness.json').readAsStringSync()) as Map<String, dynamic>;

class _FakeRepo extends DriverRequestRepository {
  _FakeRepo();

  bool missedRings = false;
  bool reportFails = false;
  TaxiResult<void> testRingResult = const TaxiOk<void>(null);
  int testRingCalls = 0;

  @override
  Future<TaxiResult<DriverReadiness>> readiness() async =>
      TaxiOk(DriverReadiness.fromJson({..._readinessJson(), 'ringReady': !missedRings, 'missedRings': missedRings}));

  @override
  Future<TaxiResult<DriverReadiness>> reportDevice(DriverDeviceState state) async {
    if (reportFails) return const TaxiFailed<DriverReadiness>(message: 'down');
    final ok = state.notificationsOn && state.ringChannelOn;
    if (state.ringTested && ok) missedRings = false;
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
  String maker = 'Xiaomi';
  bool broken = false;

  Future<TaxiRingDeviceState> probe() async {
    if (broken) throw StateError('probe failed');
    return TaxiRingDeviceState(
        notificationsOn: notificationsOn,
        ringChannelOn: ringChannelOn,
        manufacturer: maker,
        androidSdk: 34,
        appBuild: 69,
      );
  }

  Future<bool> batteryProbe() async => battery;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo repo;
  late _Phone phone;
  late Completer<DateTime> ring;
  late List<MethodCall> calls;
  late int fallbacks;
  late SystemSettingsChannel settings;
  const channel = MethodChannel(SystemSettingsChannel.channelName);

  void nativeAnswers(bool opened) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'deviceInfo') return {'manufacturer': 'Samsung', 'sdk': 34};
      return opened;
    });
  }

  setUp(() {
    Get.testMode = true;
    repo = _FakeRepo();
    phone = _Phone();
    ring = Completer<DateTime>();
    calls = [];
    fallbacks = 0;
    settings = SystemSettingsChannel(channel: channel, fallback: () async => fallbacks++);
    nativeAnswers(true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    Get.reset();
  });

  DriverReadyController make() => DriverReadyController(
        repo: repo,
        deviceProbe: phone.probe,
        batteryProbe: phone.batteryProbe,
        testRingShown: () => ring.future,
        testRingTimeout: const Duration(seconds: 2),
      );

  Future<DriverReadyController> pumpScreen(WidgetTester tester, {Size size = phoneSize}) async {
    final c = Get.put(make());
    await pumpAtSize(tester, DriverReadyScreen(controller: c, settings: settings), size);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    return c;
  }

  testWidgets('row_states_from_fake_probes', (tester) async {
    phone.notificationsOn = false;
    phone.battery = false;
    await pumpScreen(tester);
    expect(find.byKey(const ValueKey('ready_fix_notifications')), findsOneWidget);
    expect(find.byKey(const ValueKey('ready_fix_battery')), findsOneWidget);
    expect(find.byKey(const ValueKey('ready_fix_ring')), findsNothing);
    expect(find.text(DriverReadyStrings.batteryByMaker['xiaomi']!), findsOneWidget);
    expect(find.byKey(const ValueKey('ready_missed_line')), findsNothing);
  });

  testWidgets('fix_buttons_call_the_channel', (tester) async {
    phone.notificationsOn = false;
    phone.ringChannelOn = false;
    phone.battery = false;
    await pumpScreen(tester);
    for (final k in ['notifications', 'ring', 'battery']) {
      await tester.ensureVisible(find.byKey(ValueKey('ready_fix_$k')));
      await tester.tap(find.byKey(ValueKey('ready_fix_$k')));
      await tester.pump();
    }
    expect(calls.map((c) => c.method), ['openNotificationSettings', 'openRingChannelSettings', 'openBatterySettings']);
    expect(calls[1].arguments, {'channelId': TaxiRingNotification.ringChannelId});
    expect(fallbacks, 0);
  });

  test('missing_native_channel_falls_back_to_app_settings', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    expect(await settings.openBatterySettings(), isFalse);
    expect(await settings.openRingChannelSettings('x'), isFalse);
    expect(fallbacks, 2);
    expect(await settings.deviceInfo(), isNull);
  });

  test('native_false_and_platform_error_fall_back', () async {
    nativeAnswers(false);
    expect(await settings.openNotificationSettings(), isFalse);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'x'));
    expect(await settings.openBatterySettings(), isFalse);
    expect(fallbacks, 2);
  });

  testWidgets('strip_shows_only_when_notifications_need_a_fix_not_for_battery', (tester) async {
    phone.battery = false;
    final c = Get.put(make());
    var opened = 0;
    await pumpAtSize(tester, Scaffold(body: DriverReadyStrip(controller: c, onOpen: () => opened++)), phoneSize);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(c.needsFix, isFalse);
    expect(find.text(DriverReadyStrings.stripTitle), findsNothing);

    phone.notificationsOn = false;
    await tester.runAsync(() => c.report());
    await tester.pump();
    expect(find.text(DriverReadyStrings.stripTitle), findsOneWidget);
    await tester.tap(find.text(DriverReadyStrings.stripAction));
    expect(opened, 1);
  });

  testWidgets('missed_rings_line_and_primary_test_ring', (tester) async {
    repo.missedRings = true;
    await pumpScreen(tester);
    expect(find.byKey(const ValueKey('ready_missed_line')), findsOneWidget);
    expect(find.text(DriverReadyStrings.missedLine), findsOneWidget);
    expect(find.byKey(const ValueKey('ready_test_ring_primary')), findsOneWidget);
  });

  testWidgets('shown_test_ring_clears_the_missed_state', (tester) async {
    repo.missedRings = true;
    final c = await pumpScreen(tester);
    await tester.tap(find.byKey(const ValueKey('ready_test_ring_primary')));
    await tester.pump();
    await tester.runAsync(() async {
      ring.complete(DateTime.now());
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump();
    expect(repo.testRingCalls, 1);
    expect(c.missedRings, isFalse);
    expect(find.byKey(const ValueKey('ready_missed_line')), findsNothing);
    expect(find.text(DriverReadyStrings.testShown), findsOneWidget);
    expect(find.byKey(const ValueKey('ready_test_ring')), findsOneWidget);
  });

  test('battery_exemption_permission_is_never_requested', () {
    final bad = RegExp(r'REQUEST_IGNORE_BATTERY_OPTIMIZATIONS|requestIgnoreBatteryOptimizations|ignoreBatteryOptimizations\s*\.\s*(request|onGrantedCallback)');
    final files = <File>[
      ...Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
      ...Directory('android/app/src/main').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.kt') || f.path.endsWith('.xml')),
    ];
    final hits = [for (final f in files) if (bad.hasMatch(f.readAsStringSync())) f.path];
    expect(hits, isEmpty);
  });

  for (final missed in [false, true]) {
    for (final size in fiveSizes) {
      testWidgets('driver_ready_five_sizes ${missed ? 'missed' : 'fix'} at ${sizeLabel(size)}', (tester) async {
        phone
          ..notificationsOn = false
          ..ringChannelOn = false
          ..battery = false;
        repo.missedRings = missed;
        await pumpScreen(tester, size: size);
        expect(tester.takeException(), isNull);
        final primary = find.byKey(const ValueKey('ready_test_ring_primary'));
        await tester.scrollUntilVisible(primary, 200, scrollable: find.byType(Scrollable).last);
        await tester.pump();
        expect(primary.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in fiveSizes) {
    testWidgets('driver_ready_five_sizes probe failed at ${sizeLabel(size)}', (tester) async {
      phone.broken = true;
      repo.missedRings = true;
      final c = await pumpScreen(tester, size: size);
      await tester.runAsync(() => c.loadReadiness());
      await tester.pump();
      final retry = find.byKey(const ValueKey('ready_probe_retry'));
      await tester.scrollUntilVisible(retry, 200, scrollable: find.byType(Scrollable).last);
      await tester.pump();
      expect(retry.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('probe_failure_shows_error_and_retry_recovers', (tester) async {
    phone.broken = true;
    final c = await pumpScreen(tester);
    expect(c.hasFailed(DriverReadyAction.report), isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('ready_probe_failed')), findsOneWidget);
    expect(find.text(DriverReadyStrings.probeFailedTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('ready_row_notifications')), findsNothing);

    phone.broken = false;
    await tester.tap(find.byKey(const ValueKey('ready_probe_retry')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.byKey(const ValueKey('ready_probe_failed')), findsNothing);
    expect(find.byKey(const ValueKey('ready_row_notifications')), findsOneWidget);
  });

  testWidgets('strip_shows_on_missed_rings_or_failed_probe_without_a_device', (tester) async {
    phone.broken = true;
    final c = Get.put(make());
    await pumpAtSize(tester, Scaffold(body: DriverReadyStrip(controller: c, onOpen: () {})), phoneSize);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(c.device.value, isNull);
    expect(find.text(DriverReadyStrings.stripTitle), findsOneWidget);
    expect(find.text(DriverReadyStrings.stripBody), findsOneWidget);

    repo.missedRings = true;
    await tester.runAsync(() => c.loadReadiness());
    await tester.pump();
    expect(find.text(DriverReadyStrings.stripMissedBody), findsOneWidget);
  });

  testWidgets('test_ring_not_seen_shows_not_shown_note', (tester) async {
    repo.missedRings = true;
    await pumpScreen(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('ready_test_ring_primary')));
    await tester.tap(find.byKey(const ValueKey('ready_test_ring_primary')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(repo.testRingCalls, 1);
    expect(find.text(DriverReadyStrings.testNotShown), findsOneWidget);
    expect(find.byKey(const ValueKey('ready_test_ring_primary')), findsOneWidget);
  });

  testWidgets('test_ring_call_failure_shows_failed_note', (tester) async {
    repo.testRingResult = const TaxiFailed<void>(message: 'down');
    repo.missedRings = true;
    await pumpScreen(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('ready_test_ring_primary')));
    await tester.tap(find.byKey(const ValueKey('ready_test_ring_primary')));
    await tester.pump();
    await tester.pump();
    expect(find.text(DriverReadyStrings.testFailed), findsOneWidget);
    expect(find.text(DriverReadyStrings.testNotSaved), findsNothing);
  });

  testWidgets('ring_shown_but_report_failed_says_not_saved', (tester) async {
    repo.missedRings = true;
    await pumpScreen(tester);
    repo.reportFails = true;
    await tester.tap(find.byKey(const ValueKey('ready_test_ring_primary')));
    await tester.pump();
    await tester.runAsync(() async {
      ring.complete(DateTime.now());
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump();
    expect(find.text(DriverReadyStrings.testNotSaved), findsOneWidget);
    expect(find.text(DriverReadyStrings.testFailed), findsNothing);
    expect(find.byKey(const ValueKey('ready_missed_line')), findsOneWidget);
    expect(find.byKey(const ValueKey('ready_test_ring_primary')), findsOneWidget);
  });

  testWidgets('empty_maker_falls_back_to_native_device_info', (tester) async {
    phone
      ..maker = ''
      ..battery = false;
    await pumpScreen(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(calls.where((c) => c.method == 'deviceInfo'), hasLength(1));
    expect(find.text(DriverReadyStrings.batteryByMaker['samsung']!), findsOneWidget);
  });

  test('battery_maker_line_for_every_maker', () {
    const table = {
      'Xiaomi': 'xiaomi',
      'OnePlus': 'oneplus',
      'samsung': 'samsung',
      'OPPO': 'oppo',
      'vivo': 'vivo',
      ' realme ': 'realme',
    };
    for (final e in table.entries) {
      expect(DriverReadyStrings.batteryMakerLine(e.key), DriverReadyStrings.batteryByMaker[e.value], reason: e.key);
      expect(DriverReadyStrings.batteryMakerLine(e.key), isNotNull);
    }
    expect(DriverReadyStrings.batteryMakerLine('Google'), isNull);
    expect(DriverReadyStrings.batteryMakerLine(''), isNull);
  });
}
