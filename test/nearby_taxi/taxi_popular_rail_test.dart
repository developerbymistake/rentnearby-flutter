import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_controller_v2.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_screen_v2.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_popular_routes.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_seeker_cache.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../ui_golden/golden_support.dart';
import 'fake_taxi_feed_repo.dart';

TaxiPopularRoute _route(int i, {int? fare = 899, int count = 9, String to = 'Rishikesh'}) => TaxiPopularRoute(
      id: 'r$i',
      fromName: 'Delhi',
      fromLat: 28.61,
      fromLng: 77.21,
      toName: to,
      toLat: 30.09,
      toLng: 78.27,
      minFare: fare,
      taxiCount: count,
    );

Future<void> _pumpRail(WidgetTester t, List<TaxiPopularRoute> routes, {double w = 360, double s = 1, ValueChanged<TaxiPopularRoute>? onTap}) =>
    pumpJourney(
      t,
      Scaffold(body: ListView(children: [TaxiPopularRoutesRail(routes: routes, onTap: onTap ?? (_) {})])),
      width: w,
      scale: s,
      height: 800,
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  for (final w in [320.0, 360.0, 411.0]) {
    for (final s in [1.0, 1.3]) {
      testWidgets('0, 1 and 30 routes at ${w.toInt()} dp, text scale $s', (t) async {
        await _pumpRail(t, const [], w: w, s: s);
        expect(find.text('Popular routes'), findsNothing);
        await _pumpRail(t, [_route(0)], w: w, s: s);
        expect(find.text('Popular routes'), findsOneWidget);
        expect(find.text('Delhi → Rishikesh'), findsOneWidget);
        expect(find.text('From ₹899'), findsOneWidget);
        expect(find.text('9 taxis'), findsOneWidget);
        expect(t.takeException(), isNull);
        await _pumpRail(t, [for (var i = 0; i < 30; i++) _route(i, to: 'A long town name number $i in the hills')], w: w, s: s);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('no fare hides the fare line, one taxi is singular', (t) async {
    await _pumpRail(t, [_route(0, fare: null, count: 1)]);
    expect(find.textContaining('From '), findsNothing);
    expect(find.text('1 taxi'), findsOneWidget);
  });

  testWidgets('card semantics', (t) async {
    final h = t.ensureSemantics();
    await _pumpRail(t, [_route(0)]);
    expect(find.bySemanticsLabel('Delhi to Rishikesh, From ₹899, 9 taxis'), findsOneWidget);
    h.dispose();
  });

  testWidgets('tap on the tab fills From and To and opens results with the card date', (t) async {
    Get.reset();
    TaxiSeekerCache.clearMemory();
    (Get.put<LocationController>(JLoc()) as JLoc).userLocation.value = const LatLng(29.2, 79.5);
    Get.put<AuthController>(JAuth());
    Get.put<TabConfigController>(JTabs());
    Get.put(NearbyCentreController());
    final repo = FakeRepo()..popular = [_route(0)];
    final opened = <({PlaceResult? from, PlaceResult to, DateTime date})>[];
    final c = Get.put(
      TaxiListControllerV2(
        root: false,
        repo: repo,
        openResults: ({required PlaceResult? from, required bool fromNearYou, required PlaceResult to, required DateTime date, TaxiCityPair? cities}) {
          opened.add((from: from, to: to, date: date));
          return null;
        },
      ),
      tag: TaxiListControllerV2.tag,
    );
    await pumpJourney(t, const TaxiListScreenV2(root: false), width: 360, scale: 1, height: 1600);
    await flush(t);
    expect(find.text('Popular routes'), findsOneWidget);
    await t.tap(find.text('Delhi → Rishikesh'));
    await flush(t);
    expect(opened, hasLength(1));
    expect(opened.single.from?.name, 'Delhi');
    expect(opened.single.to.name, 'Rishikesh');
    expect(opened.single.date, c.date.value);
    expect(c.from.value?.name, 'Delhi');
    expect(c.to.value?.name, 'Rishikesh');
    expect(t.takeException(), isNull);
  });
}
