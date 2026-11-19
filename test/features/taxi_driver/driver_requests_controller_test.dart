import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:bakhli/features/taxi/requests/controllers/driver_bookings_controller.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_rating_controller.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_requests_controller.dart';
import 'package:bakhli/features/taxi/requests/data/driver_request_repository.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/services/taxi_ring_service.dart';

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('test/features/taxi_request/samples/$name').readAsStringSync()) as Map<String, dynamic>;

const _ringingId = 'a1b2c3d4-0001-4a00-8000-000000000001';

class _FakeRepo extends DriverRequestRepository {
  _FakeRepo();

  int offersCalls = 0;
  final Map<String, String> listStates = {};
  bool listOffline = false;
  TaxiResult<DriverOffer>? acceptResult;
  TaxiResult<DriverOffer>? declineResult;
  int offerCalls = 0;
  TaxiResult<DriverOffer>? confirmResult;
  TaxiResult<DriverOffer>? withdrawResult;
  TaxiResult<DriverBookings>? bookingsResult;
  TaxiResult<DriverRating>? ratingResult;
  final List<ReasonChip> withdrawChips = [];

  @override
  Future<TaxiResult<DriverOfferList>> offers({String? cursor}) async {
    offersCalls++;
    if (listOffline) return const TaxiOffline();
    final j = _json('driver_offer_list.json');
    j['items'] = [
      for (final i in j['items'] as List)
        {...i as Map<String, dynamic>, if (listStates[i['offerId']] != null) 'state': listStates[i['offerId']]},
    ];
    return TaxiOk(DriverOfferList.fromJson(j));
  }

  Map<String, dynamic> detailPatch = {};

  @override
  Future<TaxiResult<DriverOffer>> offer(String offerId) async {
    offerCalls++;
    return TaxiOk(DriverOffer.fromJson({..._json('driver_offer_detail_ringing.json'), ...detailPatch}));
  }

  @override
  Future<TaxiResult<DriverOffer>> accept(String offerId) async => acceptResult!;

  @override
  Future<TaxiResult<DriverOffer>> decline(String offerId, {ReasonChip? chip}) async => declineResult!;

  @override
  Future<TaxiResult<DriverOffer>> confirm(String offerId) async => confirmResult!;

  @override
  Future<TaxiResult<DriverOffer>> withdraw(String offerId, ReasonChip chip) async {
    withdrawChips.add(chip);
    return withdrawResult!;
  }

  @override
  Future<TaxiResult<DriverBookings>> bookings(DateTime from, DateTime to) async => bookingsResult!;

  @override
  Future<TaxiResult<DriverRating>> rating() async => ratingResult!;
}

class _FakeRing implements TaxiRingNotifier {
  final List<(int, String)> cancelled = [];

  @override
  Future<void> show(int id, String title, String body, NotificationDetails details, String? payload) async {}

  @override
  Future<void> cancel(int id, String tag) async => cancelled.add((id, tag));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo repo;
  late DriverRequestsController c;
  final deviceNow = DateTime.utc(2026, 12, 10, 9, 40);

  setUp(() {
    repo = _FakeRepo();
    c = DriverRequestsController(repo: repo, now: () => deviceNow);
  });

  test('load_uses_server_buckets_offset_and_badge', () async {
    final r = await c.load();
    expect(r, isA<TaxiOk<DriverOfferList>>());
    expect(c.badge, 1);
    expect(c.clockOffset.value, const Duration(minutes: 3));
    expect(c.inBucket(OfferBucket.newOffers).single.offerId, _ringingId);
    expect(c.inBucket(OfferBucket.booked), hasLength(1));
    final ringing = c.offer(_ringingId)!;
    expect(c.countdownText(ringing), '3:07');
  });

  test('accept_success_unlocks_the_traveller', () async {
    await c.load();
    expect(c.offer(_ringingId)!.traveller, isNull);
    final accepted = DriverOffer.fromJson({
      ..._json('driver_offer_detail_ringing.json'),
      'state': 'Accepted',
      'traveller': {'name': 'Aarav Sharma', 'phone': '+919876543210'},
    });
    repo.acceptResult = TaxiOk(accepted);
    repo.listStates[_ringingId] = 'Accepted';
    final r = await c.accept(_ringingId);
    await pumpEventQueue();
    expect(r, isA<TaxiOk<DriverOffer>>());
    final o = c.offer(_ringingId)!;
    expect(o.state, OfferState.accepted);
    expect(o.traveller!.phone, '+919876543210');
    expect(c.isBusy(DriverRequestAction.accept, _ringingId), isFalse);
    expect(c.hasFailed(DriverRequestAction.accept, _ringingId), isFalse);
  });

  test('accept_missed_marks_the_row', () async {
    await c.load();
    repo.listOffline = true;
    repo.acceptResult = const TaxiOfferMissed<DriverOffer>(state: 'Missed');
    final r = await c.accept(_ringingId);
    await pumpEventQueue();
    expect(r, isA<TaxiOfferMissed<DriverOffer>>());
    expect(repo.offersCalls, 2);
    expect(c.items.firstWhere((o) => o.offerId == _ringingId).state, OfferState.missed);
    expect(c.hasFailed(DriverRequestAction.accept, _ringingId), isTrue);
  });

  test('confirm_conflict_is_kept_for_the_screen', () async {
    await c.load();
    await c.loadOffer(_ringingId);
    repo.confirmResult = const TaxiDatesAlreadyBooked<DriverOffer>(from: '2026-12-20', to: '2026-12-24');
    final r = await c.confirm(_ringingId);
    expect(r, isA<TaxiDatesAlreadyBooked<DriverOffer>>());
    final conflict = c.conflictFor(_ringingId)!;
    expect(conflict.from, '2026-12-20');
    expect(conflict.to, '2026-12-24');
    await c.load();
    expect(c.conflictFor(_ringingId)!.to, '2026-12-24');
  });

  test('confirm_conflict_clears_when_fresh_detail_has_none', () async {
    await c.load();
    await c.loadOffer(_ringingId);
    repo.confirmResult = const TaxiDatesAlreadyBooked<DriverOffer>(from: '2026-12-20', to: '2026-12-24');
    await c.confirm(_ringingId);
    expect(c.conflictFor(_ringingId), isNotNull);
    repo.detailPatch = {'state': 'Selected', 'datesConflict': null};
    await c.loadOffer(_ringingId);
    expect(c.offer(_ringingId)!.state, OfferState.selected);
    expect(c.conflictFor(_ringingId), isNull);
  });

  test('fresh_detail_conflict_replaces_the_stored_one', () async {
    await c.load();
    repo.detailPatch = {
      'state': 'Selected',
      'datesConflict': {'from': '2026-12-21', 'to': '2026-12-22'},
    };
    await c.loadOffer(_ringingId);
    expect(c.conflictFor(_ringingId)!.from, '2026-12-21');
  });

  test('push_and_resume_refresh_once', () async {
    c.onPush();
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    c.onPush();
    await pumpEventQueue();
    expect(repo.offersCalls, 1);
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    await pumpEventQueue();
    expect(repo.offersCalls, 1);
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(repo.offersCalls, 2);
  });

  test('pull_refresh_during_load_runs_one_follow_up', () async {
    final first = c.reloadList();
    final second = c.reloadList();
    final third = c.reloadList();
    await Future.wait([first, second, third]);
    expect(repo.offersCalls, 2);
  });

  test('withdraw_returns_the_typed_result', () async {
    await c.load();
    repo.withdrawResult = const TaxiStateInvalid<DriverOffer>(state: 'Closed');
    final r = await c.withdraw(_ringingId, ReasonChip.values.first);
    expect(r, isA<TaxiStateInvalid<DriverOffer>>());
    expect(repo.withdrawChips, [ReasonChip.values.first]);
  });

  test('bookings_withdraw_and_rating_return_typed_results', () async {
    var changed = 0;
    final b = DriverBookingsController(repo: repo, now: () => DateTime(2026, 12, 10), onChanged: () => changed++);
    repo.bookingsResult = TaxiOk(DriverBookings.fromJson(_json('driver_bookings.json')));
    expect(await b.reload(), isA<TaxiOk<DriverBookings>>());
    final booking = b.bookings.value!.items.first;
    repo.withdrawResult = TaxiOk(DriverOffer.fromJson(_json('driver_offer_detail_ringing.json')));
    expect(await b.withdraw(booking, ReasonChip.values.first), isA<TaxiOk<DriverOffer>>());
    expect(changed, 1);

    final rating = DriverRatingController(repo: repo);
    repo.ratingResult = const TaxiOffline<DriverRating>();
    expect(await rating.load(), isA<TaxiOffline<DriverRating>>());
    expect(rating.failed.value, isTrue);
  });

  group('ring stops once the driver answers in the app', () {
    late _FakeRing ring;
    setUp(() {
      ring = _FakeRing();
      c = DriverRequestsController(repo: repo, now: () => deviceNow, ring: ring);
    });

    DriverOffer accepted() => DriverOffer.fromJson({..._json('driver_offer_detail_ringing.json'), 'state': 'Accepted'});
    final cases = <String, TaxiResult<DriverOffer> Function()>{
      'ok': () => TaxiOk(accepted()),
      'missed': () => const TaxiOfferMissed<DriverOffer>(state: 'Missed'),
      'state_invalid': () => const TaxiStateInvalid<DriverOffer>(state: 'Closed'),
    };
    for (final e in cases.entries) {
      test('accept ${e.key}', () async {
        repo.acceptResult = e.value();
        await c.accept(_ringingId);
        expect(ring.cancelled, [(TaxiRingNotification.id, 'taxi_ring_$_ringingId')]);
      });
      test('decline ${e.key}', () async {
        repo.declineResult = e.value();
        await c.decline(_ringingId);
        expect(ring.cancelled, [(TaxiRingNotification.id, 'taxi_ring_$_ringingId')]);
      });
    }

    test('offline keeps ringing', () async {
      repo.acceptResult = const TaxiOffline<DriverOffer>();
      await c.accept(_ringingId);
      expect(ring.cancelled, isEmpty);
    });

    test('confirm and withdraw do not touch the ring', () async {
      repo.confirmResult = TaxiOk(accepted());
      repo.withdrawResult = TaxiOk(accepted());
      await c.confirm(_ringingId);
      await c.withdraw(_ringingId, ReasonChip.changedPlan);
      expect(ring.cancelled, isEmpty);
    });
  });

  test('offer_state_invalid_refreshes_the_offer_and_list', () async {
    await c.load();
    final before = repo.offersCalls;
    repo.acceptResult = DriverRequestRepository.mapError<DriverOffer>(_dioError(409, 'OfferStateInvalid', {'state': 'Closed'}));
    expect(repo.acceptResult, isA<TaxiStateInvalid<DriverOffer>>());
    await c.accept(_ringingId);
    await pumpEventQueue();
    expect(repo.offersCalls, before + 1);
    expect(repo.offerCalls, 1);
  });

  test('no_shared_last_error_fields', () {
    for (final name in [
      'driver_requests_controller.dart',
      'driver_bookings_controller.dart',
      'driver_rating_controller.dart',
      'driver_ready_controller.dart',
    ]) {
      final src = File('lib/features/taxi/requests/controllers/$name').readAsStringSync();
      expect(src.contains('lastError'), isFalse, reason: name);
      expect(src.toLowerCase().contains('errormessage'), isFalse, reason: name);
      expect(src.contains('RxnString'), isFalse, reason: name);
      expect(src.contains('RxString'), isFalse, reason: name);
      expect(RegExp(r'catch \(_\)').hasMatch(src), isFalse, reason: name);
      expect(RegExp(r'catch \(\w+\)\s*\{\s*\}').hasMatch(src), isFalse, reason: name);
    }
  });

  tearDown(Get.reset);
}

DioException _dioError(int status, String type, Map<String, dynamic> data) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: {
      'data': data,
      'error': {'type': type, 'message': 'This request has changed. Please check again.'},
    }),
  );
}
