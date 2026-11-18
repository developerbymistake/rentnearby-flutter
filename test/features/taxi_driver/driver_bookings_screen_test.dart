import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_bookings_controller.dart';
import 'package:bakhli/features/taxi/requests/data/driver_request_repository.dart';
import 'package:bakhli/features/taxi/requests/driver_bookings_screen.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('test/features/taxi_request/samples/$name').readAsStringSync()) as Map<String, dynamic>;

const _bookedId = 'b00c1e55-0001-4b00-8000-000000000001';
const _doneId = 'b00c1e55-0007-4b00-8000-000000000007';

class _FakeRepo extends DriverRequestRepository {
  _FakeRepo({this.patch});

  final void Function(Map<String, dynamic> json)? patch;
  final List<(DateTime, DateTime)> loads = [];
  final List<ReasonChip> withdrawChips = [];
  final List<String> ended = [];
  final Set<int> failMonths = {};
  Completer<void>? gate;

  @override
  Future<TaxiResult<DriverBookings>> bookings(DateTime from, DateTime to) async {
    loads.add((from, to));
    final g = gate;
    if (g != null) await g.future;
    if (failMonths.contains(from.month)) return const TaxiOffline();
    final j = _json('driver_bookings.json');
    patch?.call(j);
    return TaxiOk(DriverBookings.fromJson(j));
  }

  @override
  Future<TaxiResult<DriverOffer>> withdraw(String offerId, ReasonChip chip) async {
    withdrawChips.add(chip);
    return TaxiOk(DriverOffer.fromJson(_json('driver_offer_detail_ringing.json')));
  }

  @override
  Future<TaxiResult<DriverBooking>> endBooking(String bookingId) async {
    ended.add(bookingId);
    return TaxiOk(DriverBooking.fromJson((_json('driver_bookings.json')['items'] as List).first as Map<String, dynamic>));
  }
}

DriverBookingsController _controller(_FakeRepo repo) =>
    DriverBookingsController(repo: repo, now: () => DateTime(2026, 12, 10), onChanged: () {});

Widget _screen(DriverBookingsController c, {List<String>? calls}) =>
    DriverBookingsScreen(controller: c, onCall: (p) => calls?.add(p));

Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void _inProgress(Map<String, dynamic> j) {
  final first = (j['items'] as List).first as Map<String, dynamic>;
  first
    ..['state'] = 'InProgress'
    ..['canWithdraw'] = false
    ..['canEnd'] = true;
}

void main() {
  tearDown(Get.reset);

  testWidgets('sample_renders_marks_and_rows', (tester) async {
    final c = _controller(_FakeRepo());
    await pumpPhone(tester, _screen(c));
    await tester.pumpAndSettle();

    expect(find.text('My bookings'), findsOneWidget);
    expect(find.text('December'), findsOneWidget);
    expect(find.text('December 2026'), findsOneWidget);
    for (var d = 18; d <= 21; d++) {
      expect(find.byKey(ValueKey('cal_taken_$d')), findsOneWidget, reason: 'day $d');
    }
    for (final d in [1, 17, 22, 31]) {
      expect(find.byKey(ValueKey('cal_free_$d')), findsOneWidget, reason: 'day $d');
    }
    expect(find.byKey(const ValueKey('cal_taken_22')), findsNothing);
    expect(find.text('18 Dec to 21 Dec'), findsOneWidget);
    expect(find.text('Kathgodam pickup · Aarav Sharma'), findsOneWidget);
    expect(find.text('2 Nov to 6 Nov'), findsOneWidget);
    expect(find.text('Kathgodam pickup · Neha Verma'), findsOneWidget);
    expect(find.text('Occupied'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking_withdraw_$_bookedId')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking_call_$_bookedId')), findsOneWidget);
  });

  testWidgets('month change loads', (tester) async {
    final repo = _FakeRepo();
    final c = _controller(repo);
    await pumpPhone(tester, _screen(c));
    await tester.pumpAndSettle();
    expect(repo.loads, hasLength(1));

    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pumpAndSettle();
    expect(repo.loads, hasLength(2));
    expect(repo.loads.last.$1, DateTime(2027, 1, 1));
    expect(repo.loads.last.$2, DateTime(2027, 1, 31));
    expect(find.text('January 2027'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Previous month'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Previous month'));
    await tester.pumpAndSettle();
    expect(repo.loads.last.$1, DateTime(2026, 11, 1));
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('November'), findsOneWidget);
  });

  testWidgets('month change clears old rows, failed load shows retry', (tester) async {
    final repo = _FakeRepo();
    final c = _controller(repo);
    await pumpPhone(tester, _screen(c));
    await tester.pumpAndSettle();
    expect(find.text('18 Dec to 21 Dec'), findsOneWidget);

    repo
      ..failMonths.add(1)
      ..gate = Completer<void>();
    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pump();
    expect(find.text('January 2027'), findsOneWidget);
    expect(find.text('18 Dec to 21 Dec'), findsNothing);
    expect(find.text('2 Nov to 6 Nov'), findsNothing);
    expect(find.byType(SkeletonBox), findsWidgets);

    repo.gate!.complete();
    repo.gate = null;
    await tester.pumpAndSettle();
    expect(find.text('January 2027'), findsOneWidget);
    expect(find.byKey(const ValueKey('driver_bookings_error')), findsOneWidget);
    expect(find.text('Could not load bookings'), findsOneWidget);
    expect(find.text('18 Dec to 21 Dec'), findsNothing);
    expect(find.byKey(const ValueKey('cal_taken_18')), findsNothing);

    repo.failMonths.clear();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(repo.loads.last.$1, DateTime(2027, 1, 1));
    expect(find.byKey(const ValueKey('driver_bookings_error')), findsNothing);
    expect(find.text('18 Dec to 21 Dec'), findsOneWidget);
  });

  testWidgets('failed reload shows retry even with older rows', (tester) async {
    final repo = _FakeRepo();
    final c = _controller(repo);
    await pumpPhone(tester, _screen(c));
    await tester.pumpAndSettle();
    repo.failMonths.add(12);
    await c.reload();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('driver_bookings_error')), findsOneWidget);
    expect(find.text('18 Dec to 21 Dec'), findsNothing);
  });

  testWidgets('withdraw_needs_chip_and_calls_controller', (tester) async {
    final repo = _FakeRepo();
    final c = _controller(repo);
    await pumpPhone(tester, _screen(c));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('booking_withdraw_$_bookedId')));
    await tester.pumpAndSettle();
    expect(find.text('Withdraw from booking'), findsOneWidget);
    for (final t in ['Changed plan', 'Not reachable', 'Price not agreed', 'Vehicle issue', 'Other']) {
      expect(find.text(t), findsOneWidget);
    }
    final confirm = find.byKey(const ValueKey('driver_withdraw_confirm'));
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(repo.withdrawChips, isEmpty);
    expect(find.text('Withdraw from booking'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('driver_reason_VehicleIssue')));
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(repo.withdrawChips, [ReasonChip.vehicleIssue]);
    expect(find.text('Withdraw from booking'), findsNothing);
    await _drainToast(tester);
    expect(repo.loads, hasLength(2));
  });

  testWidgets('End trip only in progress', (tester) async {
    await pumpPhone(tester, _screen(_controller(_FakeRepo())));
    await tester.pumpAndSettle();
    expect(find.text('End trip'), findsNothing);
    expect(find.text('Withdraw'), findsOneWidget);

    final repo = _FakeRepo(patch: _inProgress);
    await pumpAtSize(tester, _screen(_controller(repo)), phoneSize);
    await tester.pumpAndSettle();
    expect(find.text('End trip'), findsOneWidget);
    expect(find.text('Withdraw'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('booking_end_$_bookedId')));
    await tester.pumpAndSettle();
    expect(repo.ended, [_bookedId]);
    await _drainToast(tester);
  });

  testWidgets('number hidden when completed', (tester) async {
    final calls = <String>[];
    final repo = _FakeRepo(patch: (j) {
      final done = (j['items'] as List).firstWhere((e) => (e as Map)['bookingId'] == _doneId) as Map<String, dynamic>;
      done['travellerPhone'] = '+919811122233';
    });
    await pumpPhone(tester, _screen(_controller(repo), calls: calls));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking_call_$_doneId')), findsNothing);
    expect(find.byKey(const ValueKey('booking_withdraw_$_doneId')), findsNothing);
    expect(find.textContaining('9811'), findsNothing);
    expect(find.textContaining('9876'), findsNothing);
    expect(find.text('Call'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('booking_call_$_bookedId')));
    expect(calls, ['+919876543210']);
  });

  testFiveSizes('five sizes', () => _screen(_controller(_FakeRepo())), check: (tester, size) async {
    await tester.pumpAndSettle();
    expect(find.text('18 Dec to 21 Dec'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('booking_withdraw_$_bookedId')));
    await tester.tap(find.byKey(const ValueKey('booking_withdraw_$_bookedId')));
    await tester.pumpAndSettle();
    expect(find.text('Confirm withdraw'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
