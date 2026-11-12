import 'package:bakhli/features/taxi/ways/taxi_ways_feed_screen.dart';
import 'package:bakhli/features/taxi/ways/widgets/way_driver_row.dart';
import 'package:bakhli/features/trip/models/trip_guide_args.dart';
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

Future<void> _open(WidgetTester t, double w, double scale, Map<String, dynamic> args) async {
  t.view.physicalSize = Size(w, 760);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  installFakeApi([
    FakeRoute.value('GET', '/taxis/ways', {
      'version': 'v1',
      'from': _place('a', 'Haldwani'),
      'to': _place('b', 'Nainital'),
      'allTheWay': [_driver('d1'), _driver('d2')],
      'plans': [],
    })
  ]);
  await t.pumpWidget(GetMaterialApp(
    builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
    home: Builder(
      builder: (c) => TextButton(
        onPressed: () => Navigator.of(c).push(MaterialPageRoute(
          settings: RouteSettings(arguments: {
            'from': PlaceResult(name: 'Haldwani', subtitle: '', latLng: LatLng(29.2, 79.5)),
            'to': PlaceResult(name: 'Nainital', subtitle: '', latLng: LatLng(29.4, 79.45)),
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

  for (final w in [300.0, 360.0, 412.0]) {
    for (final s in [1.3, 2.0]) {
      testWidgets('guided ways list renders and the shortlist bar is docked at $w dp, scale $s', (t) async {
        await _open(t, w, s, {'tripRole': 'gettingThere', ...const GuideArgs('gettingThere').toArgs()});
        expect(find.byType(WayDriverRow), findsWidgets);
        expect(find.textContaining('shortlisted'), findsOneWidget);
        final bar = t.getRect(find.textContaining('shortlisted'));
        expect(bar.bottom, greaterThan(760 - 120));
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('plain ways list shows drivers and no shortlist bar', (t) async {
    await _open(t, 360, 1, {});
    expect(find.byType(WayDriverRow), findsWidgets);
    expect(find.textContaining('shortlisted'), findsNothing);
  });
}
