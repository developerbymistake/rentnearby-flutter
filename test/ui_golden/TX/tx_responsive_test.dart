import 'package:bakhli/features/taxi/taxi_option_sets.dart' show TaxiStatus;
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart';
import 'package:bakhli/features/taxi/setup/taxi_owner_card.dart';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/taxi/ways/widgets/journey_driver_card.dart';
import 'package:bakhli/features/taxi/ways/widgets/local_taxi_rail_card.dart';
import 'package:bakhli/features/taxi/ways/widgets/way_plan_ribbon_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


const _driver = WayDriver(
  taxiId: 't1',
  driverName: 'Ramesh Kumar Negi Long Name Here',
  vehicleTypeName: 'Innova Crysta',
  seats: 7,
  fromName: 'Dehradun',
  toName: 'Mussoorie',
  listedFare: 1800,
  basedHere: true,
);

const _a = WayPlace(key: 'a', name: 'Dehradun', lat: 30.3, lng: 78.0);
const _b = WayPlace(key: 'b', name: 'Mussoorie', lat: 30.4, lng: 78.07);
const _c = WayPlace(key: 'c', name: 'Kempty Falls Road', lat: 30.5, lng: 78.1);

WayLeg _leg(int i, WayPlace f, WayPlace t) => WayLeg(
      legKey: 'l$i',
      index: i,
      from: f,
      to: t,
      listedFare: 1800,
      topDrivers: const [_driver],
      driverCount: 3,
    );

TaxiOwnerModel _owner(String status) => TaxiOwnerModel(
      id: 'o1',
      status: status,
      step1Done: true,
      routesDone: true,
      vehicleTypeName: 'Innova Crysta',
      seats: 7,
      plateDisplay: 'UK07 AB 1234',
      minFare: 1800,
      pendingReportCount: 1,
      localDayRate: 3000,
      createdAt: DateTime(2026, 1, 1),
      routes: const [
        TaxiRouteModel(
            id: 'r1',
            routeIndex: 0,
            fromName: 'Dehradun',
            fromLatitude: 30,
            fromLongitude: 78,
            toName: 'Mussoorie Library Chowk',
            toLatitude: 30.4,
            toLongitude: 78.07,
            fare: 1800,
            tripType: 'ONE_WAY'),
      ],
    );

void main() {
  for (final w in [300.0, 360.0, 412.0, 560.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('TX responsive @$w x$scale', (t) async {
        t.view.physicalSize = Size(w, 1600);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final taxi = TaxiBrowseItem(
          id: 't1',
          driverName: 'Ramesh Kumar Negi',
          vehicleTypeName: 'Innova Crysta',
          seats: 7,
          plateDisplay: 'UK07 AB 1234',
          cityName: 'Dehradun',
          minFare: 1800,
          routeCount: 2,
          matchReversed: false,
          createdAt: DateTime(2026, 1, 1),
          localDayRate: 3000,
        );
        final plan2 = WayPlan(planKey: 'p', cars: 2, total: 3600, legs: [_leg(1, _a, _b), _leg(2, _b, _c)]);
        await t.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(w, 1600), textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  JourneyDriverCard(
                      driver: _driver, otherCount: 3, onChange: () {}, onTap: () {}, selected: true, seatsNote: 'Seats 7, you need 9'),
                  WayPlanRibbonCard(plan: plan2, planIndex: 0, bestReason: 'Lowest fare', onOpen: () {}, onUse: () {}),
                  TaxiOwnerCard(
                    taxi: _owner(TaxiStatus.rejected),
                    onEditFare: (_) {},
                    onPreview: () {},
                    onShare: () {},
                    onDelete: () {},
                    onTripLeads: () {},
                    onLocalRate: () {},
                    newLeads: 2,
                    onOpenSetup: () {},
                  ),
                  SizedBox(height: 300, child: ListView(scrollDirection: Axis.horizontal, children: [LocalTaxiRailCard(item: taxi)])),
                ]),
              ),
            ),
          ),
        ));
        await t.pump(const Duration(seconds: 2));
        expect(t.takeException(), isNull);
      });
    }
  }
}
