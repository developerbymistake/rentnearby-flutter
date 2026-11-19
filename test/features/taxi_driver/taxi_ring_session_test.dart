import 'dart:convert';
import 'dart:io';

import 'package:bakhli/config/app_constants.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:bakhli/services/taxi_ring_service.dart';
import 'package:bakhli/services/taxi_ring_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _samples = 'test/features/taxi_request/samples';

Map<String, dynamic> _sample(String name) =>
    jsonDecode(File('$_samples/$name').readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> _data(String name) => Map<String, dynamic>.from(_sample(name)['data'] as Map);

final _receivedAt = DateTime.utc(2026, 12, 10, 9, 41, 9);

String _jwt(Map<String, dynamic> claims) {
  String part(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(claims)}.c2ln';
}

final _driverToken = _jwt({'sub': 'u1', 'role': 'TAXI_DRIVER'});
final _seekerToken = _jwt({'sub': 'u1', 'role': 'SEEKER'});
const _me = '9b2f7c1e-0000-4000-8000-0000000000aa';
final _driverIdToken = _jwt({'nameid': _me, 'role': 'TAXI_DRIVER'});

class _Notifier implements TaxiRingNotifier {
  final shown = <String>[];
  final cancelled = <String>[];

  @override
  Future<void> show(int id, String title, String body, NotificationDetails details, String? payload) async =>
      shown.add(title);

  @override
  Future<void> cancel(int id, String tag) async => cancelled.add(tag);
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

class _Harness {
  _Harness(Future<bool> Function(String? driverUserId) session) {
    service = TaxiRingService(
      notifier: notifier,
      sendAck: (offerId, body) async => acks.add(offerId),
      probe: () async => const TaxiRingDeviceState(
        notificationsOn: true,
        ringChannelOn: true,
        manufacturer: 'Xiaomi',
        androidSdk: 34,
        appBuild: 69,
      ),
      clock: () => _receivedAt,
      driverSession: session,
    );
  }

  final notifier = _Notifier();
  final acks = <String>[];
  late final TaxiRingService service;
}

Map<String, dynamic> _testRing() => {
      ..._data('push_ring.json'),
      'kind': 'taxi_ring_test',
      'offerId': '',
      'ackToken': '',
      'expiresAt': '2026-12-10T09:41:39Z',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TaxiRingService.resetTestRingMarker();
    TaxiRingEndedLog.store = _MemoryStore();
  });
  tearDown(() => TaxiRingEndedLog.store = const GetStorageTaxiRingDeviceStore());

  group('ring needs a logged in driver session', () {
    test('logged_out_ring_is_not_shown_and_not_acked', () async {
      final h = _Harness((_) async => false);
      final result = await h.service.handle(_data('push_ring.json'));
      await result.ack;
      expect(result.outcome, TaxiRingOutcome.ignored);
      expect(h.notifier.shown, isEmpty);
      expect(h.acks, isEmpty);
    });

    test('logged_out_test_ring_is_not_shown', () async {
      final h = _Harness((_) async => false);
      final result = await h.service.handle(_testRing());
      expect(result.outcome, TaxiRingOutcome.ignored);
      expect(h.notifier.shown, isEmpty);
      expect(TaxiRingService.lastTestRingShownAt, isNull);
    });

    test('failing_session_check_shows_nothing', () async {
      final h = _Harness((_) async => throw StateError('no storage'));
      final result = await h.service.handle(_data('push_ring.json'));
      expect(result.outcome, TaxiRingOutcome.ignored);
      expect(h.notifier.shown, isEmpty);
    });

    test('ring_end_still_cancels_when_logged_out', () async {
      final h = _Harness((_) async => false);
      final result = await h.service.handle(_data('push_ring_end.json'));
      expect(result.outcome, TaxiRingOutcome.ended);
      expect(h.notifier.cancelled, hasLength(1));
    });

    test('driver_session_ring_is_shown_and_acked', () async {
      final h = _Harness((_) async => true);
      final result = await h.service.handle(_data('push_ring.json'));
      await result.ack;
      expect(result.outcome, TaxiRingOutcome.shown);
      expect(h.notifier.shown, hasLength(1));
      expect(h.acks, hasLength(1));
    });
  });

  group('session from the stored token', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));
    tearDown(() async => StorageService.clearToken());

    test('only_a_taxi_driver_token_counts', () {
      expect(TaxiRingSession.isDriverToken(_driverToken), isTrue);
      expect(TaxiRingSession.isDriverToken(_seekerToken), isFalse);
      expect(TaxiRingSession.isDriverToken(null), isFalse);
      expect(TaxiRingSession.isDriverToken('not.a.jwt'), isFalse);
    });

    test('logout_ends_the_driver_session', () async {
      await StorageService.saveToken(_driverToken);
      expect(await TaxiRingSession.isDriver(), isTrue);
      await StorageService.clearToken();
      expect(await TaxiRingSession.isDriver(), isFalse);
    });

    test('role_change_to_seeker_ends_the_driver_session', () async {
      await StorageService.saveToken(_seekerToken);
      expect(await TaxiRingSession.isDriver(), isFalse);
    });

    test('background_isolate_reads_the_stored_token_after_init', () async {
      final dir = Directory.systemTemp.createTempSync('ring_session');
      addTearDown(() {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
      });
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
      messenger.setMockMethodCallHandler(pathProvider, (_) async => dir.path);
      addTearDown(() => messenger.setMockMethodCallHandler(pathProvider, null));
      await GetStorage.init();
      await StorageService.clearToken();
      FlutterSecureStorage.setMockInitialValues({AppConstants.tokenKey: _driverToken});
      expect(await TaxiRingSession.isDriver(), isFalse);
      await StorageService.init();
      expect(await TaxiRingSession.isDriver(), isTrue);
    });
  });

  group('ring names its driver', () {
    Map<String, dynamic> ringFor(String id) => {..._data('push_ring.json'), 'driverUserId': id};

    test('ring_for_another_user_is_not_shown_and_not_acked', () async {
      final h = _Harness((id) async => id == _me);
      final result = await h.service.handle(ringFor('someone-else'));
      await result.ack;
      expect(result.outcome, TaxiRingOutcome.ignored);
      expect(h.notifier.shown, isEmpty);
      expect(h.acks, isEmpty);
    });

    test('ring_for_this_user_is_shown', () async {
      final h = _Harness((id) async => id == _me);
      final result = await h.service.handle(ringFor(_me));
      await result.ack;
      expect(result.outcome, TaxiRingOutcome.shown);
      expect(h.acks, hasLength(1));
    });

    test('test_ring_for_another_user_is_not_shown', () async {
      final h = _Harness((id) async => id == _me);
      final result = await h.service.handle({..._testRing(), 'driverUserId': 'someone-else'});
      expect(result.outcome, TaxiRingOutcome.ignored);
      expect(h.notifier.shown, isEmpty);
    });

    test('ring_without_driver_user_id_passes_null_to_the_check', () async {
      String? seen = 'unset';
      final h = _Harness((id) async {
        seen = id;
        return true;
      });
      await h.service.handle(_data('push_ring.json')..remove('driverUserId'));
      expect(seen, isNull);
    });
  });

  group('accepts', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));
    tearDown(() async => StorageService.clearToken());

    test('accepts_matches_the_token_user_id_case_insensitive', () async {
      await StorageService.saveToken(_driverIdToken);
      expect(await TaxiRingSession.accepts(_me.toUpperCase()), isTrue);
      expect(await TaxiRingSession.accepts('9b2f7c1e-0000-4000-8000-0000000000bb'), isFalse);
    });

    test('accepts_without_an_id_falls_back_to_the_role_check', () async {
      await StorageService.saveToken(_driverIdToken);
      expect(await TaxiRingSession.accepts(null), isTrue);
      expect(await TaxiRingSession.accepts(''), isTrue);
    });

    test('accepts_is_false_for_a_seeker_token', () async {
      await StorageService.saveToken(_jwt({'nameid': _me, 'role': 'SEEKER'}));
      expect(await TaxiRingSession.accepts(_me), isFalse);
    });

    test('accepts_is_false_when_logged_out', () async {
      expect(await TaxiRingSession.accepts(_me), isFalse);
    });
  });

  test('real_entry_points_use_the_session_gate', () {
    final ring = File('lib/services/taxi_ring_service.dart').readAsStringSync();
    expect(ring, contains('driverSession: TaxiRingSession.accepts,'));
    final source = File('lib/services/notification_service.dart').readAsStringSync();
    final init = source.indexOf('await StorageService.init();');
    expect(init, greaterThan(source.indexOf('if (ring.kind == TaxiRingKind.end)')));
    expect(init, lessThan(source.indexOf('final result = await TaxiRingService.withPlugin(plugin).handle')));
    expect(source, contains('final result = await TaxiRingService.withPlugin(_localNotifications).handle(data);'));
  });
}
