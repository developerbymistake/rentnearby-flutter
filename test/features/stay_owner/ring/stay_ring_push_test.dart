import 'dart:convert';
import 'dart:io';

import 'package:bakhli/services/storage_service.dart';
import 'package:bakhli/services/taxi_ring_service.dart';
import 'package:bakhli/services/taxi_ring_session.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _samples = 'test/features/stay_owner/ring/samples';
const _enquiryId = '5e0c7a11-0001-4a00-8000-0000000000e1';
const _owner = '7c1e2f3a-0005-4b00-9000-0000000000a5';
final _receivedAt = DateTime.utc(2026, 12, 10, 9, 41, 9);

Map<String, dynamic> _data(String name) =>
    Map<String, dynamic>.from((jsonDecode(File('$_samples/$name').readAsStringSync()) as Map)['data'] as Map);

Map<String, dynamic> _taxiRing() => Map<String, dynamic>.from(
    (jsonDecode(File('test/features/taxi_request/samples/push_ring.json').readAsStringSync()) as Map)['data'] as Map);

String _jwt(Map<String, dynamic> claims) {
  String part(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(claims)}.c2ln';
}

class _Shown {
  _Shown(this.title, this.body, this.details, this.payload);
  final String title;
  final String body;
  final NotificationDetails details;
  final String? payload;
}

class _Notifier implements TaxiRingNotifier {
  final shown = <_Shown>[];
  final cancelled = <String>[];

  @override
  Future<void> show(int id, String title, String body, NotificationDetails details, String? payload) async =>
      shown.add(_Shown(title, body, details, payload));

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
  _Harness({bool stayOwner = true, bool driver = false, DateTime? now}) {
    service = TaxiRingService(
      notifier: notifier,
      sendAck: (offerId, body) async => acks.add(offerId),
      probe: () async => const TaxiRingDeviceState(notificationsOn: true, ringChannelOn: true, manufacturer: 'Xiaomi', androidSdk: 34, appBuild: 69),
      clock: () => now ?? _receivedAt,
      driverSession: (id) async => driver,
      stayOwnerSession: (id) async {
        ownerIds.add(id);
        return stayOwner;
      },
    );
  }

  final notifier = _Notifier();
  final acks = <String>[];
  final ownerIds = <String?>[];
  late final TaxiRingService service;
}

void main() {
  setUp(() {
    TaxiRingService.resetTestRingMarker();
    TaxiRingSession.reset();
    TaxiRingEndedLog.store = _MemoryStore();
  });
  tearDown(() => TaxiRingEndedLog.store = const GetStorageTaxiRingDeviceStore());

  group('parse', () {
    test('stay_ring_push_reads_the_server_payload', () {
      final p = TaxiRingPush.tryParse(_data('push_stay_ring.json'))!;
      expect(p.role, RingRole.stay);
      expect(p.isStay, isTrue);
      expect(p.kind, TaxiRingKind.ring);
      expect(p.offerId, _enquiryId);
      expect(p.expiresAt, DateTime.utc(2026, 12, 10, 9, 46, 7));
      expect(p.driverUserId, _owner);
      expect(p.title, 'New stay enquiry');
      expect(p.tag, 'stay_ring_$_enquiryId');
      final info = p.stay!;
      expect(info.travellerFirstName, 'Asha');
      expect(info.stayName, 'Hill View Homestay');
      expect(info.checkIn, DateTime(2026, 12, 18));
      expect(info.checkOut, DateTime(2026, 12, 20));
      expect(info.guests, 3);
      expect(info.price, 4500);
    });

    test('stay_ring_needs_version_enquiry_id_and_expiry', () {
      expect(TaxiRingPush.tryParse({..._data('push_stay_ring.json'), 'v': '2'}), isNull);
      expect(TaxiRingPush.tryParse({..._data('push_stay_ring.json'), 'enquiryId': ''}), isNull);
      expect(TaxiRingPush.tryParse(_data('push_stay_ring.json')..remove('expiresAt')), isNull);
      expect(TaxiRingPush.isUnreadableRing({..._data('push_stay_ring.json'), 'enquiryId': ''}), isTrue);
    });

    test('stay_ring_needs_no_ack_token', () {
      expect(_data('push_stay_ring.json').containsKey('ackToken'), isFalse);
      expect(TaxiRingPush.tryParse(_data('push_stay_ring.json')), isNotNull);
    });

    test('ring_end_and_missed_are_ends_with_their_reason', () {
      final end = TaxiRingPush.tryParse(_data('push_stay_ring_end.json'))!;
      expect(end.kind, TaxiRingKind.end);
      expect(end.reason, 'Answered');
      expect(end.tag, 'stay_ring_$_enquiryId');
      final missed = TaxiRingPush.tryParse(_data('push_stay_ring_missed.json'))!;
      expect(missed.kind, TaxiRingKind.end);
      expect(missed.reason, StayRingEnds.missed);
      expect(missed.tag, 'stay_ring_$_enquiryId');
    });

    test('test_ring_has_no_enquiry_and_its_own_tag', () {
      final t = TaxiRingPush.tryParse(_data('push_stay_ring_test.json'))!;
      expect(t.kind, TaxiRingKind.test);
      expect(t.offerId, isEmpty);
      expect(t.tag, TaxiRingPush.stayTestTag);
      expect(TaxiRingNotification.payload(t), isNull);
    });

    test('received_at_keeps_role_and_info', () {
      final p = TaxiRingPush.tryParse(_data('push_stay_ring.json'))!.receivedAt(_receivedAt);
      expect(p.role, RingRole.stay);
      expect(p.stay?.travellerFirstName, 'Asha');
      expect(p.driverUserId, _owner);
    });

    test('taxi_push_still_parses_as_taxi', () {
      final p = TaxiRingPush.tryParse(_taxiRing())!;
      expect(p.role, RingRole.taxi);
      expect(p.isStay, isFalse);
      expect(p.tag, TaxiRingNotification.tagFor(p.offerId));
      expect(p.stay, isNull);
    });
  });

  group('notification', () {
    test('stay_ring_rings_on_the_stay_channel_full_screen', () {
      final p = TaxiRingPush.tryParse(_data('push_stay_ring.json'))!;
      final a = TaxiRingNotification.android(p, _receivedAt);
      expect(a.channelId, TaxiRingNotification.stayRingChannelId);
      expect(a.channelId, 'stay_enquiry_ring_v1');
      expect(a.fullScreenIntent, isTrue);
      expect(a.category, AndroidNotificationCategory.call);
      expect(a.ongoing, isTrue);
      expect(a.tag, 'stay_ring_$_enquiryId');
    });

    test('stay_decline_action_never_opens_the_app_accept_does', () {
      final p = TaxiRingPush.tryParse(_data('push_stay_ring.json'))!;
      final actions = TaxiRingNotification.android(p, _receivedAt).actions!;
      final decline = actions.firstWhere((a) => a.id == TaxiRingNotification.declineAction);
      final accept = actions.firstWhere((a) => a.id == TaxiRingNotification.acceptAction);
      expect(decline.showsUserInterface, isFalse);
      expect(decline.cancelNotification, isTrue);
      expect(accept.showsUserInterface, isTrue);
    });

    test('taxi_actions_are_unchanged', () {
      final p = TaxiRingPush.tryParse(_taxiRing())!;
      final a = TaxiRingNotification.android(p, _receivedAt);
      expect(a.channelId, TaxiRingNotification.ringChannelId);
      expect(a.actions!.every((x) => x.showsUserInterface), isTrue);
    });

    test('stay_body_reads_first_name_stay_dates_and_guests', () {
      final p = TaxiRingPush.tryParse(_data('push_stay_ring.json'))!;
      expect(TaxiRingNotification.bodyLines(p), ['Asha · Hill View Homestay', '2 nights · 18 to 20 Dec', '2 adults, 1 kid · 1 room · Rs 4,500']);
      expect(TaxiRingNotification.body(p), 'Asha · Hill View Homestay');
    });

    test('stay_route_data_opens_the_stay_ring_screen', () {
      final p = TaxiRingPush.tryParse(_data('push_stay_ring.json'))!;
      final route = TaxiRingNotification.routeData(p, action: 'accept');
      expect(route['notification_type'], 'stay_enquiry_ring');
      expect(route['action_route'], TaxiRingPush.stayRingRoute);
      expect(route['action_route'], '/stay-enquiry-ring');
      expect(route[TaxiRingNotification.tagKey], 'stay_ring_$_enquiryId');
      final args = jsonDecode(route['action_args_json'] as String) as Map<String, dynamic>;
      expect(args['enquiryId'], _enquiryId);
      expect(args['action'], 'accept');
      expect(args['guestName'], 'Asha');
      expect(args['guests'], 3);
      expect(args['price'], 4500);
      expect(args['checkIn'], '2026-12-18');
      expect(TaxiRingNotification.isRingPayload(route), isTrue);
      expect(TaxiRingNotification.isStayRingPayload(route), isTrue);
    });

    test('taxi_route_data_is_unchanged', () {
      final p = TaxiRingPush.tryParse(_taxiRing())!;
      final route = TaxiRingNotification.routeData(p);
      expect(route['notification_type'], 'taxi_request_ring');
      expect(route['action_route'], '/taxi-request-ring');
      expect(TaxiRingNotification.isStayRingPayload(route), isFalse);
    });

    test('UC14_no_phone_or_contact_reaches_the_ring_payload', () {
      final p = TaxiRingPush.tryParse({..._data('push_stay_ring.json'), 'phone': '9897012345', 'travellerPhone': '9897012345', 'guestName': 'Asha Rawat'})!;
      final payload = TaxiRingNotification.payload(p)!;
      expect(payload, isNot(contains('9897012345')));
      expect(payload, isNot(contains('Rawat')));
      expect(TaxiRingNotification.bodyLines(p).join(' '), isNot(contains('9897012345')));
    });

    test('ring_end_and_missed_show_on_the_stay_updates_channel', () {
      final end = TaxiRingPush.tryParse(_data('push_stay_ring_missed.json'))!;
      final a = TaxiRingNotification.endDetails(end).android!;
      expect(a.channelId, 'stay_enquiry_updates_v1');
      expect(a.tag, 'stay_ring_$_enquiryId');
      final taxiEnd = TaxiRingPush.tryParse({..._taxiRing(), 'kind': 'taxi_ring_end'})!;
      expect(TaxiRingNotification.endDetails(taxiEnd).android!.channelId, TaxiRingNotification.updatesChannelId);
    });
  });

  group('service', () {
    test('UC1_stay_ring_shows_for_the_stay_owner_without_an_ack', () async {
      final h = _Harness();
      final r = await h.service.handle(_data('push_stay_ring.json'));
      await r.ack;
      expect(r.outcome, TaxiRingOutcome.shown);
      expect(h.notifier.shown.single.title, 'New stay enquiry');
      expect(h.notifier.shown.single.payload, contains('/stay-enquiry-ring'));
      expect(h.ownerIds, [_owner]);
      expect(h.acks, isEmpty);
    });

    test('UC2_stay_ring_is_ignored_without_a_stay_owner_session', () async {
      final h = _Harness(stayOwner: false, driver: true);
      final r = await h.service.handle(_data('push_stay_ring.json'));
      expect(r.outcome, TaxiRingOutcome.ignored);
      expect(h.notifier.shown, isEmpty);
    });

    test('UC2_stay_ring_without_a_stay_owner_check_never_shows', () async {
      final service = TaxiRingService(notifier: _Notifier(), sendAck: (_, _) async {}, probe: () async => throw StateError('x'), clock: () => _receivedAt);
      final r = await service.handle(_data('push_stay_ring.json'));
      expect(r.outcome, TaxiRingOutcome.ignored);
    });

    test('UC13_taxi_ring_does_not_use_the_stay_owner_check', () async {
      final h = _Harness(stayOwner: false, driver: true);
      final r = await h.service.handle(_taxiRing());
      await r.ack;
      expect(r.outcome, TaxiRingOutcome.shown);
      expect(h.ownerIds, isEmpty);
      expect(h.acks, hasLength(1));
    });

    test('UC7_UC8_ring_end_cancels_the_ring_and_tells_the_screen', () async {
      final h = _Harness();
      final r = await h.service.handle(_data('push_stay_ring_end.json'));
      expect(r.outcome, TaxiRingOutcome.ended);
      expect(h.notifier.cancelled, ['stay_ring_$_enquiryId']);
      final e = TaxiRingSession.ended.value!;
      expect(e.offerId, _enquiryId);
      expect(e.role, RingRole.stay);
      expect(e.reason, 'Answered');
    });

    test('UC9_missed_push_ends_the_ring_with_missed', () async {
      final h = _Harness();
      await h.service.handle(_data('push_stay_ring_missed.json'));
      expect(TaxiRingSession.ended.value!.reason, StayRingEnds.missed);
      expect(h.notifier.cancelled, ['stay_ring_$_enquiryId']);
    });

    test('a_ring_arriving_after_its_end_never_shows', () async {
      final h = _Harness();
      await h.service.handle(_data('push_stay_ring_end.json'));
      final r = await h.service.handle(_data('push_stay_ring.json'));
      expect(r.outcome, TaxiRingOutcome.alreadyEnded);
      expect(h.notifier.shown, isEmpty);
      expect(h.acks, isEmpty);
    });

    test('an_expired_stay_ring_never_shows', () async {
      final h = _Harness(now: DateTime.utc(2026, 12, 10, 9, 50));
      final r = await h.service.handle({..._data('push_stay_ring.json'), 'sentAt': '2026-12-10T09:50:00Z', 'expiresAt': '2026-12-10T09:49:00Z'});
      expect(r.outcome, TaxiRingOutcome.expired);
      expect(h.notifier.shown, isEmpty);
    });

    test('UC11_two_enquiries_ring_with_their_own_tags', () async {
      final h = _Harness();
      await h.service.handle(_data('push_stay_ring.json'));
      await h.service.handle({..._data('push_stay_ring.json'), 'enquiryId': '5e0c7a11-0001-4a00-8000-0000000000e2'});
      final tags = [for (final s in h.notifier.shown) (s.details.android as AndroidNotificationDetails).tag];
      expect(tags, ['stay_ring_$_enquiryId', 'stay_ring_5e0c7a11-0001-4a00-8000-0000000000e2']);
    });

    test('UC15_server_test_ring_marks_the_test_shown', () async {
      final h = _Harness();
      final r = await h.service.handle(_data('push_stay_ring_test.json'));
      expect(r.outcome, TaxiRingOutcome.testShown);
      expect(TaxiRingService.lastTestRingShownAt, isNotNull);
      final details = h.notifier.shown.single.details.android as AndroidNotificationDetails;
      expect(details.fullScreenIntent, isFalse);
      expect(details.channelId, TaxiRingNotification.stayRingChannelId);
    });
  });

  group('channel ready', () {
    AndroidNotificationChannel ch(String id, Importance i) => AndroidNotificationChannel(id, 'x', importance: i);

    test('stay_channel_check_reads_the_stay_channel_only', () {
      const stay = TaxiRingNotification.stayRingChannelId;
      expect(TaxiRingDevice.ringChannelReady([ch(stay, Importance.max)], channelId: stay), isTrue);
      expect(TaxiRingDevice.ringChannelReady([ch(stay, Importance.low)], channelId: stay), isFalse);
      expect(TaxiRingDevice.ringChannelReady([ch(TaxiRingNotification.ringChannelId, Importance.max)], channelId: stay), isFalse);
      expect(TaxiRingDevice.ringChannelReady([ch(TaxiRingNotification.ringChannelId, Importance.max)]), isTrue);
    });
  });

  group('acceptsStay', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));
    tearDown(() async => StorageService.clearToken());

    test('UC2_UC16_only_a_stay_owner_token_for_this_owner_rings', () async {
      await StorageService.saveToken(_jwt({'nameid': _owner, 'role': 'STAY_OWNER'}));
      expect(await TaxiRingSession.acceptsStay(_owner.toUpperCase()), isTrue);
      expect(await TaxiRingSession.acceptsStay(null), isTrue);
      expect(await TaxiRingSession.acceptsStay('9b2f7c1e-0000-4000-8000-0000000000bb'), isFalse);
      expect(await TaxiRingSession.accepts(_owner), isFalse);
    });

    test('UC16_role_change_or_logout_stops_rings', () async {
      await StorageService.saveToken(_jwt({'nameid': _owner, 'role': 'SEEKER'}));
      expect(await TaxiRingSession.acceptsStay(_owner), isFalse);
      await StorageService.saveToken(_jwt({'nameid': _owner, 'role': 'TAXI_DRIVER'}));
      expect(await TaxiRingSession.acceptsStay(_owner), isFalse);
      await StorageService.clearToken();
      expect(await TaxiRingSession.acceptsStay(_owner), isFalse);
    });

    test('real_entry_point_uses_the_stay_owner_gate', () {
      final ring = File('lib/services/taxi_ring_service.dart').readAsStringSync();
      expect(ring, contains('stayOwnerSession: TaxiRingSession.acceptsStay,'));
      expect(ring, contains('driverSession: TaxiRingSession.accepts,'));
    });
  });
}
