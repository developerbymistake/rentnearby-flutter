import 'package:bakhli/features/social/c/social_strings_c.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/screens/trip_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/five_sizes.dart';
import '../../../support/real_phone.dart';

TripModel _trip({bool inactive = false}) => TripModel(
      id: 't1',
      title: 'Manali trip',
      status: TripStatuses.planned,
      cityKey: 1,
      cityName: 'Manali',
      cityLatitude: 32.2,
      cityLongitude: 77.2,
      dayCount: 3,
      spotCount: 5,
      plan: TripPlan.singleCity(cityKey: 1, cityName: 'Manali', settings: const TripSettings(adults: 2), days: [TripDay(day: 1, spots: const [])]),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      inactiveByPlan: inactive,
    );

void main() {
  tearDown(Get.reset);

  Future<List<String>> pump(WidgetTester t, TripModel trip) async {
    final taps = <String>[];
    await pumpAtSize(
      t,
      TripOverviewScreen(
        trip: trip,
        onViewPlan: () => taps.add('plan'),
        onTaxi: (_) => taps.add('taxi'),
        onDone: () {},
        onBack: () {},
        onStay: (_) => taps.add('stay'),
      ),
      phoneSize,
    );
    return taps;
  }

  testWidgets('an inactive trip shows the reason line and offers no new taxi or stay ask', (t) async {
    final taps = await pump(t, _trip(inactive: true));
    expect(find.byKey(const ValueKey('overview_inactive_line')), findsOneWidget);
    expect(find.text(SocialStringsC.inactiveTripPlain), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('overview_taxi_card')), warnIfMissed: false);
    await t.ensureVisible(find.byKey(const ValueKey('overview_stay_card')));
    await t.tap(find.byKey(const ValueKey('overview_stay_card')), warnIfMissed: false);
    await t.tap(find.byKey(const ValueKey('overview_itinerary_card')), warnIfMissed: false);
    await t.pump();
    expect(taps, ['plan']);
  });

  testWidgets('an active trip has no reason line', (t) async {
    final taps = await pump(t, _trip());
    expect(find.byKey(const ValueKey('overview_inactive_line')), findsNothing);
    await t.tap(find.byKey(const ValueKey('overview_taxi_card')));
    await t.pump();
    expect(taps, ['taxi']);
  });
}
