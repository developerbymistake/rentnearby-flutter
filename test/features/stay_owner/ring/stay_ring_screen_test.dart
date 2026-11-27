import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/stay_owner/ring/stay_ring_screen.dart';
import 'package:bakhli/services/system_settings_channel.dart';
import 'package:bakhli/services/taxi_ring_service.dart';
import 'package:bakhli/services/taxi_ring_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/five_sizes.dart';
import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';

const _id = '5e0c7a11-0001-4a00-8000-0000000000e1';
const _tag = 'stay_ring_$_id';

class _FakeAlert implements RingAlertControl {
  _FakeAlert(this.log);
  final List<String> log;

  @override
  Future<bool> ringAlertHold(String tag, Duration left) async {
    log.add('hold:$tag');
    return true;
  }

  @override
  Future<bool> ringAlertEnd(String tag, {bool unlock = false}) async {
    log.add('end:$tag:$unlock');
    return true;
  }
}

class _Notifier implements TaxiRingNotifier {
  _Notifier(this.log);
  final List<String> log;

  @override
  Future<void> show(int id, String title, String body, NotificationDetails details, String? payload) async {}

  @override
  Future<void> cancel(int id, String tag) async => log.add('cancel:$tag');
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

const _info = StayRingInfo(
  travellerFirstName: 'Asha',
  stayName: 'Hill View Homestay',
  checkIn: null,
  checkOut: null,
  guests: 3,
  price: 4500,
);

class _Harness {
  final log = <String>[];
  final opened = <String>[];
  final accepted = <String>[];
  int closed = 0;
  DateTime now = DateTime.utc(2026, 12, 10, 9, 41, 7);

  Widget screen({StayRingAction? action, StayRingInfo? info, DateTime? expiresAt}) => StayRingScreen(
        enquiryId: _id,
        action: action,
        expiresAt: expiresAt ?? DateTime.utc(2026, 12, 10, 9, 46, 7),
        info: info ?? StayRingInfo(travellerFirstName: _info.travellerFirstName, stayName: _info.stayName, checkIn: DateTime(2026, 12, 18), checkOut: DateTime(2026, 12, 20), guests: 3, price: 4500),
        alert: _FakeAlert(log),
        notifier: _Notifier(log),
        clock: () => now,
        onAccepted: (id) {
          log.add('opened');
          opened.add(id);
        },
        onClose: () {
          log.add('closed');
          closed++;
        },
        sendAccepted: (id) async => accepted.add(id),
      );
}

Future<_Harness> _open(WidgetTester tester, {StayRingAction? action, StayRingInfo? info, DateTime? expiresAt, Size size = phoneSize}) async {
  final h = _Harness();
  await pumpAtSize(tester, h.screen(action: action, info: info, expiresAt: expiresAt), size);
  await tester.pump();
  await tester.pump();
  return h;
}

void main() {
  late FakeTransport transport;
  setUp(() {
    Get.reset();
    TaxiRingSession.reset();
    TaxiRingEndedLog.store = _MemoryStore();
    transport = FakeTransport((m, p, b) async => {'data': {}});
    OwnerApi.transport = transport;
  });
  tearDown(() {
    TaxiRingEndedLog.store = const GetStorageTaxiRingDeviceStore();
    OwnerApi.debugReset();
  });

  testWidgets('UC14 ring shows first name, stay, dates, guests, price and no phone', (tester) async {
    await _open(tester);
    expect(find.text('INCOMING ENQUIRY'), findsOneWidget);
    expect(find.text('New stay enquiry'), findsOneWidget);
    expect(find.text('Hill View Homestay'), findsOneWidget);
    expect(find.text('From Asha'), findsOneWidget);
    expect(find.text('18 to 20 Dec · 2 nights'), findsOneWidget);
    expect(find.text('3 guests'), findsOneWidget);
    expect(find.text('₹4,500'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('5:00'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d{10}')), findsNothing);
  });

  testWidgets('price and guests are left out when the enquiry has none', (tester) async {
    await _open(tester, info: const StayRingInfo(travellerFirstName: 'Asha', stayName: 'Hill View Homestay'));
    expect(find.textContaining('₹'), findsNothing);
    expect(find.textContaining('guest'), findsNothing);
  });

  testWidgets('the screen holds the lock screen alert with the stay ring tag', (tester) async {
    final h = await _open(tester);
    expect(h.log, contains('hold:$_tag'));
  });

  testWidgets('UC5 Accept stops the ring, unlocks, opens the enquiry, changes nothing', (tester) async {
    final h = await _open(tester);
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump();
    expect(h.opened, [_id]);
    expect(h.log, containsAllInOrder(['cancel:$_tag', 'end:$_tag:true', 'opened']));
    expect(h.accepted, [_id]);
    expect(TaxiRingEndedLog.contains(_id, h.now), isTrue);
    expect(transport.calls, isEmpty);
  });

  testWidgets('UC6 Decline only stops the ring: no server call, no enquiry opened', (tester) async {
    final h = await _open(tester);
    await tester.tap(find.text('Decline'));
    await tester.pump();
    await tester.pump();
    expect(h.closed, 1);
    expect(h.opened, isEmpty);
    expect(h.accepted, isEmpty);
    expect(h.log, containsAllInOrder(['cancel:$_tag', 'end:$_tag:false', 'closed']));
    expect(transport.calls, isEmpty);
  });

  testWidgets('swipe up answers like Accept', (tester) async {
    final h = await _open(tester);
    await tester.fling(find.text('New stay enquiry'), const Offset(0, -400), 1500);
    await tester.pump();
    await tester.pump();
    expect(h.opened, [_id]);
  });

  testWidgets('UC10 notification Accept opens the enquiry at once', (tester) async {
    final h = await _open(tester, action: StayRingAction.accept);
    expect(h.opened, [_id]);
    expect(h.accepted, [_id]);
  });

  testWidgets('UC10 notification Decline closes at once without a call', (tester) async {
    final h = await _open(tester, action: StayRingAction.decline);
    expect(h.closed, 1);
    expect(h.accepted, isEmpty);
    expect(transport.calls, isEmpty);
  });

  testWidgets('UC7 answered on another phone ends the ring and closes', (tester) async {
    final h = await _open(tester);
    TaxiRingSession.ended.value = const TaxiRingEnd(_id, 'Answered', role: RingRole.stay);
    await tester.pump();
    expect(find.text('You answered this enquiry'), findsOneWidget);
    expect(find.text('The enquiry is waiting in Enquiries.'), findsOneWidget);
    expect(h.log, contains('cancel:$_tag'));
    await tester.pump(const Duration(seconds: 3));
    expect(h.closed, 1);
    expect(h.opened, isEmpty);
  });

  testWidgets('UC8 a closed enquiry ends the ring', (tester) async {
    final h = await _open(tester);
    TaxiRingSession.ended.value = const TaxiRingEnd(_id, 'Closed', role: RingRole.stay);
    await tester.pump();
    expect(find.text('This enquiry is closed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(h.closed, 1);
  });

  testWidgets('an end for another enquiry or a taxi offer leaves the ring alone', (tester) async {
    final h = await _open(tester);
    TaxiRingSession.ended.value = const TaxiRingEnd('other', 'Answered', role: RingRole.stay);
    await tester.pump();
    TaxiRingSession.ended.value = const TaxiRingEnd(_id, 'Booked');
    await tester.pump();
    expect(find.text('New stay enquiry'), findsOneWidget);
    expect(h.closed, 0);
  });

  testWidgets('UC6 Decline on the notification closes an open ring screen', (tester) async {
    final h = await _open(tester);
    TaxiRingSession.ended.value = const TaxiRingEnd(_id, StayRingEnds.declinedHere, role: RingRole.stay);
    await tester.pump();
    await tester.pump();
    expect(h.closed, 1);
    expect(h.opened, isEmpty);
    expect(transport.calls, isEmpty);
  });

  testWidgets('UC9 the ring times out to Missed; the enquiry waits in Enquiries', (tester) async {
    final h = await _open(tester);
    h.now = h.now.add(const Duration(minutes: 5, seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Missed enquiry ring'), findsOneWidget);
    expect(find.text('Open enquiries'), findsOneWidget);
    expect(h.log, contains('cancel:$_tag'));
    await tester.pump(const Duration(seconds: 3));
    expect(h.closed, 1);
    expect(h.opened, isEmpty);
    expect(transport.calls, isEmpty);
  });

  testWidgets('UC9 a missed push shows Missed and Open enquiries opens the enquiry', (tester) async {
    final h = await _open(tester);
    TaxiRingSession.ended.value = const TaxiRingEnd(_id, StayRingEnds.missed, role: RingRole.stay);
    await tester.pump();
    expect(find.text('Missed enquiry ring'), findsOneWidget);
    await tester.tap(find.text('Open enquiries'));
    await tester.pump();
    await tester.pump();
    expect(h.opened, [_id]);
  });

  testWidgets('a ring opened after its window shows Missed at once', (tester) async {
    await _open(tester, expiresAt: DateTime.utc(2026, 12, 10, 9, 41));
    expect(find.text('Missed enquiry ring'), findsOneWidget);
  });

  testWidgets('back closes like Decline', (tester) async {
    final h = await _open(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    await nav.maybePop();
    await tester.pump();
    await tester.pump();
    expect(h.closed, 1);
    expect(h.opened, isEmpty);
  });

  test('fromArguments reads the ring arguments', () {
    final s = StayRingScreen.fromArguments({
      'enquiryId': _id,
      'action': 'accept',
      'expiresAt': '2026-12-10T09:46:07.000Z',
      'guestName': 'Asha',
      'stayName': 'Hill View Homestay',
      'checkIn': '2026-12-18',
      'checkOut': '2026-12-20',
      'guests': 3,
      'price': 4500,
    });
    expect(s.enquiryId, _id);
    expect(s.action, StayRingAction.accept);
    expect(s.expiresAt, DateTime.utc(2026, 12, 10, 9, 46, 7));
    expect(s.info.travellerFirstName, 'Asha');
    expect(s.info.guests, 3);
    expect(s.info.price, 4500);
    expect(StayRingScreen.fromArguments(null).enquiryId, isEmpty);
  });

  for (final size in fiveSizes) {
    testWidgets('stay_ring_five_sizes at ${sizeLabel(size)}', (tester) async {
      await _open(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('Accept'), findsOneWidget);
    });
  }

  testWidgets('render stay ring frames', (tester) async {
    final h = await _open(tester);
    await settlePhone(tester);
    expect((await shot(tester, 'stay_ring_ringing')).existsSync(), isTrue);
    TaxiRingSession.ended.value = const TaxiRingEnd(_id, StayRingEnds.missed, role: RingRole.stay);
    await tester.pump();
    await settlePhone(tester);
    expect((await shot(tester, 'stay_ring_missed')).existsSync(), isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(h.closed, 1);
  });
}
