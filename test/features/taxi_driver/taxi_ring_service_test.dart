import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bakhli/services/taxi_ring_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

const _samples = 'test/features/taxi_request/samples';

Map<String, dynamic> _sample(String name) =>
    jsonDecode(File('$_samples/$name').readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> _ringData() => Map<String, dynamic>.from(_sample('push_ring.json')['data'] as Map);

final _receivedAt = DateTime.utc(2026, 12, 10, 9, 41, 9);

const _sampleDevice = TaxiRingDeviceState(
  notificationsOn: true,
  ringChannelOn: true,
  manufacturer: 'Xiaomi',
  androidSdk: 34,
  appBuild: 69,
);

class _Shown {
  _Shown(this.id, this.title, this.body, this.details, this.payload);
  final int id;
  final String title;
  final String body;
  final NotificationDetails details;
  final String? payload;
}

class _Notifier implements TaxiRingNotifier {
  _Notifier(this.events);
  final List<String> events;
  final shown = <_Shown>[];
  final cancelled = <(int, String)>[];

  @override
  Future<void> show(int id, String title, String body, NotificationDetails details, String? payload) async {
    events.add('show');
    shown.add(_Shown(id, title, body, details, payload));
  }

  @override
  Future<void> cancel(int id, String tag) async {
    events.add('cancel');
    cancelled.add((id, tag));
  }
}

class _Harness {
  _Harness({DateTime? now, TaxiAckSender? sendAck}) {
    notifier = _Notifier(events);
    service = TaxiRingService(
      notifier: notifier,
      sendAck: sendAck ??
          (offerId, body) async {
            events.add('ack');
            acks.add((offerId, body));
          },
      probe: () async => _sampleDevice,
      clock: () => now ?? _receivedAt,
    );
  }

  final events = <String>[];
  final acks = <(String, Map<String, dynamic>)>[];
  late final _Notifier notifier;
  late final TaxiRingService service;
}

class _MemoryStore implements TaxiRingDeviceStore {
  final values = <String, Object?>{};
  @override
  String? readString(String key) => values[key] as String?;
  @override
  int? readInt(String key) => values[key] as int?;
  @override
  Future<void> write(String key, Object? value) async => values[key] = value;
}

class _FailingAdapter implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    calls++;
    throw DioException.connectionTimeout(timeout: TaxiRingAckClient.timeout, requestOptions: options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(TaxiRingService.resetTestRingMarker);

  test('ring_sample_parses', () {
    final push = TaxiRingPush.tryParse(_ringData())!;
    expect(push.kind, TaxiRingKind.ring);
    expect(push.offerId, 'a1b2c3d4-0001-4a00-8000-000000000001');
    expect(push.requestId, '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a6101');
    expect(push.expiresAt, DateTime.utc(2026, 12, 10, 9, 46, 7));
    expect(push.ackToken, 'Qk9fY2xhdWRlX3NhbXBsZQ');
    expect(push.title, 'New taxi request');
    expect(push.lines, [
      '4 days · 3 nights · 18 to 21 Dec',
      'Kathgodam to Nainital, Ranikhet',
      '4 seater · 2 travellers',
    ]);
    expect(push.tag, 'taxi_ring_a1b2c3d4-0001-4a00-8000-000000000001');
  });

  test('details_are_max_importance_insistent_and_not_full_screen', () {
    final push = TaxiRingPush.tryParse(_ringData())!;
    final a = TaxiRingNotification.android(push, _receivedAt);
    expect(TaxiRingNotification.id, 0);
    expect(a.channelId, 'taxi_requests_ring_v1');
    expect(a.importance, Importance.max);
    expect(a.priority, Priority.max);
    expect(a.category, AndroidNotificationCategory.call);
    expect(a.ongoing, isTrue);
    expect(a.autoCancel, isFalse);
    expect(a.fullScreenIntent, isFalse);
    expect(a.additionalFlags, contains(TaxiRingNotification.flagInsistent));
    expect(TaxiRingNotification.flagInsistent, 4);
    expect(a.visibility, NotificationVisibility.public);
    expect(a.audioAttributesUsage, AudioAttributesUsage.notificationRingtone);
    expect((a.sound as UriAndroidNotificationSound).sound, TaxiRingNotification.ringtoneUri);
    expect(a.tag, push.tag);
    expect(a.actions!.map((x) => x.title), ['Decline', 'Accept']);
    expect(a.actions!.every((x) => x.showsUserInterface), isTrue);

    final channel = TaxiRingNotification.ringChannel;
    expect(channel.id, 'taxi_requests_ring_v1');
    expect(channel.importance, Importance.max);
    expect(channel.audioAttributesUsage, AudioAttributesUsage.notificationRingtone);
    expect(TaxiRingNotification.updatesChannel.id, 'taxi_request_updates_v1');
    expect(TaxiRingNotification.updatesChannel.importance, Importance.defaultImportance);

    final payload = jsonDecode(TaxiRingNotification.payload(push)!) as Map<String, dynamic>;
    expect(payload['action_route'], '/taxi-request-ring');
    expect(jsonDecode(payload['action_args_json'] as String), {'offerId': push.offerId});
    final accepted = TaxiRingNotification.withAction(payload, TaxiRingNotification.acceptAction);
    expect(jsonDecode(accepted['action_args_json'] as String), {'offerId': push.offerId, 'action': 'accept'});
    expect(TaxiRingNotification.withAction(payload, null), payload);

    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest.contains('USE_FULL_SCREEN_INTENT'), isFalse);
    expect(manifest, contains('android.permission.VIBRATE'));
    expect(manifest, contains('android.permission.WAKE_LOCK'));
  });

  test('timeout_equals_time_left', () {
    final push = TaxiRingPush.tryParse(_ringData())!;
    expect(TaxiRingNotification.android(push, _receivedAt).timeoutAfter, 298000);
    final later = DateTime.utc(2026, 12, 10, 9, 46, 6);
    expect(TaxiRingNotification.android(push, later).timeoutAfter, 1000);
  });

  test('expired_ring_shows_nothing_and_acks_late', () async {
    final h = _Harness(now: DateTime.utc(2026, 12, 10, 9, 46, 8));
    final result = await h.service.handle(_ringData());
    await result.ack;
    expect(result.outcome, TaxiRingOutcome.expired);
    expect(h.notifier.shown, isEmpty);
    expect(h.acks, hasLength(1));
    expect(h.acks.single.$1, 'a1b2c3d4-0001-4a00-8000-000000000001');
    expect(h.acks.single.$2['late'], isTrue);
    expect(h.acks.single.$2['shown'], isFalse);
  });

  test('ack_does_not_block_the_notification', () async {
    final never = Completer<void>();
    final h = _Harness(sendAck: (_, _) => never.future);
    final result = await h.service.handle(_ringData());
    expect(result.outcome, TaxiRingOutcome.shown);
    expect(h.notifier.shown, hasLength(1));
    expect(h.events.first, 'show');
    var ackDone = false;
    unawaited(result.ack.then((_) => ackDone = true));
    await Future<void>.delayed(Duration.zero);
    expect(ackDone, isFalse);
    never.complete();
    await result.ack;
    expect(ackDone, isTrue);
  });

  test('ack_failure_is_swallowed', () async {
    final h = _Harness(sendAck: (_, _) async => throw StateError('offline'));
    final result = await h.service.handle(_ringData());
    await expectLater(result.ack, completes);
    expect(h.notifier.shown, hasLength(1));

    final adapter = _FailingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    await expectLater(TaxiRingAckClient.send('a1', const {}, dio: dio), completes);
    expect(adapter.calls, 2);
  });

  test('ack_body_equals_the_contract_sample', () async {
    final h = _Harness();
    final result = await h.service.handle(_ringData());
    await result.ack;
    expect(h.acks.single.$2, _sample('ack_request.json'));
    expect(TaxiRingAckClient.path('a1b2c3d4-0001-4a00-8000-000000000001'),
        '/taxi-requests/offers/a1b2c3d4-0001-4a00-8000-000000000001/ack');
  });

  test('second_ring_for_the_same_offer_replaces', () async {
    final h = _Harness();
    await h.service.handle(_ringData());
    await h.service.handle({..._ringData(), 'attempt': '1'});
    expect(h.notifier.shown, hasLength(2));
    final tags = h.notifier.shown.map((s) => (s.details.android!.tag, s.id)).toSet();
    expect(tags, {('taxi_ring_a1b2c3d4-0001-4a00-8000-000000000001', 0)});
  });

  test('ring_end_cancels_by_tag', () async {
    final sample = _sample('push_ring_end.json');
    final h = _Harness();
    final result = await h.service.handle(Map<String, dynamic>.from(sample['data'] as Map));
    expect(result.outcome, TaxiRingOutcome.ended);
    expect(h.notifier.cancelled, [(0, (sample['android'] as Map)['tag'])]);
    expect(h.notifier.shown, isEmpty);
    expect(h.acks, isEmpty);
  });

  test('test_ring_shown_sets_the_marker', () async {
    final h = _Harness();
    final waiter = TaxiRingService.testRingShown;
    final result = await h.service.handle({
      ..._ringData(),
      'kind': 'taxi_ring_test',
      'offerId': '',
      'ackToken': '',
      'expiresAt': '2026-12-10T09:41:39Z',
    });
    await result.ack;
    expect(result.outcome, TaxiRingOutcome.testShown);
    expect(h.notifier.shown.single.details.android!.channelId, 'taxi_requests_ring_v1');
    expect(TaxiRingService.lastTestRingShownAt, _receivedAt);
    expect(await waiter.timeout(const Duration(seconds: 1)), _receivedAt);
    expect(h.acks, isEmpty);
    expect(h.notifier.shown.single.payload, isNull);
  });

  group('device identity', () {
    late _MemoryStore store;
    setUp(() {
      store = _MemoryStore();
      TaxiRingDevice.store = store;
    });
    tearDown(() {
      TaxiRingDevice.store = const GetStorageTaxiRingDeviceStore();
      TaxiRingDevice.source = TaxiRingDevice.channelIdentity;
    });

    test('read_returns_what_remember_stored', () async {
      TaxiRingDevice.source = () async => throw StateError('no channel in background');
      await TaxiRingDevice.remember(manufacturer: 'Xiaomi', androidSdk: 34);
      final id = await TaxiRingDevice.identity();
      expect(id.manufacturer, 'Xiaomi');
      expect(id.androidSdk, 34);
    });

    test('refresh_reads_the_system_settings_channel_and_caches_it', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(TaxiRingDevice.channel, (call) async {
        calls.add(call.method);
        return {'manufacturer': 'Xiaomi', 'androidSdk': 34};
      });
      addTearDown(() => messenger.setMockMethodCallHandler(TaxiRingDevice.channel, null));
      expect(TaxiRingDevice.channel.name, 'bakhli/system_settings');
      expect(await TaxiRingDevice.refresh(), isTrue);
      expect(calls, ['deviceInfo']);
      expect(TaxiRingDevice.stored(), (manufacturer: 'Xiaomi', androidSdk: 34));
    });

    test('empty_cache_falls_back_to_the_live_source', () async {
      TaxiRingDevice.source = () async => (manufacturer: 'Samsung', androidSdk: 33);
      expect(await TaxiRingDevice.identity(), (manufacturer: 'Samsung', androidSdk: 33));
      expect(TaxiRingDevice.stored(), (manufacturer: 'Samsung', androidSdk: 33));
    });

    test('no_source_and_no_cache_reports_unknown', () async {
      TaxiRingDevice.source = () async => throw MissingPluginException();
      expect(await TaxiRingDevice.refresh(), isFalse);
      expect(await TaxiRingDevice.identity(), (manufacturer: null, androidSdk: 0));
    });
  });

  test('ring_end_in_foreground_uses_the_updates_channel_with_the_ring_tag', () {
    final sample = _sample('push_ring_end.json');
    final push = TaxiRingPush.tryParse(Map<String, dynamic>.from(sample['data'] as Map))!;
    final a = TaxiRingNotification.endDetails(push).android!;
    expect(a.channelId, 'taxi_request_updates_v1');
    expect(a.tag, (sample['android'] as Map)['tag']);
    final source = File('lib/services/notification_service.dart').readAsStringSync();
    expect(source, contains('notificationDetails: TaxiRingNotification.endDetails(ring)'));
  });

  test('background_ack_is_capped', () async {
    final never = Completer<void>();
    final sw = Stopwatch()..start();
    await TaxiRingAckClient.within(never.future, limit: const Duration(milliseconds: 50));
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    expect(TaxiRingAckClient.overallTimeout, const Duration(seconds: 9));
    final source = File('lib/services/notification_service.dart').readAsStringSync();
    expect(source, contains('await TaxiRingAckClient.within(result.ack);'));
  });

  test('chat_pushes_are_untouched', () async {
    final chat = <String, dynamic>{'conversation_id': 'c1', 'title': 'Asha', 'body': 'Hi'};
    expect(TaxiRingPush.tryParse(chat), isNull);
    expect(TaxiRingPush.isUnreadableRing(chat), isFalse);
    final h = _Harness();
    final result = await h.service.handle(chat);
    expect(result.outcome, TaxiRingOutcome.ignored);
    expect(h.events, isEmpty);

    final source = File('lib/services/notification_service.dart').readAsStringSync();
    expect(source, contains("final conversationId = message.data['conversation_id'] as String?;"));
    expect(source, contains('if (conversationId == null) return; // not a chat push'));
    expect(source.indexOf('TaxiRingPush.tryParse(message.data)'),
        lessThan(source.indexOf("final conversationId = message.data['conversation_id']")));
  });

  test('unknown_kind_is_ignored', () async {
    final h = _Harness();
    for (final data in [
      {..._ringData(), 'kind': 'taxi_ring_video'},
      {..._ringData(), 'v': '2'},
      {..._ringData(), 'expiresAt': 'soon'},
    ]) {
      final result = await h.service.handle(data);
      await result.ack;
      expect(result.outcome, TaxiRingOutcome.ignored);
    }
    expect(TaxiRingPush.isUnreadableRing({..._ringData(), 'v': '2'}), isTrue);
    expect(h.events, isEmpty);
  });
}
