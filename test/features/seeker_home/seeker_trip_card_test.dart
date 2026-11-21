import 'package:bakhli/features/seeker_home/seeker_feed_model.dart';
import 'package:bakhli/features/seeker_home/seeker_trip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/owner_sizes.dart';

const _noTrip = SeekerFeed(slots: SeekerSlots(count: 0, limit: 3, full: false));

final _inProgress = SeekerFeed(
  tripCard: SeekerTripCard(
    state: SeekerTripState.inProgress,
    tripId: 'trip-1',
    title: 'Nainital trip',
    destinationName: 'Nainital',
    startDate: DateTime(2026, 11, 26),
    endDate: DateTime(2026, 11, 29),
    done: 3,
    total: 5,
    nextStep: const SeekerNextStep(key: 'taxi', kind: SeekerStepKind.taxi),
  ),
  slots: const SeekerSlots(count: 2, limit: 3, full: false),
);

SeekerFeed _onTrip({int? seen, int places = 4}) => SeekerFeed(
      tripCard: SeekerTripCard(
        state: SeekerTripState.onTrip,
        tripId: 'trip-1',
        title: 'Nainital trip',
        destinationName: 'Nainital',
        startDate: DateTime(2026, 11, 26),
        endDate: DateTime(2026, 11, 29),
        done: 3,
        total: 5,
        today: SeekerToday(dayNumber: 2, totalDays: 4, cityName: 'Mukteshwar', placeCount: places, placesSeen: seen),
      ),
    );

SeekerFeed _withSlots(SeekerFeed f, SeekerSlots s) => SeekerFeed(tripCard: f.tripCard, status: f.status, slots: s);

const _confirmed = SeekerStatus(kind: SeekerStatusKind.confirmed, listingName: 'Deodar Heights', key: 'k1');
const _reply = SeekerStatus(kind: SeekerStatusKind.reply, count: 2, key: 'k2');

Widget _host(SeekerFeed feed, {SeekerStatus? status, List<String>? taps}) => Scaffold(
      body: SingleChildScrollView(
        child: SeekerTripCardView(
          feed: feed,
          status: status,
          onPlan: () => taps?.add('plan'),
          onContinue: () => taps?.add('continue'),
          onToday: () => taps?.add('today'),
          onMyTrips: () => taps?.add('myTrips'),
          onStatus: () => taps?.add('status'),
        ),
      ),
    );

void main() {
  testOwnerSizes('o_sk_1 no trip card', () => _host(_noTrip), check: (t, _, _) async {
    expect(find.text('Travel Planner'), findsOneWidget);
    expect(find.text('Plan your first trip'), findsOneWidget);
    expect(find.text('Places, days, stay and taxi in one plan.'), findsOneWidget);
    expect(find.text('Plan a trip'), findsOneWidget);
  });

  testOwnerSizes('o_sk_2 in progress card with status', () => _host(_inProgress, status: _confirmed), check: (t, _, _) async {
    expect(find.text('Nainital trip · 26 to 29 Nov'), findsOneWidget);
    expect(find.text('Continue your trip'), findsOneWidget);
    expect(find.text('3 of 5 done'), findsOneWidget);
    expect(find.text('Next: book a taxi'), findsOneWidget);
    expect(find.text('Deodar Heights confirmed your stay'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testOwnerSizes('o_sk_3 on the trip card', () => _host(_onTrip()), check: (t, _, _) async {
    expect(find.text('Nainital trip · Day 2 of 4'), findsOneWidget);
    expect(find.text('Today in Mukteshwar'), findsOneWidget);
    expect(find.text('4 places on today’s plan'), findsOneWidget);
    expect(find.text('Today’s plan'), findsOneWidget);
  });

  testOwnerSizes('o_sk_4 plans full card', () => _host(_withSlots(_inProgress, const SeekerSlots(count: 3, limit: 3, full: true))),
      check: (t, _, _) async {
    expect(find.text('3 of 3 plans used. Delete one to plan more.'), findsOneWidget);
    expect(find.text('My trips'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testOwnerSizes('very long trip title stays one line', () {
    final long = SeekerFeed(
      tripCard: SeekerTripCard(state: SeekerTripState.inProgress, tripId: 't', title: 'A very long trip name ' * 6, done: 1, total: 9),
    );
    return _host(long, status: _reply);
  });

  testWidgets('o_sk_1_noTrip_showsPlanYourFirstTripAndOneButton and o_sk_1_noCityChipsInCard', (t) async {
    final taps = <String>[];
    await t.pumpWidget(MaterialApp(home: _host(_noTrip, taps: taps)));
    expect(find.text('Plan a trip'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.textContaining('Nainital'), findsNothing);
    await t.tap(find.text('Plan a trip'));
    expect(taps, ['plan']);
  });

  testWidgets('o_sk_2_statusReply_winsOverConfirmed: the line is the reply copy and opens the status target', (t) async {
    final taps = <String>[];
    await t.pumpWidget(MaterialApp(home: _host(_inProgress, status: _reply, taps: taps)));
    expect(find.text('2 stays replied. Pick one.'), findsOneWidget);
    expect(find.text('Deodar Heights confirmed your stay'), findsNothing);
    await t.tap(find.text('2 stays replied. Pick one.'));
    expect(taps, ['status']);
  });

  testWidgets('o_sk_2_continueOpensNextStep', (t) async {
    final taps = <String>[];
    await t.pumpWidget(MaterialApp(home: _host(_inProgress, taps: taps)));
    await t.tap(find.text('Continue'));
    expect(taps, ['continue']);
  });

  testWidgets('o_sk_2_unknownNextStepKey_noNextLine and o_sk_2_totalZero_noBar', (t) async {
    final f = SeekerFeed(
      tripCard: SeekerTripCard(
        state: SeekerTripState.inProgress,
        tripId: 't',
        title: 'Nainital trip',
        done: 0,
        total: 0,
        nextStep: const SeekerNextStep(key: 'x', kind: SeekerStepKind.unknown),
      ),
    );
    await t.pumpWidget(MaterialApp(home: _host(f)));
    expect(find.textContaining('Next:'), findsNothing);
    expect(find.textContaining('0 of 0'), findsNothing);
    expect(find.byType(FractionallySizedBox), findsNothing);
  });

  testWidgets('o_sk_2 status hidden when the controller passes none', (t) async {
    await t.pumpWidget(MaterialApp(home: _host(_inProgress)));
    expect(find.textContaining('confirmed your stay'), findsNothing);
  });

  testWidgets('o_sk_3_placesSeenNull_noLineNoBar', (t) async {
    await t.pumpWidget(MaterialApp(home: _host(_onTrip())));
    expect(find.textContaining('places seen'), findsNothing);
    expect(find.byType(FractionallySizedBox), findsNothing);
  });

  testWidgets('o_sk_3_placesSeenTwo_lineAndBar', (t) async {
    await t.pumpWidget(MaterialApp(home: _host(_onTrip(seen: 2))));
    expect(find.text('2 of 4 places seen'), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsOneWidget);
  });

  testWidgets('o_sk_3 zero places: no places line, button stays', (t) async {
    final taps = <String>[];
    await t.pumpWidget(MaterialApp(home: _host(_onTrip(places: 0), taps: taps)));
    expect(find.textContaining('places on today'), findsNothing);
    await t.tap(find.text('Today’s plan'));
    expect(taps, ['today']);
  });

  testWidgets('o_sk_4_belowLimit_showsNothing and o_sk_4_myTripsOpensMyTrips', (t) async {
    final taps = <String>[];
    await t.pumpWidget(MaterialApp(home: _host(_inProgress, taps: taps)));
    expect(find.textContaining('plans used'), findsNothing);
    await t.pumpWidget(MaterialApp(home: _host(_withSlots(_inProgress, const SeekerSlots(count: 3, limit: 3, full: true)), taps: taps)));
    await t.tap(find.text('My trips'));
    expect(taps, ['myTrips']);
  });

  testWidgets('o_sk_4_limitOfFive_textUsesFive', (t) async {
    await t.pumpWidget(MaterialApp(home: _host(_withSlots(_inProgress, const SeekerSlots(count: 5, limit: 5, full: true)))));
    expect(find.text('5 of 5 plans used. Delete one to plan more.'), findsOneWidget);
  });

  testWidgets('o_sk_4 no trip and full: the strip shows under the no-trip card', (t) async {
    await t.pumpWidget(MaterialApp(home: _host(const SeekerFeed(slots: SeekerSlots(count: 3, limit: 3, full: true)))));
    expect(find.text('Plan your first trip'), findsOneWidget);
    expect(find.text('3 of 3 plans used. Delete one to plan more.'), findsOneWidget);
  });

  testWidgets('buttons are at least 48 dp tall at text scale 1.3', (t) async {
    await t.pumpWidget(MaterialApp(
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.3)), child: child!),
      home: _host(_withSlots(_inProgress, const SeekerSlots(count: 3, limit: 3, full: true))),
    ));
    for (final label in ['Continue', 'My trips']) {
      final box = find.ancestor(of: find.text(label), matching: find.byType(GestureDetector)).first;
      expect(t.getSize(box).height, greaterThanOrEqualTo(48), reason: label);
    }
  });
}
