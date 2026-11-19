import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/screens/trip_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../journeys/fake_api.dart';
import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';

TripPlan _twoCityPlan() => TripPlan(
      legs: const [
        TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 29.4, longitude: 79.4),
        TripCityLeg(index: 2, cityKey: 2, cityName: 'Almora', latitude: 29.6, longitude: 79.7),
      ],
      settings: const TripSettings(adults: 2),
      days: [TripDay(day: 1, spots: const [])],
    );

TripModel _trip({String? view, String title = 'Uttarakhand Hills Trip', bool nameChosen = false, TripPlan? plan}) => TripModel(
      id: 't1',
      title: title,
      status: TripStatuses.planned,
      cityKey: 1,
      cityName: 'Nainital',
      cityLatitude: 29.4,
      cityLongitude: 79.4,
      dayCount: 9,
      spotCount: 31,
      legCount: 5,
      plan: plan ??
          TripPlan.singleCity(
            cityKey: 1,
            cityName: 'Nainital',
            settings: const TripSettings(adults: 2),
            days: [TripDay(day: 1, spots: const [])],
          ),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      taxiRequest: view == null ? null : TripTaxiRequestRef(requestId: 'r1', state: 'Open', view: view, version: 1),
      nameChosen: nameChosen,
    );

String _shownName(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('overview_trip_name'))).data!;

class _Calls {
  int plan = 0;
  int done = 0;
  final taxi = <TripOverviewTaxiState>[];
  final stay = <TripOverviewStayState>[];
}

TripOverviewScreen _screen(
  TripModel trip, {
  bool paused = false,
  _Calls? calls,
  TripOverviewStay stay = TripOverviewStay.notAdded,
  bool showStay = true,
}) {
  final c = calls ?? _Calls();
  return TripOverviewScreen(
    trip: trip,
    paused: paused,
    onViewPlan: () => c.plan++,
    onTaxi: (t) => c.taxi.add(t.state),
    onDone: () => c.done++,
    onBack: () {},
    stay: stay,
    showStay: showStay,
    onStay: (s) => c.stay.add(s.state),
  );
}

Future<void> _pump(WidgetTester tester, TripModel trip, {bool paused = false, _Calls? calls}) =>
    pumpAtSize(tester, _screen(trip, paused: paused, calls: calls), phoneSize);

Finder _in(String key, String text) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

void main() {
  testWidgets('name_shown', (tester) async {
    await _pump(tester, _trip());
    expect(find.text('Trip overview'), findsOneWidget);
    expect(find.text('Your plan is saved'), findsOneWidget);
    expect(find.text('Uttarakhand Hills Trip'), findsOneWidget);
    expect(find.text('5 cities · 9 days · 2 travellers'), findsOneWidget);
    expect(_in('overview_itinerary_card', 'Saved'), findsOneWidget);
    expect(find.text('9 days, 31 places'), findsOneWidget);
  });

  group('name follows the Day plan title rule', () {
    testWidgets('unchosen stale default follows the current cities', (tester) async {
      await _pump(tester, _trip(title: 'Nainital trip', plan: _twoCityPlan()));
      expect(_shownName(tester), 'Nainital, Almora trip');
    });

    testWidgets('chosen name is shown as is', (tester) async {
      await _pump(tester, _trip(title: 'Nainital trip', nameChosen: true, plan: _twoCityPlan()));
      expect(_shownName(tester), 'Nainital trip');
    });

    testWidgets('unchosen custom name is kept', (tester) async {
      await _pump(tester, _trip(plan: _twoCityPlan()));
      expect(_shownName(tester), 'Uttarakhand Hills Trip');
    });

    testWidgets('empty title falls back to the cities', (tester) async {
      await _pump(tester, _trip(title: '', plan: _twoCityPlan()));
      expect(_shownName(tester), 'Nainital, Almora trip');
    });
  });

  group('bottom label follows the card state', () {
    const labels = <String, String>{
      'Busy': 'Skip, just keep my plan',
      'Ended': 'Skip, just keep my plan',
      'Finding': 'Back to my trips',
      'Booked': 'Back to my trips',
      'Rate': 'Back to my trips',
      'Done': 'Back to my trips',
    };
    for (final e in labels.entries) {
      testWidgets('view ${e.key}', (tester) async {
        await _pump(tester, _trip(view: e.key));
        expect(_in('overview_done_button', e.value), findsOneWidget);
      });
    }
  });

  testWidgets('paused_keeps_an_existing_booking_open', (tester) async {
    final calls = _Calls();
    await _pump(tester, _trip(view: 'Booked'), paused: true, calls: calls);
    expect(find.text('Requests are paused right now'), findsOneWidget);
    final dim = tester.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('overview_taxi_card')), matching: find.byType(Opacity)).first);
    expect(dim.opacity, 1);
    await tester.tap(find.byKey(const ValueKey('overview_taxi_button')));
    expect(calls.taxi, [TripOverviewTaxiState.booked]);
  });

  testWidgets('paused_blocks_request_again_after_busy', (tester) async {
    final calls = _Calls();
    await _pump(tester, _trip(view: 'Busy'), paused: true, calls: calls);
    await tester.tap(find.byKey(const ValueKey('overview_taxi_button')), warnIfMissed: false);
    expect(calls.taxi, isEmpty);
  });

  testWidgets('taxi_card_optional', (tester) async {
    await _pump(tester, _trip());
    expect(_in('overview_taxi_card', 'Optional'), findsOneWidget);
    expect(_in('overview_taxi_card', 'Request taxi'), findsOneWidget);
    expect(find.text('Skip, just keep my plan'), findsOneWidget);
    expect(find.text('Back to my trips'), findsNothing);
  });

  testWidgets('taxi_card_requested_and_booked_from_trip_fields', (tester) async {
    await _pump(tester, _trip(view: 'Collecting'));
    expect(_in('overview_taxi_card', 'Requested'), findsOneWidget);
    expect(_in('overview_taxi_card', 'View request'), findsOneWidget);
    expect(find.text('Back to my trips'), findsOneWidget);
    expect(find.text('Skip, just keep my plan'), findsNothing);

    await _pump(tester, _trip(view: 'Booked'));
    expect(_in('overview_taxi_card', 'Booked'), findsOneWidget);
    expect(_in('overview_taxi_card', 'View booking'), findsOneWidget);
  });

  group('taxi_card_follows_the_contract_view_table', () {
    const table = <String?, (String, String)>{
      null: ('Optional', 'Request taxi'),
      'Busy': ('Optional', 'Request taxi'),
      'Ended': ('Optional', 'Request taxi'),
      'Something': ('Optional', 'Request taxi'),
      'Finding': ('Requested', 'View request'),
      'FindingWaiting': ('Requested', 'View request'),
      'NoReply': ('Requested', 'View request'),
      'Collecting': ('Requested', 'View request'),
      'Selected': ('Requested', 'View request'),
      'Booked': ('Booked', 'View booking'),
      'InProgress': ('Booked', 'View booking'),
      'Rate': ('Completed', 'View booking'),
      'Done': ('Completed', 'View booking'),
    };
    for (final e in table.entries) {
      testWidgets('view ${e.key}', (tester) async {
        await _pump(tester, _trip(view: e.key));
        expect(_in('overview_taxi_card', e.value.$1), findsOneWidget);
        expect(_in('overview_taxi_card', e.value.$2), findsOneWidget);
      });
    }
  });

  testWidgets('paused', (tester) async {
    final calls = _Calls();
    await _pump(tester, _trip(), paused: true, calls: calls);
    expect(find.text('Requests are paused right now'), findsOneWidget);
    final dim = tester.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('overview_taxi_card')), matching: find.byType(Opacity)).first);
    expect(dim.opacity, lessThan(1));
    await tester.tap(find.byKey(const ValueKey('overview_taxi_button')), warnIfMissed: false);
    expect(calls.taxi, isEmpty);

    await _pump(tester, _trip());
    expect(find.text('Requests are paused right now'), findsNothing);
  });

  testWidgets('buttons call their routes', (tester) async {
    final calls = _Calls();
    await _pump(tester, _trip(view: 'Booked'), calls: calls);
    await tester.tap(find.byKey(const ValueKey('overview_itinerary_button')));
    await tester.tap(find.byKey(const ValueKey('overview_taxi_button')));
    await tester.tap(find.byKey(const ValueKey('overview_done_button')));
    expect(calls.plan, 1);
    expect(calls.taxi, [TripOverviewTaxiState.booked]);
    expect(calls.done, 1);
  });

  group('stay card', () {
    TripEnquiryModel row(String status, {String kind = TripEnquiryKinds.stay}) => TripEnquiryModel.fromJson(
        enquiryJson(id: 'e$status$kind', kind: kind, status: status, start: DateTime(2030, 11, 1)));

    test('state follows the stay enquiries only', () {
      expect(TripOverviewStay.of(const []).state, TripOverviewStayState.notAdded);
      expect(TripOverviewStay.of([row(TripEnquiryStatuses.asked, kind: TripEnquiryKinds.taxi)]).state, TripOverviewStayState.notAdded);
      expect(TripOverviewStay.of([row(TripEnquiryStatuses.declined)]).state, TripOverviewStayState.notAdded);
      expect(TripOverviewStay.of([row(TripEnquiryStatuses.asked)]).state, TripOverviewStayState.requested);
      expect(TripOverviewStay.of([row(TripEnquiryStatuses.offered)]).state, TripOverviewStayState.requested);
      expect(TripOverviewStay.of([row(TripEnquiryStatuses.asked), row(TripEnquiryStatuses.confirmedByBoth)]).state,
          TripOverviewStayState.booked);
      expect(TripOverviewStay.of([row(TripEnquiryStatuses.bookedByTraveller)]).state, TripOverviewStayState.booked);
    });

    for (final e in {
      TripOverviewStay.notAdded: ('Optional', 'Find a stay'),
      TripOverviewStay.requested: ('Added', 'View stays'),
      TripOverviewStay.booked: ('Booked', 'View stays'),
    }.entries) {
      testWidgets('stay_card_${e.key.state.name}', (tester) async {
        await pumpAtSize(tester, _screen(_trip(), stay: e.key), phoneSize);
        expect(_in('overview_stay_card', 'Stay'), findsOneWidget);
        expect(_in('overview_stay_card', 'Homestays, hostels and hotels'), findsOneWidget);
        expect(_in('overview_stay_card', e.value.$1), findsOneWidget);
        expect(_in('overview_stay_card', e.value.$2), findsOneWidget);
        final arts = find.descendant(of: find.byKey(const ValueKey('overview_stay_card')), matching: find.byType(Art3D));
        expect(tester.widget<Art3D>(arts.first).asset, TravelIcon.stay);
      });
    }

    testWidgets('stay_card_hidden_when_stays_off', (tester) async {
      await pumpAtSize(tester, _screen(_trip(), showStay: false), phoneSize);
      expect(find.byKey(const ValueKey('overview_stay_card')), findsNothing);
    });

    testWidgets('stay_button_calls_onStay', (tester) async {
      final calls = _Calls();
      await pumpAtSize(tester, _screen(_trip(), stay: TripOverviewStay.requested, calls: calls), phoneSize);
      await tester.ensureVisible(find.byKey(const ValueKey('overview_stay_button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('overview_stay_button')));
      expect(calls.stay, [TripOverviewStayState.requested]);
    });

    testWidgets('bottom_label_follows_taxi_or_stay', (tester) async {
      await pumpAtSize(tester, _screen(_trip()), phoneSize);
      expect(_in('overview_done_button', 'Skip, just keep my plan'), findsOneWidget);
      await pumpAtSize(tester, _screen(_trip(), stay: TripOverviewStay.requested), phoneSize);
      expect(_in('overview_done_button', 'Back to my trips'), findsOneWidget);
      await pumpAtSize(tester, _screen(_trip(view: 'Finding')), phoneSize);
      expect(_in('overview_done_button', 'Back to my trips'), findsOneWidget);
      await pumpAtSize(tester, _screen(_trip(), stay: TripOverviewStay.booked, showStay: false), phoneSize);
      expect(_in('overview_done_button', 'Skip, just keep my plan'), findsOneWidget);
    });
  });

  testFiveSizes('skip_bar_touches_the_screen_bottom', () => _screen(_trip()), check: (tester, size) async {
    final bar = tester.getRect(find.ancestor(of: find.byKey(const ValueKey('overview_done_button')), matching: find.byType(DecoratedBox)).first);
    expect(bar.bottom, closeTo(size.height, 0.5));
    expect(bar.top, greaterThan(tester.getRect(find.byKey(const ValueKey('overview_progress_card'))).bottom));
  });

  testWidgets('three_cards_scroll_under_a_fixed_bar_on_a_small_phone', (tester) async {
    const small = Size(320, 568);
    await pumpAtSize(tester, _screen(_trip(view: 'Booked'), stay: TripOverviewStay.booked, paused: true), small);
    final done = find.byKey(const ValueKey('overview_done_button'));
    final before = tester.getRect(done);
    expect(before.bottom, lessThanOrEqualTo(small.height));
    expect(find.ancestor(of: done, matching: find.byType(Scrollable)), findsNothing);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pump();
    expect(tester.getRect(done), before);
    expect(tester.takeException(), isNull);
  });

  testFiveSizes('five sizes optional', () => _screen(_trip()));
  testFiveSizes('five sizes three cards booked', () => _screen(_trip(view: 'Booked'), stay: TripOverviewStay.booked));
  testFiveSizes('five sizes booked paused long name', () => _screen(_trip(view: 'Booked', title: 'A very long trip name that goes on and on forever'), paused: true));
  testFiveSizes('five sizes large text', () => _screen(_trip(view: 'Rate')), textScale: 1.5);
}
