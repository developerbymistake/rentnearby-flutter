import 'package:bakhli/features/taxi/setup/taxi_routes_screen.dart';
import 'package:bakhli/features/taxi/models/taxi_vehicle_type_model.dart';
import 'package:bakhli/features/taxi/setup/taxi_vehicle_screen.dart';
import 'package:bakhli/features/taxi/taxi_vehicle_types_controller.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';
import 'taxi_setup_fixtures.dart';

class _Types extends TaxiVehicleTypesController {
  @override
  // ignore: must_call_super
  void onInit() {
    types.value = const [TaxiVehicleTypeModel(id: 'v3', name: 'Maruti Ertiga', category: 'MUV', defaultSeats: 7, sortOrder: 1)];
  }

  @override
  Future<void> load() async {}
}

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

  testWidgets('render o_tx_4', (t) async {
    setUpTaxiSetup(_saved);
    await renderOwnerFrame(t, 'o_tx_4', const TaxiRoutesScreen(), arrange: _settle);
    for (final s in ['Routes and fares', 'Step 2 of 3', 'Routes', '1 of 1 on Free', '1 of 1 route saved on Free', 'Haldwani to Nainital', 'Route 1 · One way · ₹1,800', 'Free plan keeps 1 route. Get Plus to add up to 5.', 'See Plus', 'Local sightseeing', 'Needed to list your taxi', 'Travellers see this rate. You can quote a different fare for a trip after you read the itinerary.', 'Save', 'Add another route', 'Plus']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    expect(find.text('Route 2'), findsNothing);
  });

  testWidgets('o_tx_3 add route on Free opens G1 at the tap and no Route 2 form', (t) async {
    setUpTaxiSetup(_saved);
    await pumpPhone(t, const TaxiRoutesScreen(), size: const Size(360, 800));
    await _settle(t);
    expect(find.text('Routes: 1 of 1 on Free'), findsOneWidget);
    await t.ensureVisible(find.text('Add another route'));
    await t.pump();
    await t.tap(find.text('Add another route'));
    await _settle(t);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('1 route on Free'), findsOneWidget);
    expect(find.text('Route 2'), findsNothing);
  });

  testWidgets('add route row sits under the routes, above Local sightseeing', (t) async {
    setUpTaxiSetup(_saved);
    await pumpPhone(t, const TaxiRoutesScreen(), size: const Size(360, 1500));
    await _settle(t);
    final add = t.getTopLeft(find.text('Add another route')).dy;
    expect(add, greaterThan(t.getTopLeft(find.text('Haldwani to Nainital')).dy));
    expect(add, lessThan(t.getTopLeft(find.text('Local sightseeing')).dy));
  });

  testWidgets('Plus: the next route form is open in place with the add row below it', (t) async {
    setUpTaxiSetup(_saved, plan: OwnerPlans.plus);
    await pumpPhone(t, const TaxiRoutesScreen(), size: const Size(360, 1500));
    await _settle(t);
    expect(find.text('Route 2'), findsOneWidget);
    expect(find.text('2 of 5'), findsOneWidget);
    expect(find.text('Not now'), findsNothing);
    expect(t.getTopLeft(find.text('Add another route')).dy, greaterThan(t.getTopLeft(find.text('Route 2')).dy));
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
    setUpTaxiSetup(_saved, plan: OwnerPlans.plus);
    await renderOwnerFrame(t, 'o_tx_2', const TaxiRoutesScreen(), arrange: _settle);
    for (final s in ['Routes and fares', 'Step 2 of 3', 'Routes', '1 of 5', 'Haldwani to Nainital', 'Route 1 · One way · ₹1,800', 'Route 2', 'New route', 'One way', 'Round trip', 'Add another route', '2 of 5', 'Routes: 1 of 5', 'Save route']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
  });

  testWidgets('render o_tx_35 A vehicle step', (t) async {
    setUpTaxiSetup(_step1);
    Get.put<TaxiVehicleTypesController>(_Types());
    await renderOwnerFrame(t, 'o_tx_35', const TaxiVehicleScreen(), part: 'A', arrange: _settle);
    for (final s in ['Vehicle and contact', 'Step 1 of 3 · Vehicle', 'Vehicle type', 'Maruti Ertiga', 'Seats', 'Plate number', 'Number plate photo', 'Plate must be visible', 'Next']) {
      expect(find.textContaining(s, findRichText: true), findsWidgets, reason: s);
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 11));
  });

  for (final rows in [0, 1, 5]) {
    testOwnerSizes('routes screen with $rows routes', () => const TaxiRoutesScreen(), setUpEach: () {
      setUpTaxiSetup(setupTaxi(percent: 60, step1: true, identity: true, routes: [for (var i = 0; i < rows; i++) setupRoute('r$i', 'Haldwani', 'City $i', 1800 + i * 100)]));
    }, arrange: _settle);
  }
}
