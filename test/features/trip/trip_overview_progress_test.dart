import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/screens/trip_overview_screen.dart';
import 'package:bakhli/features/trip/utils/trip_parts.dart';
import 'package:bakhli/features/trip/widgets/trip_overview_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';

const _a = TripPartState.arranged;
const _o = TripPartState.open;
const _s = TripPartState.skipped;

TripParts _parts(TripPartState taxi, TripPartState stay) => TripParts(itinerary: _a, taxi: taxi, stay: stay);

TripModel _trip() => TripModel(
      id: 't1',
      title: 'Hills',
      status: TripStatuses.planned,
      cityKey: 1,
      cityName: 'Nainital',
      cityLatitude: 29.4,
      cityLongitude: 79.4,
      dayCount: 3,
      spotCount: 6,
      legCount: 1,
      plan: TripPlan.singleCity(
        cityKey: 1,
        cityName: 'Nainital',
        settings: const TripSettings(adults: 2),
        days: [TripDay(day: 1, spots: const [])],
      ),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Widget _screen(TripParts parts, {bool showStay = true}) => TripOverviewScreen(
      trip: _trip(),
      parts: parts,
      highlight: TripOverviewScreen.highlightOf(parts, showStay: showStay),
      showStay: showStay,
      onViewPlan: () {},
      onTaxi: (_) {},
      onDone: () {},
      onBack: () {},
      onStay: (_) {},
    );

Widget _card(TripParts parts, {bool showProgress = true}) => Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TripOverviewProgress(parts: parts, title: 'Hills', line: '1 city · 3 days · 2 travellers', showProgress: showProgress),
      ),
    );

bool _highlighted(WidgetTester t, String card) => find
    .descendant(
      of: find.byKey(ValueKey(card)),
      matching: find.byWidgetPredicate((w) => w is Semantics && (w.properties.label ?? '').endsWith(', next')),
    )
    .evaluate()
    .isNotEmpty;

void main() {
  group('line and percent per state', () {
    final cases = <String, (TripParts, int, String, int)>{
      'both open': (_parts(_o, _o), 33, 'Itinerary saved. Taxi and stay are optional.', 0),
      'taxi arranged': (_parts(_a, _o), 67, 'Stay not added yet.', 0),
      'stay arranged': (_parts(_o, _a), 67, 'Taxi not added yet.', 0),
      'taxi skipped': (_parts(_s, _o), 67, 'Stay not added yet.', 1),
      'all arranged': (_parts(_a, _a), 100, 'All set.', 0),
      'completed by skip': (_parts(_s, _s), 100, 'All set.', 2),
      'no places': (TripParts.none, 0, 'Add places to your plan.', 0),
    };
    for (final e in cases.entries) {
      testWidgets(e.key, (t) async {
        final (parts, pct, line, ticks) = e.value;
        await pumpAtSize(t, _card(parts), phoneSize);
        expect(find.text('$pct%'), findsOneWidget);
        expect(find.byKey(const ValueKey('overview_progress_tick')), findsNWidgets(ticks));
        expect(find.bySemanticsLabel(RegExp('^${RegExp.escape('Plan progress, $pct percent. $line')}')), findsOneWidget);
        expect(find.text('Hills'), findsOneWidget);
        expect(find.text('1 city · 3 days · 2 travellers'), findsOneWidget);
        expect(find.text(line), findsNothing);
      });
    }
  });

  testFiveSizes('progress card fits', () => _card(_parts(_s, _o)), check: (t, _) async {
    expect(find.byKey(const ValueKey('overview_progress_card')), findsOneWidget);
    for (final k in ['itinerary', 'taxi', 'stay']) {
      expect(find.byKey(ValueKey('overview_progress_seg_$k')), findsOneWidget);
    }
  });

  testFiveSizes('progress card fits at text scale 1.3', () => _card(_parts(_o, _o)), textScale: 1.3);

  testWidgets('shared trip keeps the name and line without bars and ring', (t) async {
    await pumpAtSize(t, _card(_parts(_o, _o), showProgress: false), phoneSize);
    expect(find.text('Hills'), findsOneWidget);
    expect(find.text('1 city · 3 days · 2 travellers'), findsOneWidget);
    expect(find.byKey(const ValueKey('overview_progress_card')), findsNothing);
    expect(find.byKey(const ValueKey('overview_progress_seg_taxi')), findsNothing);
    expect(find.byKey(const ValueKey('overview_progress_percent')), findsNothing);
  });

  testFiveSizes('overview puts the card above the itinerary and keeps the bottom button', () => _screen(_parts(_o, _o)),
      check: (t, _) async {
    final card = t.getTopLeft(find.byKey(const ValueKey('overview_progress_card')));
    final itinerary = t.getTopLeft(find.byKey(const ValueKey('overview_itinerary_card')));
    expect(card.dy, lessThan(itinerary.dy));
    expect(find.text('Skip, just keep my plan'), findsOneWidget);
  });

  group('highlight of the next card', () {
    testWidgets('stay open highlights the stay card', (t) async {
      await pumpAtSize(t, _screen(_parts(_o, _o)), phoneSize);
      expect(_highlighted(t, 'overview_stay_card'), isTrue);
      expect(_highlighted(t, 'overview_taxi_card'), isFalse);
    });

    testWidgets('stay arranged highlights the taxi card', (t) async {
      await pumpAtSize(t, _screen(_parts(_o, _a)), phoneSize);
      expect(_highlighted(t, 'overview_taxi_card'), isTrue);
      expect(_highlighted(t, 'overview_stay_card'), isFalse);
    });

    testWidgets('all handled highlights nothing', (t) async {
      await pumpAtSize(t, _screen(_parts(_s, _a)), phoneSize);
      expect(_highlighted(t, 'overview_taxi_card'), isFalse);
      expect(_highlighted(t, 'overview_stay_card'), isFalse);
    });

    test('stay tab off falls to the taxi', () {
      expect(TripOverviewScreen.highlightOf(_parts(_o, _o), showStay: false), TripPart.taxi);
      expect(TripOverviewScreen.highlightOf(_parts(_a, _o), showStay: false), isNull);
      expect(TripOverviewScreen.highlightOf(_parts(_o, _o), showStay: true), TripPart.stay);
    });
  });
}
