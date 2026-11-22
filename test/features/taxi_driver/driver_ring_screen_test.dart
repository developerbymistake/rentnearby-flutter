import 'dart:convert';
import 'dart:io';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_requests_controller.dart';
import 'package:bakhli/features/taxi/requests/data/driver_request_repository.dart';
import 'package:bakhli/features/taxi/requests/driver_ring_screen.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('test/features/taxi_request/samples/$name').readAsStringSync()) as Map<String, dynamic>;

const _id = 'a1b2c3d4-0001-4a00-8000-000000000001';

class _FakeRepo extends DriverRequestRepository {
  Map<String, dynamic> detailPatch = {};
  bool listFail = false;
  bool detailFail = false;
  TaxiResult<DriverOffer>? acceptResult;
  TaxiResult<DriverOffer>? declineResult;
  final List<String> calls = [];

  @override
  Future<TaxiResult<DriverOfferList>> offers({String? cursor}) async =>
      listFail ? const TaxiFailed(message: 'down') : TaxiOk(DriverOfferList.fromJson(_json('driver_offer_list.json')));

  @override
  Future<TaxiResult<DriverOffer>> offer(String offerId) async => detailFail
      ? const TaxiFailed(message: 'down')
      : TaxiOk(DriverOffer.fromJson({..._json('driver_offer_detail_ringing.json'), ...detailPatch}));

  @override
  Future<TaxiResult<DriverOffer>> accept(String offerId) async {
    calls.add('accept');
    return acceptResult!;
  }

  @override
  Future<TaxiResult<DriverOffer>> decline(String offerId, {ReasonChip? chip}) async {
    calls.add('decline');
    return declineResult!;
  }
}

class _Harness {
  _Harness() {
    controller = DriverRequestsController(repo: repo, now: () => now);
  }

  final repo = _FakeRepo();
  DateTime now = DateTime.utc(2026, 12, 10, 9, 40);
  late final DriverRequestsController controller;
  final opened = <String>[];
  int closed = 0;

  Widget screen({DriverRingAction? action}) => DriverRingScreen(
        offerId: _id,
        action: action,
        controller: controller,
        onAccepted: opened.add,
        onClose: () => closed++,
      );
}

DriverOffer _offer(String state) => DriverOffer.fromJson({..._json('driver_offer_detail_ringing.json'), 'state': state});

Future<_Harness> _open(
  WidgetTester tester, {
  DriverRingAction? action,
  Map<String, dynamic> patch = const {},
  Size size = phoneSize,
  bool fail = false,
}) async {
  final h = _Harness()
    ..repo.detailPatch = patch
    ..repo.listFail = fail
    ..repo.detailFail = fail;
  h.repo.acceptResult = TaxiOk(_offer('Accepted'));
  h.repo.declineResult = TaxiOk(_offer('Declined'));
  await pumpAtSize(tester, h.screen(action: action), size);
  await tester.pump();
  await tester.pump();
  return h;
}

void main() {
  setUp(Get.reset);

  testWidgets('fields_and_countdown', (tester) async {
    final h = await _open(tester);
    expect(find.text('INCOMING REQUEST'), findsOneWidget);
    expect(find.text('New taxi request'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Sightseeing 3 days'), findsOneWidget);
    expect(find.text('Drop'), findsOneWidget);
    expect(find.text('4 days · 3 nights · 18 to 21 Dec'), findsOneWidget);
    expect(find.text('Kathgodam to Nainital, Ranikhet'), findsOneWidget);
    expect(find.text('4 seater · 2 travellers'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Swipe up to answer'), findsOneWidget);
    expect(find.text('3:07'), findsOneWidget);
    h.now = h.now.add(const Duration(seconds: 7));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('3:00'), findsOneWidget);
  });

  testWidgets('accept_and_decline_call_controller', (tester) async {
    final h = await _open(tester);
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump();
    expect(h.repo.calls, ['accept']);
    expect(h.opened, [_id]);

    final d = await _open(tester);
    await tester.tap(find.text('Decline'));
    await tester.pump();
    await tester.pump();
    expect(d.repo.calls, ['decline']);
    expect(d.closed, 1);
    expect(d.opened, isEmpty);
  });

  testWidgets('missed path: accept answered OfferMissed', (tester) async {
    final h = await _open(tester);
    h.repo.acceptResult = const TaxiOfferMissed<DriverOffer>();
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Missed'), findsOneWidget);
    expect(find.text('Went to the next drivers.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    expect(h.closed, 1);
    expect(h.opened, isEmpty);
  });

  testWidgets('missed path: countdown reaches zero', (tester) async {
    final h = await _open(tester);
    h.now = h.now.add(const Duration(minutes: 4));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Missed'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump();
    expect(h.closed, 1);
  });

  testWidgets('missed path: offer already missed on open', (tester) async {
    final h = await _open(tester, patch: {'state': 'Missed'});
    expect(find.text('Missed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(h.closed, 1);
  });

  testWidgets('action argument accept runs at once', (tester) async {
    final h = await _open(tester, action: DriverRingAction.accept);
    await tester.pump();
    expect(h.repo.calls, ['accept']);
    expect(h.opened, [_id]);
  });

  testWidgets('action argument decline runs at once', (tester) async {
    final h = await _open(tester, action: DriverRingAction.decline);
    await tester.pump();
    expect(h.repo.calls, ['decline']);
    expect(h.closed, 1);
  });

  test('action argument is parsed from route arguments', () {
    expect(DriverRingScreen.fromArguments({'offerId': _id, 'action': 'accept'}).action, DriverRingAction.accept);
    expect(DriverRingScreen.fromArguments({'offerId': _id, 'action': 'decline'}).action, DriverRingAction.decline);
    expect(DriverRingScreen.fromArguments({'offerId': _id}).action, isNull);
    expect(DriverRingScreen.fromArguments(null).offerId, '');
  });

  testWidgets('ring look matches frame 41: progress arc, taxi art, X decline', (tester) async {
    await _open(tester);
    final paint = tester.widget<CustomPaint>(find.byKey(const ValueKey('ring_progress')));
    expect((paint.painter as dynamic).progress, closeTo(187 / 300, 0.01));
    expect(find.byWidgetPredicate((w) => w is Art3D && w.asset.endsWith('travel3d/taxi.png')), findsOneWidget);
    expect(find.byKey(const ValueKey('ring_decline_x')), findsOneWidget);
    expect(find.byIcon(Icons.call), findsOneWidget);
    expect(find.byIcon(Icons.call_end_rounded), findsNothing);
    expect((paint.painter as dynamic).radius, DS.s(92));
  });

  testWidgets('answered after a failed accept opens the detail, not stuck on loading', (tester) async {
    final h = await _open(tester);
    h.repo.acceptResult = const TaxiStateInvalid<DriverOffer>();
    h.repo.detailPatch = {'state': 'Accepted'};
    await tester.tap(find.text('Accept'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(h.opened, [_id]);
  });

  testWidgets('FT-12: a tick repaints the arc and the countdown only, the page and the art are not rebuilt', (tester) async {
    final h = await _open(tester);
    final rebuilt = <String>[];
    final prev = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (e, _) => rebuilt.add(e.widget.runtimeType.toString());
    addTearDown(() => debugOnRebuildDirtyWidget = prev);
    for (var i = 0; i < 3; i++) {
      h.now = h.now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    debugOnRebuildDirtyWidget = prev;
    expect(find.text('3:04'), findsOneWidget);
    expect(rebuilt.where((n) => n == 'DriverRingScreen' || n == 'Art3D' || n == 'Wrap' || n == '_Chip' || n == '_Round'), isEmpty, reason: rebuilt.toSet().join(', '));
    expect(rebuilt.where((n) => n.startsWith('ValueListenableBuilder')).length, 3);
    final paint = tester.widget<CustomPaint>(find.byKey(const ValueKey('ring_progress')));
    expect((paint.painter as dynamic).progress, closeTo(184 / 300, 0.01));
  });

  testWidgets('load failed shows retry and retry loads the ring', (tester) async {
    final h = await _open(tester, fail: true);
    expect(find.text('Could not open the request'), findsOneWidget);
    expect(find.text('Check your internet and try again.'), findsOneWidget);
    h.repo
      ..listFail = false
      ..detailFail = false;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('New taxi request'), findsOneWidget);
  });

  testWidgets('action failed and paused messages', (tester) async {
    final h = await _open(tester);
    h.repo.acceptResult = const TaxiFailed<DriverOffer>(message: 'down');
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Could not send your answer. Try again.'), findsOneWidget);
    h.repo.acceptResult = const TaxiPaused<DriverOffer>();
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Taxi requests are paused for now'), findsOneWidget);
    expect(h.opened, isEmpty);
  });

  for (final size in fiveSizes) {
    testWidgets('five sizes load failed and action failed at ${sizeLabel(size)}', (tester) async {
      await _open(tester, size: size, fail: true);
      expect(find.text('Could not open the request'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final h = await _open(tester, size: size);
      h.repo.acceptResult = const TaxiPaused<DriverOffer>();
      await tester.tap(find.text('Accept'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Taxi requests are paused for now'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in fiveSizes) {
    testWidgets('five sizes ring and missed at ${sizeLabel(size)}', (tester) async {
      await _open(tester, size: size);
      expect(find.text('3:07'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final hint = tester.getRect(find.text('Swipe up to answer'));
      expect(hint.bottom, lessThanOrEqualTo(size.height));
      expect(tester.getRect(find.text('Accept')).bottom, lessThan(hint.top));
      expect(tester.getRect(find.byKey(const ValueKey('ring_countdown'))).bottom, lessThan(tester.getRect(find.text('Accept')).top));
      final h = await _open(tester, size: size, patch: {'state': 'Missed'});
      expect(find.text('Missed'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      expect(h.closed, 1);
    });
  }
}
