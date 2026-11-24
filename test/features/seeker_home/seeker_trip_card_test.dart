import 'package:bakhli/design/design.dart';
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
    expect(find.text('Find your next destination?'), findsOneWidget);
    expect(find.text('Plan your trip'), findsOneWidget);
    expect(find.text('Make your itinerary.'), findsOneWidget);
    expect(find.text('Plan a trip'), findsOneWidget);
    expect(find.text('Travel Planner'), findsNothing);
    expect(find.byType(WorkoutActionPill), findsOneWidget);
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
    expect(find.text('Plan your trip'), findsOneWidget);
    expect(find.text('3 of 3 plans used. Delete one to plan more.'), findsOneWidget);
  });

  Rect cardRect(WidgetTester t) => t.getRect(find.descendant(of: find.byType(WorkoutCard), matching: find.byType(DecoratedBox)).first);

  testOwnerSizes('Bug 10: no-trip card is the banner base with the pill at the bottom right', () => _host(_noTrip), check: (t, _, _) async {
    final card = cardRect(t);
    final pill = t.getRect(find.byType(WorkoutActionPill));
    expect(card.height, greaterThanOrEqualTo(DS.s(SeekerTripCardView.minHeight) - 0.5));
    expect(card.right - pill.right, moreOrLessEquals(DS.s(20), epsilon: 0.5));
    expect(card.bottom - pill.bottom, moreOrLessEquals(DS.s(20), epsilon: 0.5));
    expect(pill.height, moreOrLessEquals(DS.s(46), epsilon: 0.5));
    expect(pill.left, greaterThanOrEqualTo(card.left));
    for (final s in ['Find your next destination?', 'Plan your trip', 'Make your itinerary.']) {
      expect(pill.overlaps(t.getRect(find.text(s))), isFalse, reason: s);
    }
    final art = t.getRect(find.byType(Art3D));
    expect(art.top, lessThan(card.top), reason: 'art sticks out above the card');
    expect(pill.top, greaterThanOrEqualTo(art.bottom), reason: 'pill stays below the art');
  });

  for (final (name, feed, status) in [
    ('in progress', _inProgress, _confirmed),
    ('on trip', _onTrip(seen: 2), null),
    ('full', _withSlots(_inProgress, const SeekerSlots(count: 3, limit: 3, full: true)), _reply),
  ]) {
    testOwnerSizes('Bug 10: $name card keeps the pill under its extra rows', () => _host(feed, status: status), check: (t, _, _) async {
      final card = cardRect(t);
      final pill = t.getRect(find.byType(WorkoutActionPill));
      expect(card.right - pill.right, moreOrLessEquals(DS.s(20), epsilon: 0.5));
      expect(card.bottom - pill.bottom, moreOrLessEquals(DS.s(20), epsilon: 0.5));
      for (final text in find.descendant(of: find.byType(WorkoutCard), matching: find.byType(Text)).evaluate()) {
        final w = text.widget as Text;
        if (find.descendant(of: find.byType(WorkoutActionPill), matching: find.byWidget(w)).evaluate().isNotEmpty) continue;
        expect(pill.overlaps(t.getRect(find.byWidget(w))), isFalse, reason: w.data);
      }
    });
  }

  testWidgets('Bug 10: card uses the indigo tone, the banner corner and the briefcase art', (t) async {
    await t.pumpWidget(MaterialApp(home: _host(_noTrip)));
    final card = t.widget<WorkoutCard>(find.byType(WorkoutCard));
    expect(card.tone, ListingTone.indigo);
    expect(card.art, ListingArt.luggage);
    expect(card.actionLabel, 'Plan a trip');
    expect(card.minHeight, 156);
    final box = t.widget<DecoratedBox>(find.descendant(of: find.byType(WorkoutCard), matching: find.byType(DecoratedBox)).first);
    expect((box.decoration as BoxDecoration).borderRadius, DS.br(WorkoutCard.radius));
  });

  testWidgets('Bug 10: the whole card is one TalkBack button and a tap anywhere opens the action', (t) async {
    final handle = t.ensureSemantics();
    final taps = <String>[];
    await t.pumpWidget(MaterialApp(home: _host(_noTrip, taps: taps)));
    expect(
      find.byWidgetPredicate((w) => w is Semantics && w.properties.button == true && w.properties.label == 'Plan your trip'),
      findsOneWidget,
    );
    await t.tap(find.text('Make your itinerary.'));
    expect(taps, ['plan']);
    handle.dispose();
  });

  testWidgets('Bug 10: status and My trips stay their own buttons inside the tappable card', (t) async {
    final taps = <String>[];
    await t.pumpWidget(MaterialApp(home: _host(_withSlots(_inProgress, const SeekerSlots(count: 3, limit: 3, full: true)), status: _reply, taps: taps)));
    await t.tap(find.text('2 stays replied. Pick one.'));
    await t.tap(find.text('My trips'));
    await t.tap(find.text('Continue your trip'));
    expect(taps, ['status', 'myTrips', 'continue']);
  });

  testWidgets('Bug 10: error card keeps Travel Planner, Your trips and Retry on the same base', (t) async {
    var retried = 0;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SeekerTripCardView(feed: SeekerFeed.empty, failed: true, onRetry: () => retried++))));
    expect(find.text('Travel Planner'), findsOneWidget);
    expect(find.text('Your trips'), findsOneWidget);
    expect(find.descendant(of: find.byType(WorkoutActionPill), matching: find.text('Retry')), findsOneWidget);
    await t.tap(find.text('Retry'));
    expect(retried, 1);
  });

  testWidgets('Bug 10: error card is one TalkBack button that says it failed and that a tap retries', (t) async {
    final handle = t.ensureSemantics();
    var retried = 0;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SeekerTripCardView(feed: SeekerFeed.empty, failed: true, onRetry: () => retried++))));
    expect(
      find.byWidgetPredicate((w) =>
          w is Semantics && w.properties.button == true && w.properties.label == 'Your trips. Check your internet and try again. Retry'),
      findsOneWidget,
    );
    await t.tap(find.text('Check your internet and try again.'));
    expect(retried, 1);
    handle.dispose();
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
