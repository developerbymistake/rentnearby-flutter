import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/taxi/requests/controllers/driver_requests_controller.dart';
import 'package:bakhli/features/taxi/requests/data/driver_request_repository.dart';
import 'package:bakhli/features/taxi/requests/driver_requests_screen.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/features/trip/widgets/taxi_status/taxi_driver_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('test/features/taxi_request/samples/$name').readAsStringSync()) as Map<String, dynamic>;

const _ringingId = 'a1b2c3d4-0001-4a00-8000-000000000001';
const _bookedId = 'a1b2c3d4-0009-4a00-8000-000000000009';
const _missedId = 'a1b2c3d4-0010-4a00-8000-000000000010';
const _notSelectedId = 'a1b2c3d4-0011-4a00-8000-000000000011';
const _acceptedId = 'a1b2c3d4-0021-4a00-8000-000000000021';
const _selectedId = 'a1b2c3d4-0022-4a00-8000-000000000022';
const _notAgreedId = 'a1b2c3d4-0023-4a00-8000-000000000023';
const _closedId = 'a1b2c3d4-0024-4a00-8000-000000000024';
const _endedId = 'a1b2c3d4-0025-4a00-8000-000000000025';

Map<String, dynamic> _item(String id, String state, String bucket, {String? confirmBy, String? endReason, bool named = false}) {
  final base = (_json('driver_offer_list.json')['items'] as List).first as Map<String, dynamic>;
  return {
    ...base,
    'offerId': id,
    'state': state,
    'bucket': bucket,
    'expiresAt': null,
    'confirmBy': confirmBy,
    'endReason': endReason,
    'traveller': named ? {'name': 'Meera Joshi', 'phone': null} : null,
  };
}

Map<String, dynamic> _allStates() => {
      ..._json('driver_offer_list.json'),
      'items': [
        _item(_acceptedId, 'Accepted', 'New', named: true),
        _item(_selectedId, 'Selected', 'New', confirmBy: '2026-12-10T09:58:00Z', named: true),
        _item(_notAgreedId, 'NotAgreed', 'Earlier'),
        _item(_closedId, 'Closed', 'Earlier', endReason: 'RequestCancelled'),
        _item(_endedId, 'Confirmed', 'Earlier'),
      ],
    };

Finder _in(String id, Finder f) => find.descendant(of: find.byKey(ValueKey('request_card_$id')), matching: f);

BoxDecoration _decoration(WidgetTester tester, String id) =>
    tester.widget<Container>(find.byKey(ValueKey('request_card_$id'))).decoration! as BoxDecoration;

class _FakeRepo extends DriverRequestRepository {
  _FakeRepo();

  TaxiResult<DriverOfferList>? listResult;
  Map<String, dynamic> Function()? listJson;
  TaxiResult<DriverOffer>? acceptResult;
  final List<String> accepted = [];
  final List<String> declined = [];
  final List<String?> cursors = [];
  DateTime Function()? clock;

  @override
  Future<TaxiResult<DriverOfferList>> offers({String? cursor}) async {
    cursors.add(cursor);
    final j = {...(listJson?.call() ?? _json('driver_offer_list.json'))};
    final now = clock;
    if (now != null) j['serverNow'] = now().toIso8601String();
    return listResult ?? TaxiOk(DriverOfferList.fromJson(j));
  }

  @override
  Future<TaxiResult<DriverOffer>> accept(String offerId) async {
    accepted.add(offerId);
    return acceptResult ?? TaxiOk(DriverOffer.fromJson(_json('driver_offer_detail_ringing.json')));
  }

  @override
  Future<TaxiResult<DriverOffer>> decline(String offerId, {ReasonChip? chip}) async {
    declined.add(offerId);
    return TaxiOk(DriverOffer.fromJson(_json('driver_offer_detail_ringing.json')));
  }
}

class _Rig {
  _Rig({this.repo}) {
    repo ??= _FakeRepo();
    repo!.clock = () => deviceNow;
    controller = DriverRequestsController(repo: repo!, now: () => deviceNow);
  }

  _FakeRepo? repo;
  late final DriverRequestsController controller;
  DateTime deviceNow = DateTime.utc(2026, 12, 10, 9, 43);
  final List<String> opened = [];

  Widget screen() => DriverRequestsScreen(controller: controller, onOpenOffer: opened.add, onBack: () {});
}

const _tall = Size(360, 2400);

Future<_Rig> _open(WidgetTester tester, {_FakeRepo? repo, Size size = phoneSize}) async {
  final rig = _Rig(repo: repo);
  await pumpAtSize(tester, rig.screen(), size);
  await tester.pump();
  await tester.pump();
  return rig;
}

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  testWidgets('sample_renders_groups_and_chips', (tester) async {
    await _open(tester, size: _tall);
    expect(find.text('Taxi requests'), findsOneWidget);
    expect(_key('requests_group_new'), findsOneWidget);
    expect(_key('requests_group_booked'), findsOneWidget);
    expect(_key('requests_group_earlier'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Sightseeing 3 days'), findsOneWidget);
    expect(_in(_bookedId, find.text('Booked')), findsOneWidget);
    expect(_in(_bookedId, find.text('26 to 28 Dec')), findsOneWidget);
    expect(tester.widget<TaxiStateChip>(_in(_bookedId, find.byType(TaxiStateChip))).positive, isTrue);
    expect(_decoration(tester, _bookedId).border, isNotNull);
    expect(find.text('Missed'), findsOneWidget);
    expect(find.text('Went to the next drivers'), findsOneWidget);
    expect(find.text('Not selected'), findsOneWidget);
    expect(find.text('Traveller chose another driver'), findsOneWidget);
    expect(find.text('Kathgodam pickup'), findsOneWidget);
    expect(find.text('4 days · 3 nights · 18 to 21 Dec'), findsOneWidget);
    expect(find.text('4 seater · 2 travellers'), findsWidgets);
    expect(_key('request_accept_$_ringingId'), findsOneWidget);
    expect(_key('request_accept_$_bookedId'), findsNothing);
    expect(_key('request_accept_$_missedId'), findsNothing);
    expect(_key('request_card_$_notSelectedId'), findsOneWidget);
  });

  testWidgets('chips_for_every_state', (tester) async {
    final repo = _FakeRepo()..listJson = _allStates;
    await _open(tester, repo: repo, size: _tall);
    expect(_in(_acceptedId, find.text('Accepted')), findsOneWidget);
    expect(_in(_acceptedId, find.text('Waiting for the traveller')), findsOneWidget);
    expect(_in(_selectedId, find.text('15:00 left')), findsOneWidget);
    expect(_in(_selectedId, find.text('Traveller chose you')), findsOneWidget);
    expect(_in(_notAgreedId, find.text('Closed')), findsOneWidget);
    expect(_in(_notAgreedId, find.text('Price not agreed')), findsOneWidget);
    expect(_in(_closedId, find.text('Closed')), findsOneWidget);
    expect(_in(_closedId, find.text('Request closed')), findsOneWidget);
    expect(_in(_acceptedId, find.byKey(const ValueKey('request_accept_$_acceptedId'))), findsNothing);
  });

  testWidgets('ended_booking_under_earlier_is_not_shown_as_booked', (tester) async {
    final repo = _FakeRepo()..listJson = _allStates;
    await _open(tester, repo: repo, size: _tall);
    expect(_key('requests_group_booked'), findsNothing);
    expect(_in(_endedId, find.text('Booked')), findsNothing);
    expect(_in(_endedId, find.text('Closed')), findsOneWidget);
    expect(_in(_endedId, find.text('This ride has ended')), findsOneWidget);
    expect(tester.widget<TaxiStateChip>(_in(_endedId, find.byType(TaxiStateChip))).positive, isFalse);
    expect(_decoration(tester, _endedId).border, isNull);
  });

  testWidgets('selected_confirm_by_counts_down', (tester) async {
    final repo = _FakeRepo()..listJson = _allStates;
    final rig = await _open(tester, repo: repo, size: _tall);
    expect(_in(_selectedId, find.text('15:00 left')), findsOneWidget);
    rig.deviceNow = rig.deviceNow.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    expect(_in(_selectedId, find.text('14:30 left')), findsOneWidget);
  });

  testWidgets('name_hidden_before_accept', (tester) async {
    await _open(tester, size: _tall);
    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.text('Traveller'), findsNWidgets(3));
  });

  testWidgets('tap_opens_the_offer', (tester) async {
    final rig = await _open(tester);
    await tester.tap(_key('request_open_$_bookedId'));
    await tester.pump();
    expect(rig.opened, [_bookedId]);
  });

  testWidgets('countdown', (tester) async {
    final rig = await _open(tester);
    expect(find.text('3:07 left'), findsOneWidget);
    rig.deviceNow = rig.deviceNow.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('3:02 left'), findsOneWidget);
  });

  testWidgets('countdown_end_disables_buttons_and_reloads', (tester) async {
    final repo = _FakeRepo();
    final rig = await _open(tester, repo: repo);
    final calls = repo.cursors.length;
    rig.deviceNow = rig.deviceNow.add(const Duration(minutes: 4));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('0:00 left'), findsOneWidget);
    await tester.tap(_key('request_accept_$_ringingId'));
    await tester.pump();
    expect(repo.accepted, isEmpty);
    expect(repo.cursors.length, calls + 1);
  });

  testWidgets('accept_and_decline_call_controller', (tester) async {
    final repo = _FakeRepo();
    await _open(tester, repo: repo);
    await tester.tap(_key('request_accept_$_ringingId'));
    await tester.pump();
    await tester.pump();
    expect(repo.accepted, [_ringingId]);
    await tester.tap(_key('request_decline_$_ringingId'));
    await tester.pump();
    await tester.pump();
    expect(repo.declined, [_ringingId]);
  });

  testWidgets('accept_missed_shows_notice', (tester) async {
    final repo = _FakeRepo()..acceptResult = const TaxiOfferMissed<DriverOffer>();
    await _open(tester, repo: repo);
    await tester.tap(_key('request_accept_$_ringingId'));
    await tester.pump();
    await tester.pump();
    expect(find.text('This request went to the next drivers.'), findsOneWidget);
  });

  testWidgets('empty_state', (tester) async {
    final repo = _FakeRepo()
      ..listJson = () => {..._json('driver_offer_list.json'), 'items': <dynamic>[], 'counts': {'new': 0, 'booked': 0}};
    await _open(tester, repo: repo);
    expect(_key('requests_empty'), findsOneWidget);
    expect(find.text('No requests yet'), findsOneWidget);
  });

  testWidgets('empty_then_refresh_fails_shows_banner', (tester) async {
    final repo = _FakeRepo()
      ..listJson = () => {..._json('driver_offer_list.json'), 'items': <dynamic>[], 'counts': {'new': 0, 'booked': 0}};
    final rig = await _open(tester, repo: repo);
    expect(_key('requests_refresh_failed'), findsNothing);
    repo.listResult = const TaxiOffline<DriverOfferList>();
    await rig.controller.load();
    await tester.pump();
    expect(_key('requests_refresh_failed'), findsOneWidget);
    expect(_key('requests_empty'), findsOneWidget);
  });

  testWidgets('error_state_retries', (tester) async {
    final repo = _FakeRepo()..listResult = const TaxiOffline<DriverOfferList>();
    await _open(tester, repo: repo);
    expect(_key('requests_error'), findsOneWidget);
    repo.listResult = null;
    await tester.tap(_key('requests_retry'));
    await tester.pump();
    await tester.pump();
    expect(_key('requests_error'), findsNothing);
    expect(_key('requests_group_new'), findsOneWidget);
  });

  testWidgets('paused_state', (tester) async {
    final repo = _FakeRepo()..listResult = const TaxiPaused<DriverOfferList>();
    await _open(tester, repo: repo);
    expect(_key('requests_paused'), findsOneWidget);
    expect(find.text('Requests are paused right now'), findsOneWidget);
  });

  testWidgets('paused_banner_over_loaded_list', (tester) async {
    final repo = _FakeRepo();
    final rig = await _open(tester, repo: repo);
    repo.listResult = const TaxiPaused<DriverOfferList>();
    await rig.controller.load();
    await tester.pump();
    expect(_key('requests_paused_banner'), findsOneWidget);
    expect(_key('requests_group_new'), findsOneWidget);
  });

  testWidgets('show_more_pages_earlier', (tester) async {
    final repo = _FakeRepo()..listJson = () => {..._json('driver_offer_list.json'), 'nextCursor': 'c2'};
    await _open(tester, repo: repo);
    await tester.scrollUntilVisible(_key('requests_more'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(_key('requests_more'));
    await tester.pump();
    await tester.pump();
    expect(repo.cursors.last, 'c2');
  });

  group('five sizes', () {
    testFiveSizes('requests list', () => _Rig().screen(), check: (tester, size) async {
      await tester.pump();
      await tester.pump();
      expect(_key('requests_group_new'), findsOneWidget, reason: sizeLabel(size));
    });

    testFiveSizes('every state list', () => _Rig(repo: _FakeRepo()..listJson = _allStates).screen(), check: (tester, size) async {
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('request_card_$_acceptedId')), findsOneWidget, reason: sizeLabel(size));
      await tester.scrollUntilVisible(find.byKey(const ValueKey('request_card_$_endedId')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const ValueKey('request_card_$_endedId')), findsOneWidget, reason: sizeLabel(size));
    });

    for (final size in fiveSizes) {
      testWidgets('empty error paused at ${sizeLabel(size)}', (tester) async {
        for (final result in <TaxiResult<DriverOfferList>>[
          const TaxiOffline<DriverOfferList>(),
          const TaxiPaused<DriverOfferList>(),
        ]) {
          await _open(tester, repo: _FakeRepo()..listResult = result, size: size);
          expect(tester.takeException(), isNull, reason: sizeLabel(size));
        }
        await _open(
          tester,
          repo: _FakeRepo()..listJson = () => {..._json('driver_offer_list.json'), 'items': <dynamic>[]},
          size: size,
        );
        expect(tester.takeException(), isNull, reason: sizeLabel(size));
      });
    }
  });
}
