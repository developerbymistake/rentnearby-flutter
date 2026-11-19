import 'package:bakhli/features/trip/controllers/trip_taxi_request_controller.dart';
import 'package:bakhli/features/trip/models/taxi_request_models.dart';
import 'package:bakhli/features/trip/screens/trip_taxi_request_status_screen.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';
import 'taxi_request_controller_fakes.dart';

const _ramesh = 'a1b2c3d4-0001-4a00-8000-000000000001';
const _mohan = 'a1b2c3d4-0002-4a00-8000-000000000002';
const _unavailable = 'This driver is no longer available. Choose another driver.';
const _didNotConfirm = 'This driver did not confirm. Choose another driver.';

TripTaxiRequestController _controller(FakeTaxiRepo repo, DateTime Function() now) => TripTaxiRequestController(
      repo: repo,
      enquiries: FakeEnquiries(),
      realtime: null,
      refreshPlan: (_) async => true,
      onLegacyClosed: () {},
      now: now,
    );

TaxiRequest _selected() => sampleRequest('taxi_request_selected.json');

TaxiRequest _lapsed({String? updatedAt}) {
  final base = sampleJson('taxi_request_collecting.json');
  final mohan = [
    for (final d in base['drivers'] as List)
      if ((d as Map)['offerId'] == _mohan) d,
  ];
  return TaxiRequest.fromJson({...base, 'version': 9, 'drivers': mohan, 'updatedAt': ?updatedAt});
}

TaxiRequest _lapsedNoBackup({String? updatedAt}) => TaxiRequest.fromJson({
      ...sampleJson('taxi_request_collecting.json'),
      'state': 'Open',
      'view': 'Finding',
      'version': 9,
      'drivers': <Object>[],
      'updatedAt': ?updatedAt,
    });

TaxiRequest _leftDuringTrip({bool canRate = true, Object? rating, int version = 20}) {
  final base = sampleJson('taxi_request_in_progress.json');
  return TaxiRequest.fromJson({
    ...base,
    'state': 'Cancelled',
    'view': 'Ended',
    'endReason': 'DriverLeftTrip',
    'version': version,
    'canCancel': false,
    'rating': rating,
    'booking': {
      ...(base['booking'] as Map<String, dynamic>),
      'state': 'Cancelled',
      'canCancel': false,
      'canEnd': false,
      'canRate': canRate,
      'leftDuringTrip': true,
    },
  });
}

Future<TripTaxiRequestController> _open(WidgetTester tester, FakeTaxiRepo repo, TaxiRequest first, DateTime now,
    {Size size = phoneSize}) async {
  repo.getAnswer = (_) => TaxiOk(first);
  final c = _controller(repo, () => now);
  await pumpAtSize(
    tester,
    TripTaxiRequestStatusScreen(requestId: first.id, controller: c, onDone: () {}, onCall: (_) async {}, onBack: () {}),
    size,
  );
  await tester.pump();
  await tester.pump();
  return c;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  expect(f, findsOneWidget, reason: key);
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump();
}

Future<void> _refresh(WidgetTester tester, TripTaxiRequestController c) async {
  await c.refreshRequest();
  await tester.pump();
  await tester.pump();
}

DioException _tooMany({String? retryAfter}) {
  final options = RequestOptions(path: '/taxi-requests/x');
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: 429,
      headers: Headers.fromMap({if (retryAfter != null) 'retry-after': [retryAfter]}),
      data: {'error': {'type': 'TooManyRequests', 'message': 'Too many requests'}},
    ),
    type: DioExceptionType.badResponse,
  );
}

class _LimitedTripRead extends FakeTaxiRepo {
  @override
  Future<TaxiResult<TaxiRequest?>> forTrip(String tripId) async =>
      const TaxiRefused<TaxiRequest?>(type: 'TooManyRequests', statusCode: 429, retryAfterSeconds: 20);
}

void main() {
  tearDown(Get.reset);

  group('lapse at once (O8)', () {
    final early = DateTime.utc(2026, 12, 10, 9, 50);

    testWidgets('back to collecting with the other drivers and the unavailable line', (tester) async {
      final repo = FakeTaxiRepo();
      final c = await _open(tester, repo, _selected(), early);
      expect(find.text('Waiting for Ramesh Kumar to confirm'), findsOneWidget);
      expect(find.byKey(const ValueKey('status_lapse_line')), findsNothing);
      repo.getAnswer = (_) => TaxiOk(_lapsed());
      await _refresh(tester, c);
      expect(find.byKey(const ValueKey('status_lapse_line')), findsOneWidget);
      expect(find.text(_unavailable), findsOneWidget);
      expect(find.text('Waiting for Ramesh Kumar to confirm'), findsNothing);
      expect(find.byKey(const ValueKey('driver_card_$_mohan')), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
    });

    testWidgets('a timed out selection says the driver did not confirm', (tester) async {
      final repo = FakeTaxiRepo();
      final c = await _open(tester, repo, _selected(), early);
      repo.getAnswer = (_) => TaxiOk(_lapsed(updatedAt: '2026-12-10T10:01:05Z'));
      await _refresh(tester, c);
      expect(find.text(_didNotConfirm), findsOneWidget);
      expect(find.text(_unavailable), findsNothing);
    });

    testWidgets('an early lapse noticed after the confirm time still says unavailable', (tester) async {
      final repo = FakeTaxiRepo();
      final c = await _open(tester, repo, _selected(), DateTime.utc(2026, 12, 10, 11));
      repo.getAnswer = (_) => TaxiOk(_lapsed(updatedAt: '2026-12-10T09:50:00Z'));
      await _refresh(tester, c);
      expect(find.text(_unavailable), findsOneWidget);
      expect(find.text(_didNotConfirm), findsNothing);
    });

    testWidgets('no backup driver: the request reopens and the finding screen shows the line', (tester) async {
      final repo = FakeTaxiRepo();
      final c = await _open(tester, repo, _selected(), early);
      repo.getAnswer = (_) => TaxiOk(_lapsedNoBackup());
      await _refresh(tester, c);
      expect(c.request.value?.state, RequestState.open);
      expect(find.byKey(const ValueKey('status_lapse_line')), findsOneWidget);
      expect(find.text(_unavailable), findsOneWidget);
      expect(find.byKey(const ValueKey('status_number_note')), findsOneWidget);
    });

    testWidgets('no backup driver and timed out says did not confirm', (tester) async {
      final repo = FakeTaxiRepo();
      final c = await _open(tester, repo, _selected(), early);
      repo.getAnswer = (_) => TaxiOk(_lapsedNoBackup(updatedAt: '2026-12-10T10:01:05Z'));
      await _refresh(tester, c);
      expect(find.text(_didNotConfirm), findsOneWidget);
    });

    testWidgets('not agreed by the traveller shows no lapse line', (tester) async {
      final repo = FakeTaxiRepo();
      final c = await _open(tester, repo, _selected(), early);
      repo.actionAnswer = TaxiOk(_lapsed());
      await c.notAgreed(_ramesh);
      await tester.pump();
      expect(c.lapse.value, isNull);
      expect(find.byKey(const ValueKey('status_lapse_line')), findsNothing);
      expect(find.byKey(const ValueKey('driver_card_$_mohan')), findsOneWidget);
    });

    testWidgets('choosing again clears the line', (tester) async {
      final repo = FakeTaxiRepo();
      final c = await _open(tester, repo, _selected(), early);
      repo.getAnswer = (_) => TaxiOk(_lapsed());
      await _refresh(tester, c);
      expect(find.text(_unavailable), findsOneWidget);
      repo.actionAnswer = TaxiOk(sampleRequest('taxi_request_selected.json', change: {'version': 10}));
      await c.select(_mohan);
      await tester.pump();
      expect(find.byKey(const ValueKey('status_lapse_line')), findsNothing);
    });

    testWidgets('a request that opens already collecting shows no line', (tester) async {
      await _open(tester, FakeTaxiRepo(), _lapsed(), early);
      expect(find.byKey(const ValueKey('status_lapse_line')), findsNothing);
    });

    for (final size in fiveSizes) {
      testWidgets('lapse line at ${sizeLabel(size)}', (tester) async {
        final repo = FakeTaxiRepo();
        final c = await _open(tester, repo, _selected(), early, size: size);
        repo.getAnswer = (_) => TaxiOk(_lapsed());
        await _refresh(tester, c);
        expect(tester.takeException(), isNull);
        expect(find.text(_unavailable), findsOneWidget);
      });
    }
  });

  group('rating after a trip cancelled mid-trip (O13)', () {
    final now = DateTime.utc(2026, 12, 19, 10);

    testWidgets('rate card shows and submits', (tester) async {
      final repo = FakeTaxiRepo();
      await _open(tester, repo, _leftDuringTrip(), now);
      expect(find.byKey(const ValueKey('taxi_rating_card')), findsOneWidget);
      expect(find.text('Rate your driver'), findsOneWidget);
      await _tap(tester, 'rate_star_4');
      repo.actionAnswer = TaxiOk(_leftDuringTrip(canRate: false, version: 21, rating: {'stars': 4, 'ratedAt': '2026-12-19T10:05:00Z'}));
      await _tap(tester, 'rate_submit');
      expect(repo.actions, ['rate:4']);
      expect(find.text('Thank you'), findsOneWidget);
      expect(find.byKey(const ValueKey('taxi_rating_card')), findsNothing);
    });

    testWidgets('no rate card when the backend does not allow rating', (tester) async {
      await _open(tester, FakeTaxiRepo(), _leftDuringTrip(canRate: false), now);
      expect(find.byKey(const ValueKey('taxi_rating_card')), findsNothing);
      expect(find.text('Request closed'), findsOneWidget);
    });

    testWidgets('an old answer without canRate stays the closed screen', (tester) async {
      final json = sampleJson('taxi_request_in_progress.json');
      final booking = {...(json['booking'] as Map<String, dynamic>), 'state': 'Cancelled'};
      final r = TaxiRequest.fromJson({...json, 'state': 'Cancelled', 'view': 'Ended', 'booking': booking});
      await _open(tester, FakeTaxiRepo(), r, now);
      expect(find.text('Request closed'), findsOneWidget);
    });

    for (final size in fiveSizes) {
      testWidgets('rate card at ${sizeLabel(size)}', (tester) async {
        await _open(tester, FakeTaxiRepo(), _leftDuringTrip(), now, size: size);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('taxi_rating_card')), findsOneWidget);
      });
    }

    test('booking fields round trip only when sent', () {
      final b = _leftDuringTrip().booking!;
      expect(b.canRate, isTrue);
      expect(b.leftDuringTrip, isTrue);
      expect(b.toJson()['canRate'], true);
      final old = TaxiBooking.fromJson(sampleJson('taxi_request_booked.json')['booking'] as Map<String, dynamic>);
      expect(old.canRate, isFalse);
      expect(old.toJson().containsKey('canRate'), isFalse);
    });
  });

  group('429 backs off quietly', () {
    test('Retry-After is read and clamped', () {
      final r = TaxiResult.fromError<TaxiRequest>(_tooMany(retryAfter: '7')) as TaxiRefused<TaxiRequest>;
      expect(r.rateLimited, isTrue);
      expect(r.retryAfterSeconds, 7);
      expect((TaxiResult.fromError<TaxiRequest>(_tooMany()) as TaxiRefused).retryAfterSeconds, 1);
      expect((TaxiResult.fromError<TaxiRequest>(_tooMany(retryAfter: '9999')) as TaxiRefused).retryAfterSeconds, 120);
    });

    test('a limited poll is not repeated until the wait is over', () async {
      var clock = DateTime.utc(2026, 12, 10, 9);
      final repo = FakeTaxiRepo();
      repo.getAnswer = (_) => const TaxiRefused(type: 'TooManyRequests', statusCode: 429, retryAfterSeconds: 30);
      final c = _controller(repo, () => clock);
      c.attach(_selected().id);
      await c.refreshRequest();
      final first = repo.getIds.length;
      expect(first, 1);
      expect(c.backingOff, isTrue);
      await c.refreshRequest();
      await c.refreshRequest();
      c.onTaxiPush();
      await Future<void>.delayed(Duration.zero);
      expect(repo.getIds.length, first);
      clock = clock.add(const Duration(seconds: 31));
      expect(c.backingOff, isFalse);
      repo.getAnswer = (_) => TaxiOk(_selected());
      await c.refreshRequest();
      expect(repo.getIds.length, first + 1);
      expect(c.request.value?.id, _selected().id);
      c.detach();
    });

    testWidgets('taps during the wait send nothing', (tester) async {
      var clock = DateTime.utc(2026, 12, 10, 9);
      final repo = FakeTaxiRepo();
      repo.getAnswer = (_) => TaxiOk(_lapsed());
      final c = _controller(repo, () => clock);
      await pumpAtSize(
        tester,
        TripTaxiRequestStatusScreen(requestId: _lapsed().id, controller: c, onDone: () {}, onCall: (_) async {}, onBack: () {}),
        phoneSize,
      );
      await tester.pump();
      await tester.pump();
      repo.actionAnswer = const TaxiRefused(type: 'TooManyRequests', statusCode: 429, retryAfterSeconds: 30);
      await _tap(tester, 'driver_select_$_mohan');
      expect(repo.actions, ['select:$_mohan']);
      await _tap(tester, 'driver_select_$_mohan');
      await _tap(tester, 'driver_select_$_mohan');
      expect(repo.actions, ['select:$_mohan']);
      expect(find.text('Please wait a moment and try again.'), findsOneWidget);
      clock = clock.add(const Duration(seconds: 31));
      repo.actionAnswer = TaxiOk(sampleRequest('taxi_request_selected.json', change: {'version': 10}));
      await _tap(tester, 'driver_select_$_mohan');
      expect(repo.actions.length, 2);
      c.detach();
    });

    test('the trip read backs off and the first limited load is not a failure', () async {
      var clock = DateTime.utc(2026, 12, 10, 9);
      final repo = _LimitedTripRead();
      final c = _controller(repo, () => clock);
      final r = await c.loadForTrip('trip-1');
      expect(r, isA<TaxiRefused<TaxiRequest?>>());
      expect(c.hasFailed(TaxiAction.loadTrip), isFalse);
      expect(c.backingOff, isTrue);
      await c.load(_selected().id);
      await c.loadForTrip('trip-1');
      expect(repo.getIds, isEmpty);
      expect(c.hasFailed(TaxiAction.load), isFalse);
      clock = clock.add(const Duration(seconds: 25));
      expect(c.backingOff, isFalse);
    });

    testWidgets('the timer refreshes once when the wait ends', (tester) async {
      var clock = DateTime.utc(2026, 12, 10, 9);
      final repo = FakeTaxiRepo();
      repo.getAnswer = (_) => const TaxiRefused(type: 'TooManyRequests', statusCode: 429, retryAfterSeconds: 10);
      final c = _controller(repo, () => clock);
      c.attach(_selected().id);
      await tester.pump();
      expect(repo.getIds.length, 1);
      repo.getAnswer = (_) => TaxiOk(_selected());
      await tester.pump(const Duration(seconds: 5));
      expect(repo.getIds.length, 1);
      clock = clock.add(const Duration(seconds: 11));
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(repo.getIds.length, 2);
      expect(c.request.value?.id, _selected().id);
      await tester.pump(const Duration(seconds: 60));
      expect(repo.getIds.length, 2);
      c.detach();
    });

    testWidgets('a limited first load stays on loading, not on the failed screen', (tester) async {
      final repo = FakeTaxiRepo();
      repo.getAnswer = (_) => const TaxiRefused(type: 'TooManyRequests', statusCode: 429, retryAfterSeconds: 30);
      final c = _controller(repo, () => DateTime.utc(2026, 12, 10, 9));
      await pumpAtSize(
        tester,
        TripTaxiRequestStatusScreen(requestId: _selected().id, controller: c, onDone: () {}, onCall: (_) async {}, onBack: () {}),
        phoneSize,
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('status_retry')), findsNothing);
      expect(find.text('Loading your request'), findsOneWidget);
      c.detach();
    });

    testWidgets('a limited action shows a calm line, not an error toast', (tester) async {
      final repo = FakeTaxiRepo();
      final c = await _open(tester, repo, _lapsed(), DateTime.utc(2026, 12, 10, 9));
      repo.actionAnswer = const TaxiRefused(type: 'TooManyRequests', statusCode: 429, retryAfterSeconds: 5);
      await _tap(tester, 'driver_select_$_mohan');
      expect(find.byKey(const ValueKey('status_failed_line')), findsOneWidget);
      expect(find.text('Please wait a moment and try again.'), findsOneWidget);
      expect(c.backingOff, isTrue);
      c.detach();
    });
  });
}
