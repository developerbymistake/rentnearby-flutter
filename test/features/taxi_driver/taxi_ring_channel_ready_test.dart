import 'dart:convert';
import 'dart:io';

import 'package:bakhli/services/taxi_ring_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _MemoryStore implements TaxiRingDeviceStore {
  final values = <String, Object?>{};

  @override
  String? readString(String key) => values[key] as String?;

  @override
  int? readInt(String key) => values[key] as int?;

  @override
  Future<void> write(String key, Object? value) async => values[key] = value;
}

const _pluginChannel = MethodChannel('dexterous.com/flutter/local_notifications');

Map<String, Object?> _channelMap(String id, Importance importance) => {
      'id': id,
      'name': id,
      'description': null,
      'groupId': null,
      'showBadge': true,
      'importance': importance.value,
      'bypassDnd': false,
      'playSound': importance.value >= Importance.defaultImportance.value,
      'enableLights': false,
      'enableVibration': true,
      'vibrationPattern': null,
      'ledColor': 0,
      'audioAttributesUsage': AudioAttributesUsage.notification.value,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const ringId = TaxiRingNotification.ringChannelId;

  group('ringChannelReady', () {
    AndroidNotificationChannel ch(String id, Importance i) => AndroidNotificationChannel(id, id, importance: i);

    test('high_and_max_count_as_ready', () {
      expect(TaxiRingDevice.ringChannelReady([ch(ringId, Importance.max)]), isTrue);
      expect(TaxiRingDevice.ringChannelReady([ch(ringId, Importance.high)]), isTrue);
    });

    test('silent_or_lowered_channel_is_not_ready', () {
      for (final i in [Importance.none, Importance.min, Importance.low, Importance.defaultImportance]) {
        expect(TaxiRingDevice.ringChannelReady([ch(ringId, i)]), isFalse, reason: '$i');
      }
    });

    test('missing_ring_channel_is_not_ready_and_other_channels_do_not_count', () {
      expect(TaxiRingDevice.ringChannelReady(const []), isFalse);
      expect(TaxiRingDevice.ringChannelReady([ch('taxi_requests_updates', Importance.max)]), isFalse);
    });
  });

  group('read through the notification plugin', () {
    late List<Map<String, Object?>> channels;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      PackageInfo.setMockInitialValues(
        appName: 'bakhli',
        packageName: 'com.rentnearby.rentnearby',
        version: '1.0.0',
        buildNumber: '62',
        buildSignature: '',
      );
      TaxiRingDevice.store = _MemoryStore();
      TaxiRingDevice.source = () async => (manufacturer: 'Xiaomi', androidSdk: 34);
      messenger.setMockMethodCallHandler(_pluginChannel, (call) async {
        switch (call.method) {
          case 'areNotificationsEnabled':
            return true;
          case 'getNotificationChannels':
            return channels;
        }
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(_pluginChannel, null);
      debugDefaultTargetPlatformOverride = null;
      TaxiRingDevice.store = const GetStorageTaxiRingDeviceStore();
      TaxiRingDevice.source = TaxiRingDevice.channelIdentity;
    });

    Future<TaxiRingDeviceState> read() => TaxiRingDevice.read(FlutterLocalNotificationsPlugin());

    test('ring_channel_lowered_to_low_reports_ring_channel_off', () async {
      channels = [_channelMap(ringId, Importance.low)];
      final state = await read();
      expect(state.notificationsOn, isTrue);
      expect(state.ringChannelOn, isFalse);
      expect(state.appBuild, 62);
    });

    test('ring_channel_at_default_reports_ring_channel_off', () async {
      channels = [_channelMap(ringId, Importance.defaultImportance)];
      expect((await read()).ringChannelOn, isFalse);
    });

    test('ring_channel_at_max_reports_ring_channel_on', () async {
      channels = [
        _channelMap('taxi_requests_updates', Importance.defaultImportance),
        _channelMap(ringId, Importance.max),
      ];
      expect((await read()).ringChannelOn, isTrue);
    });

    test('ring_channel_at_high_reports_ring_channel_on', () async {
      channels = [_channelMap(ringId, Importance.high)];
      final state = await read();
      expect(state.ringChannelOn, isTrue);
      expect(TaxiRingService.ackBody(_push, DateTime.utc(2026, 12, 10), state, shown: true, late: false)['ringChannelOn'],
          isTrue);
    });
  });
}

final _push = TaxiRingPush.tryParse(Map<String, dynamic>.from(
    (jsonDecode(File('test/features/taxi_request/samples/push_ring.json').readAsStringSync()) as Map)['data'] as Map))!;
