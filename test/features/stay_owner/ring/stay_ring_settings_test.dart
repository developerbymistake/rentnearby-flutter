import 'dart:async';

import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/stay_owner/ring/stay_ring_api.dart';
import 'package:bakhli/features/stay_owner/ring/stay_ring_ready_controller.dart';
import 'package:bakhli/features/stay_owner/ring/stay_ring_ready_screen.dart';
import 'package:bakhli/features/stay_owner/ring/stay_ring_settings_controller.dart';
import 'package:bakhli/features/stay_owner/ring/stay_ring_switch_row.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:bakhli/services/system_settings_channel.dart';
import 'package:bakhli/services/taxi_ring_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';

const _settings = {'ringOn': true, 'stayLive': true, 'hasValidToken': true, 'canRing': true, 'ringSeconds': 300};

TaxiRingDeviceState _device({bool notifications = true, bool ring = true}) =>
    TaxiRingDeviceState(notificationsOn: notifications, ringChannelOn: ring, manufacturer: 'Xiaomi', androidSdk: 34, appBuild: 69);

class _Settings extends SystemSettingsChannel {
  _Settings() : super(channel: const MethodChannel('test/none'), fallback: () async {});
  final opened = <String>[];

  @override
  Future<bool> openNotificationSettings() async {
    opened.add('notifications');
    return true;
  }

  @override
  Future<bool> openRingChannelSettings(String channelId) async {
    opened.add('ring:$channelId');
    return true;
  }

  @override
  Future<bool> openBatterySettings() async {
    opened.add('battery');
    return true;
  }
}

void main() {
  // sendAccepted reads the FCM token from StorageService, so GetStorage must be ready (as in the taxi repository test).
  setUpAll(() => initTestStorage('stay_ring_settings_test'));
  setUp(Get.reset);
  tearDown(OwnerApi.debugReset);

  group('api', () {
    test('UC15 switch reads and writes /stays/me/enquiry-ring with ringOn', () async {
      final bodies = <Map<String, dynamic>?>[];
      final t = FakeTransport((m, p, b) async {
        bodies.add(b);
        return {'data': {..._settings, if (m == 'PUT') 'ringOn': b!['ringOn']}};
      });
      OwnerApi.transport = t;
      final c = StayRingSettingsController();
      await c.load();
      expect(c.enabled.value, isTrue);
      expect(c.settings.value!.canRing, isTrue);
      expect(await c.setEnabled(false), isTrue);
      expect(c.enabled.value, isFalse);
      expect(t.calls, ['GET /stays/me/enquiry-ring', 'PUT /stays/me/enquiry-ring']);
      expect(bodies.last, {'ringOn': false});
    });

    test('UC15 the switch is on when the server has no value yet', () {
      expect(StayRingSettings.fromJson(const {}).ringOn, isTrue);
      expect(StayRingSettings.fromJson(const {'ringOn': false}).ringOn, isFalse);
    });

    test('a failed save puts the switch back', () async {
      OwnerApi.transport = FakeTransport((m, p, b) async => m == 'GET' ? {'data': _settings} : throw Exception('down'));
      final c = StayRingSettingsController();
      await c.load();
      expect(await c.setEnabled(false), isFalse);
      expect(c.enabled.value, isTrue);
      expect(c.saving.value, isFalse);
    });

    test('a failed load keeps the default and flags the error', () async {
      OwnerApi.transport = FakeTransport((m, p, b) async => throw Exception('down'));
      final c = StayRingSettingsController();
      await c.load();
      expect(c.enabled.value, isTrue);
      expect(c.loaded.value, isFalse);
      expect(c.loadFailed.value, isTrue);
    });

    test('Accept posts the Accepted answer; nothing posts Declined', () async {
      final bodies = <Map<String, dynamic>?>[];
      final t = FakeTransport((m, p, b) async {
        bodies.add(b);
        return {'data': {}};
      });
      OwnerApi.transport = t;
      StorageService.clearFcmToken();
      final r = await StayRingApi.sendAccepted('e1');
      expect(r, isA<OwnerOk<void>>());
      await StorageService.saveFcmToken('tok-1');
      await StayRingApi.sendAccepted('e1');
      StorageService.clearFcmToken();
      expect(t.calls, ['POST /stays/me/enquiry-ring/e1/answer', 'POST /stays/me/enquiry-ring/e1/answer']);
      expect(bodies, [
        {'outcome': 'Accepted'},
        {'outcome': 'Accepted', 'deviceToken': 'tok-1'},
      ]);
      expect(StayRingApi.accepted, 'Accepted');
    });

    test('test ring posts to the test endpoint', () async {
      final t = FakeTransport((m, p, b) async => {'data': {}});
      OwnerApi.transport = t;
      await StayRingApi.testRing();
      expect(t.calls, ['POST /stays/me/enquiry-ring/test']);
    });
  });

  group('ready controller', () {
    test('checks read the stay ring channel state and battery', () async {
      final c = StayRingReadyController(deviceProbe: () async => _device(ring: false), batteryProbe: () async => true);
      await c.check();
      expect(c.isDone(StayRingReadyItem.notifications), isTrue);
      expect(c.isDone(StayRingReadyItem.ringSound), isFalse);
      expect(c.isDone(StayRingReadyItem.battery), isTrue);
      expect(c.needsFix, isTrue);
    });

    test('UC17 a failing probe never throws', () async {
      final c = StayRingReadyController(deviceProbe: () async => throw StateError('no plugin'), batteryProbe: () async => false);
      await c.check();
      expect(c.checkFailed.value, isTrue);
    });

    test('UC15 test ring is done when this phone showed it', () async {
      final shown = Completer<DateTime>();
      final c = StayRingReadyController(
        deviceProbe: () async => _device(),
        batteryProbe: () async => true,
        requestTest: () async {
          shown.complete(DateTime.utc(2026));
          return const OwnerOk<void>(null);
        },
        testRingShown: () => shown.future,
      );
      await c.testRing();
      expect(c.isDone(StayRingReadyItem.testRing), isTrue);
      expect(c.testNotShown.value, isFalse);
    });

    test('test ring not seen in time is reported', () async {
      final c = StayRingReadyController(
        deviceProbe: () async => _device(),
        batteryProbe: () async => true,
        requestTest: () async => const OwnerOk<void>(null),
        testRingShown: () => Completer<DateTime>().future,
        testRingTimeout: const Duration(milliseconds: 10),
      );
      await c.testRing();
      expect(c.isDone(StayRingReadyItem.testRing), isFalse);
      expect(c.testNotShown.value, isTrue);
    });

    test('a refused test request is a failure', () async {
      final c = StayRingReadyController(
        deviceProbe: () async => _device(),
        batteryProbe: () async => true,
        requestTest: () async => const OwnerFailed<void>(message: 'down'),
        testRingShown: () => Completer<DateTime>().future,
      );
      await c.testRing();
      expect(c.testFailed.value, isTrue);
      expect(c.testing.value, isFalse);
    });
  });

  group('ready screen', () {
    Future<(StayRingReadyController, _Settings, FakeTransport)> open(WidgetTester t, {bool ring = false}) async {
      final transport = FakeTransport((m, p, b) async => {'data': {..._settings, if (m == 'PUT') 'ringOn': b!['ringOn']}});
      OwnerApi.transport = transport;
      final c = Get.put(StayRingReadyController(deviceProbe: () async => _device(ring: ring), batteryProbe: () async => false));
      final s = _Settings();
      await pumpPhone(t, StayRingReadyScreen(controller: c, settingsController: Get.put(StayRingSettingsController()), settings: s), size: const Size(392, 1200), toastHost: true);
      await settlePhone(t);
      return (c, s, transport);
    }

    testWidgets('UC15 switch on top, then the checklist rows', (t) async {
      await open(t);
      expect(find.text('Ring for enquiries'), findsOneWidget);
      expect(find.text('Ring me for new enquiries'), findsOneWidget);
      expect(find.text('Your phone rings for every new enquiry'), findsOneWidget);
      expect(find.byKey(const ValueKey('stay_ready_row_notifications')), findsOneWidget);
      expect(find.byKey(const ValueKey('stay_ready_row_ring')), findsOneWidget);
      expect(find.byKey(const ValueKey('stay_ready_row_battery')), findsOneWidget);
      expect(find.byKey(const ValueKey('stay_ready_row_test')), findsOneWidget);
      expect(find.text('Un-mute the Stay enquiries sound'), findsOneWidget);
    });

    testWidgets('Open settings on the ring row opens the stay ring channel', (t) async {
      final (_, s, _) = await open(t);
      await t.tap(find.byKey(const ValueKey('stay_ready_fix_ring')));
      await t.pump();
      expect(s.opened, ['ring:${TaxiRingNotification.stayRingChannelId}']);
    });

    testWidgets('UC15 turning the switch off saves on the server', (t) async {
      final (_, _, transport) = await open(t, ring: true);
      await t.tap(find.byKey(StayRingSwitchRow.switchKey));
      await settlePhone(t);
      expect(transport.calls, contains('PUT /stays/me/enquiry-ring'));
      expect(find.text('New enquiries only show a notification'), findsOneWidget);
    });

    testWidgets('render stay ring ready frame', (t) async {
      await open(t);
      expect((await shot(t, 'stay_ring_ready')).existsSync(), isTrue);
    });
  });
}
