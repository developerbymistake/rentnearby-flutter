import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/widgets/customize/trip_customize_spot_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _spot = TripSpotRef(id: 's1', name: 'Naini Lake', latitude: 29.39, longitude: 79.45, category: 'lake', visitMinutes: 60);

Future<void> _pump(WidgetTester t, int? drive) => t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TripCustomizeSpotRow(spot: _spot, day: 0, index: 0, color: Colors.indigo, time: '9:00', driveMinutes: drive, frozen: true),
      ),
    ));

void main() {
  testWidgets('a zero minute drive has no row, like the day plan', (t) async {
    await _pump(t, 0);
    expect(find.text('0 min'), findsNothing);
    await _pump(t, 25);
    expect(find.text('25 min'), findsOneWidget);
    await _pump(t, null);
    expect(find.text('25 min'), findsNothing);
  });
}
