import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_feed_screen.dart';
import 'package:bakhli/features/taxi/ways/trip_strings_mcb_a2.dart';
import 'package:bakhli/features/taxi/ways/widgets/way_driver_row.dart';
import 'package:bakhli/features/trip/controllers/trip_supply_controller.dart';
import 'package:bakhli/features/trip/models/trip_guide_args.dart';
import 'package:bakhli/features/trip/trip_constants.dart';
import 'package:bakhli/features/trip/trip_strings_guide.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../journeys/fake_api.dart';

Map<String, Object?> _place(String key, String name) => {'key': key, 'name': name, 'lat': 30.0, 'lng': 78.0};

Map<String, Object?> _driver(String id) => {
      'taxiId': id,
      'driverName': 'Driver $id',
      'vehicleTypeName': 'Innova',
      'seats': 7,
      'fromName': 'Haldwani',
      'toName': 'Nainital',
      'listedFare': 1500,
      'basedHere': true,
    };

Map<String, Object?> _leg(int i, String from, String to) => {
      'legKey': 'l$i',
      'index': i,
      'from': _place('f$i', from),
      'to': _place('t$i', to),
      'listedFare': 1500,
      'topDrivers': [_driver('d$i')],
      'driverCount': 1,
    };

Map<String, Object?> _waysJson({required bool plan}) => {
      'version': 'v1',
      'from': _place('a', 'Haldwani'),
      'to': _place('b', 'Munsiyari'),
      'plans': plan
          ? [
              {
                'planKey': 'p-two',
                'cars': 2,
                'total': 3000,
                'legs': [_leg(1, 'Haldwani', 'Almora'), _leg(2, 'Almora', 'Munsiyari')],
              }
            ]
          : [],
    };

Future<void> _open(WidgetTester t, Map<String, Object?> ways, Map<String, dynamic> args) async {
  t.view.physicalSize = const Size(360, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  installFakeApi([FakeRoute.value('GET', '/taxis/ways', ways)]);
  await t.pumpWidget(GetMaterialApp(
    home: Builder(
      builder: (c) => TextButton(
        onPressed: () => Navigator.of(c).push(MaterialPageRoute(
          settings: RouteSettings(arguments: {
            'from': PlaceResult(name: 'Haldwani', subtitle: '', latLng: LatLng(29.2, 79.5)),
            'to': PlaceResult(name: 'Munsiyari', subtitle: '', latLng: LatLng(30.0, 80.2)),
            'fromTrip': true,
            'tripId': 't1',
            ...args,
          }),
          builder: (_) => const TaxiWaysFeedScreen(),
        )),
        child: const Text('go'),
      ),
    ),
  ));
  await t.tap(find.text('go'));
  await t.pump();
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await t.pump(const Duration(seconds: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  for (final role in ['gettingThere', 'comingBack']) {
    testWidgets('gap card for $role shows arrange myself, skip and the nearest place hint', (t) async {
      await _open(t, _waysJson(plan: false), {'tripRole': role});
      expect(find.text(TripStringsGuide.optOwn), findsWidgets);
      expect(find.text(TripStringsGuide.optSkip), findsWidgets);
      expect(find.text(TripStringsMcbA2.nobodyListed), findsOneWidget);
      expect(find.textContaining('Munsiyari'), findsWidgets);
      expect(find.byKey(const ValueKey('plan-only-note')), findsNothing);
    });
  }

  testWidgets('guided plan-only result shows the one enquiry per car note and the arrange bar', (t) async {
    await _open(t, _waysJson(plan: true), {'tripRole': 'gettingThere', ...GuideArgs('gettingThere').toArgs()});
    expect(find.byKey(const ValueKey('plan-only-note')), findsOneWidget);
    expect(find.text(TaxiWaysFeedScreen.planOnlyNote), findsOneWidget);
    expect(find.text(TripStringsGuide.optOwn), findsOneWidget);
    expect(find.text(TripStringsGuide.optSkip), findsOneWidget);
  });

  testWidgets('driver row says the driver confirms the final fare', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WayDriverRow(driver: WayDriver.fromJson(_driver('d1')), onTap: () {}),
        ),
      ),
    ));
    expect(find.text(WayDriverRow.finalFareNote), findsOneWidget);
  });

  test('supply radius comes from the one constant', () {
    expect(TripSupplyController.radiusKm, TripConstants.cityRadiusKm);
    expect(TripConstants.cityRadiusKm, 10);
  });
}
