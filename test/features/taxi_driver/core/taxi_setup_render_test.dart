import 'package:bakhli/features/taxi/setup/taxi_routes_screen.dart';
import 'package:bakhli/features/taxi/setup/taxi_setup_hub_screen.dart';
import 'package:bakhli/features/taxi/setup/taxi_submit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';
import 'taxi_setup_fixtures.dart';

final _route1 = setupRoute('r1', 'Haldwani', 'Nainital', 1800);
final _step1 = setupTaxi(percent: 40, step1: true, identity: true);
final _saved = setupTaxi(percent: 90, step1: true, identity: true, routes: [_route1], rate: 2500, km: 120);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  setUpAll(() => initTestStorage('taxi_setup_render'));
  useOwnerRenderScale();
  tearDown(tearDownTaxiSetup);

  testWidgets('render o_tx_1', (t) async {
    setUpTaxiSetup(setupTaxi(), canCorrect: true);
    await renderOwnerFrame(t, 'o_tx_1', const TaxiSetupHubScreen(), arrange: _settle);
    for (final s in ['Set up your taxi', 'Finish 3 steps to open your dashboard', 'Profile 0% complete', 'Vehicle and contact', 'Routes and fares', 'Final submit', 'Wrong role? Change it']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
  });

  testWidgets('render o_tx_4', (t) async {
    setUpTaxiSetup(_saved);
    await renderOwnerFrame(t, 'o_tx_4', const TaxiRoutesScreen(), arrange: _settle);
    for (final s in ['Routes and fares', 'Step 2 of 3', 'Routes', '1 of 1 on Free', '1 of 1 route saved on Free', 'Haldwani to Nainital', 'Route 1 · One way · ₹1,800', 'Free plan keeps 1 route. Get Plus to add up to 5.', 'See Plus', 'Local sightseeing', 'Needed to list your taxi', 'Travellers see this rate. You can quote a different fare for a trip after you read the itinerary.', 'Save', 'Add another route', 'Plus']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    expect(find.text('Route 2'), findsNothing);
  });

  testWidgets('o_tx_3 save of route 2 on Free opens G1 and Not now keeps route 1 only', (t) async {
    setUpTaxiSetup(_saved);
    await pumpPhone(t, const TaxiRoutesScreen(), size: const Size(360, 800));
    await _settle(t);
    await t.tap(find.text('Add another route'));
    await _settle(t);
    expect(find.text('Route 2'), findsOneWidget);
  });

  testWidgets('payment off: no plan words, meter reads N of 5', (t) async {
    setUpTaxiSetup(_saved, plan: OwnerPlans.paymentOff);
    await pumpPhone(t, const TaxiRoutesScreen(), size: const Size(360, 800));
    await _settle(t);
    expect(find.text('1 of 5'), findsOneWidget);
    expect(find.textContaining('Free'), findsNothing);
    expect(find.text('See Plus'), findsNothing);
  });

  testWidgets('render o_tx_2', (t) async {
    setUpTaxiSetup(_saved);
    await renderOwnerFrame(t, 'o_tx_2', const TaxiRoutesScreen(), arrange: (t) async {
      await _settle(t);
      await t.tap(find.text('Add another route'));
      await _settle(t);
    });
    for (final s in ['Routes and fares', 'Step 2 of 3', 'Routes', '1 of 1 on Free', 'Free plan: 1 route. Plus allows up to 5 routes.', 'See Plus', 'Haldwani to Nainital', 'Route 1 · One way · ₹1,800', 'Route 2', 'New route', 'One way', 'Round trip', 'Routes: 1 of 1 on Free', 'Save route']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
  });

  testWidgets('render o_tx_5', (t) async {
    setUpTaxiSetup(_saved);
    await renderOwnerFrame(t, 'o_tx_5', const TaxiSubmitScreen(), arrange: _settle);
    for (final s in ['Final Submit', 'Step 3 of 3', 'Check your taxi', 'Travellers see this after approval.', 'Vehicle and contact', 'Vehicle', 'Maruti Ertiga', 'Seats', '6', 'Plate', 'UK 04 TA 2231', 'Phone', '+91 98765 11223', 'Base', 'Haldwani', 'Routes and fares', 'Routes', '1', 'Local day rate', '₹2,500 · 120 km', 'Submit for review']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    expect(find.text('Dashboard opens after submit'), findsNothing);
  });

  testWidgets('o_tx_5 refusals before submit', (t) async {
    setUpTaxiSetup(setupTaxi(percent: 40, step1: true, identity: false, routes: [_route1], rate: 2500, km: 120));
    await pumpPhone(t, const TaxiSubmitScreen(), size: const Size(360, 800));
    await _settle(t);
    expect(find.text('Add licence and date of birth'), findsOneWidget);
    await t.tap(find.text('Submit for review'));
    await _settle(t);
    expect(find.text('Add your licence and date of birth.'), findsOneWidget);
    await t.pump(const Duration(seconds: 8));
  });

  testWidgets('render o_tx_1 step 1 done', (t) async {
    setUpTaxiSetup(_step1);
    await renderOwnerFrame(t, 'o_tx_1', const TaxiSetupHubScreen(), part: 'X', arrange: _settle);
  });

  for (final rows in [0, 1, 5]) {
    testOwnerSizes('routes screen with $rows routes', () => const TaxiRoutesScreen(), setUpEach: () {
      setUpTaxiSetup(setupTaxi(percent: 60, step1: true, identity: true, routes: [for (var i = 0; i < rows; i++) setupRoute('r$i', 'Haldwani', 'City $i', 1800 + i * 100)]));
    }, arrange: _settle);
  }

  testOwnerSizes('submit screen', () => const TaxiSubmitScreen(), setUpEach: () => setUpTaxiSetup(_saved), arrange: _settle);
}
