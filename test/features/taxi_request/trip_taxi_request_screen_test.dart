import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/controllers/trip_taxi_request_controller.dart';
import 'package:bakhli/features/trip/models/taxi_request_models.dart';
import 'package:bakhli/features/trip/screens/trip_taxi_request_screen.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/features/trip/widgets/taxi_request/taxi_day_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';
import 'taxi_request_controller_fakes.dart';

const _oldAskId = 'c7d1e2f3-4a5b-4c6d-8e9f-0a1b2c3d4e5f';

const _cities = ['Nainital', 'Nainital', 'Nainital', 'Ranikhet', 'Kausani', 'Almora', 'Almora', 'Jim Corbett', 'Jim Corbett'];

final List<TaxiRequestDayRow> _rows = [
  for (var i = 0; i < _cities.length; i++)
    TaxiRequestDayRow(
      day: i + 1,
      leg: _cities.indexOf(_cities[i]) + 1,
      city: _cities[i],
      places: ['Spot ${i + 1}a', 'Spot ${i + 1}b'],
      km: 20 + i,
    ),
];

class _CountingRepo extends FakeTaxiRepo {
  int placeCalls = 0;

  @override
  Future<TaxiResult<TaxiPickupPlaces>> pickupPlaces(String tripId) {
    placeCalls++;
    return super.pickupPlaces(tripId);
  }
}

TaxiPickupPlaces _emptyPickup() => TaxiPickupPlaces.fromJson({
      ...sampleJson('pickup_places.json'),
      'firstCity': {'cityKey': 1, 'name': 'Mukteshwar'},
      'pickup': <Object>[],
    });

TripTaxiRequestController _controller(FakeTaxiRepo repo, {FakeEnquiries? enquiries}) {
  var n = 0;
  return TripTaxiRequestController(
    repo: repo,
    enquiries: enquiries ?? FakeEnquiries(),
    realtime: null,
    refreshPlan: (_) async => true,
    onLegacyClosed: () {},
    newClientId: () => 'client-${++n}',
  );
}

class _Sent {
  final List<TaxiRequest> requests = [];
}

TripTaxiRequestScreen _screen(TripTaxiRequestController c, {_Sent? sent, VoidCallback? onTryAnotherCity}) => TripTaxiRequestScreen(
      controller: c,
      tripId: 't1',
      rows: _rows,
      onSent: (r) => (sent ?? _Sent()).requests.add(r),
      onTryAnotherCity: onTryAnotherCity ?? () {},
      onBack: () {},
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _pump(WidgetTester tester, TripTaxiRequestController c, {_Sent? sent, Size size = phoneSize, VoidCallback? onTryAnotherCity}) async {
  await pumpAtSize(tester, _screen(c, sent: sent, onTryAnotherCity: onTryAnotherCity), size);
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _tapKey(WidgetTester tester, String key) => _tap(tester, find.byKey(ValueKey(key)));

Future<void> _offDays(WidgetTester tester, List<int> days) async {
  for (final d in days) {
    await _tapKey(tester, 'taxi_day_switch_$d');
  }
}

Future<void> _pickKathgodam(WidgetTester tester) => _tapKey(tester, 'taxi_pickup_6377270');

String _summary(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('taxi_request_summary'))).data!;

bool _sendEnabled(WidgetTester tester) => tester.widget<GradientPillButton>(find.byKey(const ValueKey('taxi_request_send'))).enabled;

Future<TripTaxiRequestController> _ready(WidgetTester tester, {FakeTaxiRepo? repo, _Sent? sent}) async {
  final c = _controller(repo ?? FakeTaxiRepo());
  await _pump(tester, c, sent: sent);
  return c;
}

void main() {
  testWidgets('frame_21_all_on', (tester) async {
    await _ready(tester);
    await _offDays(tester, [3, 7, 9]);
    expect(find.text('Request taxi'), findsWidgets);
    expect(find.text('Choose what you need, then send'), findsOneWidget);
    expect(find.text('Turn a section on or off. Only turned-on sections are sent.'), findsOneWidget);
    expect(find.text('Pickup from hub'), findsOneWidget);
    expect(find.text('Choose pickup'), findsOneWidget);
    expect(find.text('Kathgodam'), findsOneWidget);
    expect(find.text('6 drivers'), findsOneWidget);
    expect(find.text('Haldwani'), findsOneWidget);
    expect(find.text('9 drivers'), findsOneWidget);
    expect(find.text('Sightseeing taxi'), findsOneWidget);
    expect(find.text('3 days'), findsOneWidget);
    expect(find.text('Day 1 · Nainital'), findsOneWidget);
    expect(find.text('About 20 km'), findsOneWidget);
    expect(find.text('Drop to hub'), findsOneWidget);
    expect(find.text('Same as pickup'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Your car'), findsOneWidget);
    expect(find.text('Set from 2 travellers'), findsOneWidget);
    expect(find.text('4 seater'), findsOneWidget);
    expect(find.text('6 seater'), findsOneWidget);
    expect(find.text('7 seater'), findsOneWidget);
    expect(find.text('12 seater'), findsOneWidget);
    expect(_summary(tester), 'Choose a pickup, 6 sightseeing days, drop same as pickup');
    expect(_sendEnabled(tester), isFalse);
  });

  testWidgets('frame_22_all_off_disables_send', (tester) async {
    await _ready(tester);
    await _tapKey(tester, 'taxi_pickup_switch');
    await _tapKey(tester, 'taxi_sightseeing_switch');
    await _tapKey(tester, 'taxi_drop_switch');
    expect(_summary(tester), 'Turn on at least one section');
    expect(_sendEnabled(tester), isFalse);
    expect(find.byKey(const ValueKey('taxi_day_1')), findsNothing);
    expect(find.text('Choose pickup'), findsNothing);
    expect(find.text('Your car'), findsOneWidget);
  });

  testWidgets('frame_23_pickup_only', (tester) async {
    await _ready(tester);
    await _tapKey(tester, 'taxi_sightseeing_switch');
    await _tapKey(tester, 'taxi_drop_switch');
    await _pickKathgodam(tester);
    expect(_summary(tester), 'Pickup at Kathgodam');
    expect(_sendEnabled(tester), isTrue);
    expect(find.text('Haldwani'), findsNothing);
  });

  testWidgets('frame_24_sightseeing_only', (tester) async {
    await _ready(tester);
    await _tapKey(tester, 'taxi_pickup_switch');
    await _tapKey(tester, 'taxi_drop_switch');
    await _offDays(tester, [3, 7, 9]);
    expect(_summary(tester), '6 sightseeing days');
    expect(_sendEnabled(tester), isTrue);
  });

  testWidgets('frame_25_drop_only', (tester) async {
    await _ready(tester);
    await _tapKey(tester, 'taxi_pickup_switch');
    await _tapKey(tester, 'taxi_sightseeing_switch');
    expect(_summary(tester), 'Choose a drop');
    expect(_sendEnabled(tester), isFalse);
    expect(find.text('Choose drop'), findsOneWidget);
    expect(find.text('Same as pickup'), findsNothing);
    expect(find.text('Ramnagar'), findsOneWidget);
    expect(find.text('5 drivers'), findsOneWidget);
    await _tapKey(tester, 'taxi_drop_2738820');
    expect(_summary(tester), 'Drop at Ramnagar');
    expect(_sendEnabled(tester), isTrue);
  });

  testWidgets('frame_26_pickup_and_drop', (tester) async {
    await _ready(tester);
    await _tapKey(tester, 'taxi_sightseeing_switch');
    await _pickKathgodam(tester);
    expect(_summary(tester), 'Pickup at Kathgodam, drop same as pickup');
    expect(_sendEnabled(tester), isTrue);
    await _tapKey(tester, 'taxi_drop_change');
    expect(find.byKey(const ValueKey('taxi_drop_same')), findsOneWidget);
    expect(find.text('Same as pickup'), findsOneWidget);
    expect(find.text('Choose drop'), findsNothing);
    expect(find.text('Ramnagar'), findsOneWidget);
    expect(find.text('Kashipur'), findsOneWidget);
    await _tapKey(tester, 'taxi_drop_1525290');
    expect(_summary(tester), 'Pickup at Kathgodam, drop at Kashipur');
    await _tapKey(tester, 'taxi_drop_field');
    await _tapKey(tester, 'taxi_drop_same_row');
    expect(_summary(tester), 'Pickup at Kathgodam, drop same as pickup');
    expect(find.byKey(const ValueKey('taxi_drop_same')), findsOneWidget);
  });

  testWidgets('frame_27_ready_send_enabled', (tester) async {
    await _ready(tester);
    await _offDays(tester, [3, 7, 9]);
    await _pickKathgodam(tester);
    expect(_summary(tester), 'Pickup at Kathgodam, 6 sightseeing days, drop same as pickup');
    expect(_sendEnabled(tester), isTrue);
  });

  testWidgets('frame_28_empty_pickup_list', (tester) async {
    var tried = 0;
    final repo = FakeTaxiRepo()..placesAnswer = TaxiOk(_emptyPickup());
    final c = _controller(repo);
    await _pump(tester, c, onTryAnotherCity: () => tried++);
    await _tapKey(tester, 'taxi_sightseeing_switch');
    await _tapKey(tester, 'taxi_drop_switch');
    expect(find.text('No taxi drivers registered near here yet'), findsOneWidget);
    expect(find.text('Pickup is not available for Mukteshwar right now.'), findsOneWidget);
    expect(find.text('Skip taxi'), findsOneWidget);
    expect(find.text('Try another city'), findsOneWidget);
    expect(find.text('Kathgodam'), findsNothing);
    expect(find.text('Haldwani'), findsNothing);
    expect(_summary(tester), 'No pickup available here');
    expect(_sendEnabled(tester), isFalse);
    await _tapKey(tester, 'taxi_pickup_try_another');
    expect(tried, 1);
    await _tapKey(tester, 'taxi_pickup_skip');
    expect(c.form.value!.pickupOn, isFalse);
    expect(find.text('No taxi drivers registered near here yet'), findsNothing);
  });

  testWidgets('empty pickup list shows no fallback list with every section on', (tester) async {
    final repo = FakeTaxiRepo()..placesAnswer = TaxiOk(_emptyPickup());
    await _pump(tester, _controller(repo));
    expect(_summary(tester), 'No pickup available here');
    expect(find.text('No taxi drivers registered near here yet'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d+ drivers?$')), findsNothing);
    expect(_sendEnabled(tester), isFalse);
  });

  testWidgets('day toggle changes summary', (tester) async {
    await _ready(tester);
    await _pickKathgodam(tester);
    expect(_summary(tester), 'Pickup at Kathgodam, 9 sightseeing days, drop same as pickup');
    await _tapKey(tester, 'taxi_day_switch_2');
    expect(_summary(tester), 'Pickup at Kathgodam, 8 sightseeing days, drop same as pickup');
    await _tapKey(tester, 'taxi_day_switch_2');
    expect(_summary(tester), 'Pickup at Kathgodam, 9 sightseeing days, drop same as pickup');
  });

  testWidgets('paused banner disables send', (tester) async {
    final repo = FakeTaxiRepo()..placesAnswer = TaxiOk(TaxiPickupPlaces.fromJson({...sampleJson('pickup_places.json'), 'paused': true}));
    await _pump(tester, _controller(repo));
    await _pickKathgodam(tester);
    expect(find.text('Requests are paused right now'), findsOneWidget);
    expect(_sendEnabled(tester), isFalse);
  });

  testWidgets('Send calls the controller once', (tester) async {
    final repo = FakeTaxiRepo()..createAnswers.add(TaxiOk(sampleRequest('taxi_request_finding.json')));
    final sent = _Sent();
    await _ready(tester, repo: repo, sent: sent);
    await _pickKathgodam(tester);
    await _tapKey(tester, 'taxi_request_send');
    expect(repo.createBodies, hasLength(1));
    expect(repo.createBodies.single['pickup'], {'on': true, 'cityKey': 6377270});
    expect(sent.requests, hasLength(1));
  });

  testWidgets('PickupNotAvailable reloads the list', (tester) async {
    final repo = _CountingRepo()
      ..createAnswers.add(const TaxiRefused(type: 'PickupNotAvailable', statusCode: 409, message: 'Pickup changed'));
    final sent = _Sent();
    final c = await _ready(tester, repo: repo, sent: sent);
    expect(repo.placeCalls, 1);
    await _pickKathgodam(tester);
    repo.placesAnswer = TaxiOk(TaxiPickupPlaces.fromJson({
      ...sampleJson('pickup_places.json'),
      'pickup': [
        {'cityKey': 2552100, 'name': 'Haldwani', 'drivers': 9},
      ],
    }));
    await _tapKey(tester, 'taxi_request_send');
    expect(repo.placeCalls, 2);
    expect(sent.requests, isEmpty);
    expect(c.places.value!.pickup.map((p) => p.name), ['Haldwani']);
    expect(find.text('Kathgodam'), findsNothing);
    expect(_summary(tester), startsWith('Choose a pickup'));
    expect(_sendEnabled(tester), isFalse);
    await tester.pump(const Duration(seconds: 5));
  });

  group('legacy ask dialog', () {
    TaxiLegacyActive<TaxiRequest> legacy() => const TaxiLegacyActive(rows: [TaxiLegacyRow(id: _oldAskId, booked: false)]);

    testWidgets('legacy_taxi_dialog_cancels_then_sends_again', (tester) async {
      final repo = FakeTaxiRepo()..createAnswers.addAll([legacy(), TaxiOk(sampleRequest('taxi_request_finding.json'))]);
      final enquiries = FakeEnquiries();
      final c = _controller(repo, enquiries: enquiries);
      final sent = _Sent();
      await _pump(tester, c, sent: sent);
      await _pickKathgodam(tester);
      await _tapKey(tester, 'taxi_request_send');
      expect(find.text('Taxi already asked'), findsOneWidget);
      expect(find.text('This trip has a taxi ask from an older app version. Cancel it to send a new request.'), findsOneWidget);
      expect(find.text('Keep it'), findsOneWidget);
      expect(find.text('Cancel old ask'), findsOneWidget);
      expect(repo.createBodies, hasLength(1));
      await _tapKey(tester, 'taxi_legacy_cancel');
      expect(enquiries.withdrawn, [_oldAskId]);
      expect(repo.createBodies, hasLength(2));
      expect(sent.requests, hasLength(1));
      expect(find.text('Taxi already asked'), findsNothing);
    });

    testWidgets('legacy_taxi_dialog_keep_changes_nothing', (tester) async {
      final repo = FakeTaxiRepo()..createAnswers.add(legacy());
      final enquiries = FakeEnquiries();
      final c = _controller(repo, enquiries: enquiries);
      final sent = _Sent();
      await _pump(tester, c, sent: sent);
      await _pickKathgodam(tester);
      final before = c.form.value!.summary;
      await _tapKey(tester, 'taxi_request_send');
      await _tapKey(tester, 'taxi_legacy_keep');
      expect(find.text('Taxi already asked'), findsNothing);
      expect(enquiries.withdrawn, isEmpty);
      expect(enquiries.cancelled, isEmpty);
      expect(repo.createBodies, hasLength(1));
      expect(sent.requests, isEmpty);
      expect(c.form.value!.summary, before);
      expect(_sendEnabled(tester), isTrue);
    });

    testWidgets('legacy_taxi_dialog_five_sizes', (tester) async {
      for (final size in fiveSizes) {
        final repo = FakeTaxiRepo()..createAnswers.add(legacy());
        final c = _controller(repo);
        await _pump(tester, c, size: size);
        await _pickKathgodam(tester);
        await _tapKey(tester, 'taxi_request_send');
        expect(find.text('Taxi already asked'), findsOneWidget, reason: sizeLabel(size));
        expect(tester.takeException(), isNull, reason: sizeLabel(size));
        await _tapKey(tester, 'taxi_legacy_keep');
        expect(tester.takeException(), isNull, reason: sizeLabel(size));
      }
    });
  });

  group('seats and overlap', () {
    TripTaxiRequestController withTravellers(FakeTaxiRepo repo, int n) {
      repo.placesAnswer = TaxiOk(TaxiPickupPlaces.fromJson({...sampleJson('pickup_places.json'), 'travellers': n, 'suggestedSeats': 4}));
      return _controller(repo);
    }

    bool seatOn(WidgetTester tester, int s) =>
        tester.widget<Opacity>(find.ancestor(of: find.byKey(ValueKey('taxi_seat_$s')), matching: find.byType(Opacity)).first).opacity == 1;

    testWidgets('six travellers disable the 4 seater', (tester) async {
      final repo = FakeTaxiRepo();
      final c = withTravellers(repo, 6);
      await _pump(tester, c);
      expect(seatOn(tester, 4), isFalse);
      expect(seatOn(tester, 6), isTrue);
      expect(c.form.value!.seats, 6);
      await _tapKey(tester, 'taxi_seat_4');
      expect(c.form.value!.seats, 6);
      await _tapKey(tester, 'taxi_seat_12');
      expect(c.form.value!.seats, 12);
    });

    testWidgets('above 12 travellers send stays off with the group line', (tester) async {
      final c = withTravellers(FakeTaxiRepo(), 13);
      await _pump(tester, c);
      await _pickKathgodam(tester);
      expect(_sendEnabled(tester), isFalse);
      expect(_summary(tester), 'For groups above 12, please send separate requests.');
    });

    testWidgets('overlap error names the other trip and keeps the form', (tester) async {
      final repo = FakeTaxiRepo()
        ..createAnswers.add(const TaxiOverlap(tripId: 't9', tripName: 'Goa Trip', message: 'x'));
      final sent = _Sent();
      await _ready(tester, repo: repo, sent: sent);
      await _pickKathgodam(tester);
      await _tapKey(tester, 'taxi_request_send');
      expect(find.text('You already have a taxi request for these dates in Goa Trip.'), findsOneWidget);
      expect(sent.requests, isEmpty);
      expect(_sendEnabled(tester), isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('overlap error without a trip name says another trip', (tester) async {
      final repo = FakeTaxiRepo()..createAnswers.add(const TaxiOverlap(tripId: 't9', tripName: '  ', message: 'x'));
      final sent = _Sent();
      await _ready(tester, repo: repo, sent: sent);
      await _pickKathgodam(tester);
      await _tapKey(tester, 'taxi_request_send');
      expect(find.text('You already have a taxi request for these dates in another trip.'), findsOneWidget);
      expect(sent.requests, isEmpty);
      expect(_sendEnabled(tester), isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('NoReadyDriver on send says no driver is ready and keeps the form', (tester) async {
      final repo = FakeTaxiRepo()..createAnswers.add(const TaxiNoReadyDriver(message: 'server text'));
      final sent = _Sent();
      await _ready(tester, repo: repo, sent: sent);
      await _pickKathgodam(tester);
      await _tapKey(tester, 'taxi_request_send');
      expect(find.text('No driver is ready for this route right now. Please try again in a little while.'), findsOneWidget);
      expect(find.textContaining('busy'), findsNothing);
      expect(sent.requests, isEmpty);
      expect(_sendEnabled(tester), isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('AllDriversBusy on send says all drivers are busy', (tester) async {
      final repo = FakeTaxiRepo()..createAnswers.add(const TaxiAllDriversBusy(message: 'server text'));
      await _ready(tester, repo: repo);
      await _pickKathgodam(tester);
      await _tapKey(tester, 'taxi_request_send');
      expect(find.text('All drivers are busy right now. Please try again in a little while.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('header menu Try another city calls back once and keeps the form', (tester) async {
      var tried = 0;
      final c = _controller(FakeTaxiRepo());
      await _pump(tester, c, onTryAnotherCity: () => tried++);
      await _pickKathgodam(tester);
      final before = c.form.value!.summary;
      await _tapKey(tester, 'taxi_request_menu');
      expect(find.text('Try another city'), findsOneWidget);
      await _tap(tester, find.text('Try another city'));
      expect(tried, 1);
      expect(find.text('Try another city'), findsNothing);
      expect(c.form.value!.summary, before);
      expect(_summary(tester), before);
      expect(_sendEnabled(tester), isTrue);
    });

    testWidgets('SeatsTooFew shows the message and reloads places', (tester) async {
      final repo = _CountingRepo()..createAnswers.add(const TaxiRefused(type: 'SeatsTooFew', statusCode: 400, message: 'm'));
      await _ready(tester, repo: repo);
      await _pickKathgodam(tester);
      await _tapKey(tester, 'taxi_request_send');
      expect(repo.placeCalls, 2);
      expect(find.text('Choose a taxi with a seat for everyone.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('seat states at five sizes', (tester) async {
      for (final n in [2, 6, 7, 12, 13]) {
        for (final size in fiveSizes) {
          final c = withTravellers(FakeTaxiRepo(), n);
          await _pump(tester, c, size: size);
          await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -4000));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '${sizeLabel(size)} travellers=$n');
          expect(find.text('12 seater'), findsOneWidget);
        }
      }
    });
  });

  testWidgets('five sizes', (tester) async {
    for (final empty in [false, true]) {
      for (final size in fiveSizes) {
        final repo = FakeTaxiRepo();
        if (empty) repo.placesAnswer = TaxiOk(_emptyPickup());
        final c = _controller(repo);
        await _pump(tester, c, size: size);
        expect(tester.takeException(), isNull, reason: '${sizeLabel(size)} empty=$empty');
        if (!empty) {
          await _pickKathgodam(tester);
          await _tapKey(tester, 'taxi_drop_change');
          expect(tester.takeException(), isNull, reason: '${sizeLabel(size)} drop picker');
        }
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -4000));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '${sizeLabel(size)} scrolled empty=$empty');
        expect(find.byKey(const ValueKey('taxi_request_send')), findsOneWidget);
      }
    }
  });
}
