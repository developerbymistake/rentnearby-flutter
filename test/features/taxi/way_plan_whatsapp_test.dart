import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/taxi/ways/widgets/way_plan_stack_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WayPlan _plan({String? whatsApp}) => WayPlan.fromJson({
      'planKey': 'p1',
      'cars': 1,
      'total': 900,
      'legs': [
        {
          'legKey': 'l1',
          'index': 1,
          'from': {'key': 'a', 'name': 'Haldwani', 'lat': 29.2, 'lng': 79.5},
          'to': {'key': 'b', 'name': 'Bhowali', 'lat': 29.4, 'lng': 79.5},
          'listedFare': 900,
          'topDrivers': [
            {
              'taxiId': 'x1',
              'driverName': 'Rakesh Singh',
              'vehicleTypeName': 'Dzire',
              'seats': 4,
              'listedFare': 900,
              'phone': '9876500000',
              if (whatsApp != null) 'whatsApp': whatsApp,
            },
          ],
          'driverCount': 1,
        },
      ],
    });

Future<void> _pump(WidgetTester t, WayPlan plan) async {
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: WayPlanStackCard(plan: plan, planIndex: 0, onOpen: () {})),
    ),
  ));
}

void main() {
  testWidgets('plan card shows Call and WhatsApp when the driver has a WhatsApp number', (t) async {
    await _pump(t, _plan(whatsApp: '9876500000'));
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
  });

  testWidgets('plan card hides WhatsApp when the driver has no WhatsApp number', (t) async {
    await _pump(t, _plan());
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);
  });
}
