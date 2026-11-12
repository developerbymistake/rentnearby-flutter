import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/models/trip_journey_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/widgets/trip_journey_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden_support.dart';

TripJourney _journey(TripJourneyLeg l) => TripJourney(
      id: 'j',
      role: TripStepRole.gettingThere,
      fromName: 'Delhi',
      toName: 'Nainital',
      date: DateTime(2026, 12, 1),
      legs: [l],
    );

const _ok = TripJourneyLeg(
  legIndex: 1,
  fromName: 'Delhi',
  toName: 'Nainital',
  taxiId: 't1',
  driverName: 'Ramesh Kumar Negi',
  vehicleTypeName: 'Innova Crysta',
  phone: '9876543210',
  listedFare: 5200,
);

const _gone = TripJourneyLeg(
  legIndex: 1,
  fromName: 'Delhi',
  toName: 'Nainital',
  taxiId: 't1',
  driverName: 'Ramesh Kumar Negi',
  driverAvailable: false,
  backupName: 'Suresh Bisht',
  backupTaxiId: 't2',
  phone: '9876543210',
);

void main() {
  final strip = TripJourneyStrip(role: TripStepRole.gettingThere);
  for (final w in [300.0, 360.0, 412.0, 560.0]) {
    for (final scale in [1.0, 1.3]) {
      for (final entry in {'ok': _ok, 'paused': _gone}.entries) {
        testWidgets('journey car ${entry.key} @${w.toInt()} x$scale', (t) async {
          t.view.physicalSize = Size(w, 1400);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await loadGoldenFonts();
          await t.pumpWidget(MaterialApp(
            theme: ThemeData(fontFamily: 'WorkSans'),
            home: MediaQuery(
              data: MediaQueryData(size: Size(w, 1400), textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Builder(
                    builder: (c) => strip.carCard(c, _journey(entry.value), entry.value, const [], true),
                  ),
                ),
              ),
            ),
          ));
          await t.pump(const Duration(milliseconds: 600));
          expect(t.takeException(), isNull);
          expect(find.byType(DriverOptionCard), findsOneWidget);
          expect(find.textContaining('Ramesh Kumar Negi'), findsOneWidget);
          expect(find.byType(PrimaryButton), findsOneWidget);
          expect(find.byType(SecondaryButton), findsOneWidget);
        });
      }
    }
  }
}
