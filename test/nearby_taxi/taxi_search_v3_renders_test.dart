// Owner v3 renders for the mock compare (Option A search card, route card + Card 1).
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_journey_date.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_controller_v2.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_screen_v2.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_popular_routes.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_results_controller.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_results_screen.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_seeker_cache.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../support/real_phone.dart';
import 'fake_taxi_feed_repo.dart';
import 'fake_ways_repo.dart';

const _dir = r'F:\Dhasu\Buddy_resume\taxi_search_v3\shots';

TaxiFeedItem _taxi(String id, String name, {int fare = 899}) => TaxiFeedItem.fromJson({
      'id': id,
      'driverName': name,
      'vehicleTypeName': 'Innova',
      'plateDisplay': 'UK04',
      'routeCount': 2,
      'createdAt': '2026-11-01T00:00:00Z',
      'cityName': 'Haldwani',
      'stateName': 'Uttarakhand',
      'distanceKm': 5.0,
      'labelKey': 'near',
      'listedForRoute': true,
      'minFare': fare,
      'seats': 7,
    });

final _popular = [
  const TaxiPopularRoute(id: 'a', fromName: 'Delhi', fromLat: 28.61, fromLng: 77.21, toName: 'Rishikesh', toLat: 30.09, toLng: 78.27, minFare: 899, taxiCount: 9),
  const TaxiPopularRoute(id: 'b', fromName: 'Delhi', fromLat: 28.61, fromLng: 77.21, toName: 'Almora', toLat: 29.6, toLng: 79.66, minFare: 949, taxiCount: 6),
];

PlaceResult _p(String n, double lat, double lng) => PlaceResult(name: n, subtitle: '', latLng: LatLng(lat, lng));

void _base() {
  Get.reset();
  TaxiSeekerCache.clearMemory();
  final loc = Get.put<LocationController>(JLoc()) as JLoc;
  loc.userLocation.value = const LatLng(29.2, 79.5);
  loc.autoCity.value = CityModel(id: 'hld', districtId: 'd', name: 'Haldwani', latitude: 29.21, longitude: 79.51);
  Get.put<AuthController>(JAuth()).tabIndex.value = 3;
  Get.put<TabConfigController>(JTabs());
  Get.put(NearbyCentreController());
}

FakeRepo _repo({List<TaxiPopularRoute>? popular}) => FakeRepo()
  ..popular = popular ?? _popular
  ..localPage = (_) => NearbyPage(items: [_taxi('l1', 'Ramesh Kumar'), _taxi('l2', 'Sunil Negi')]);

Future<TaxiListControllerV2> _tab(WidgetTester t, FakeRepo repo, {bool toast = false}) async {
  final c = Get.put(TaxiListControllerV2(root: true, repo: repo), tag: TaxiListControllerV2.tag);
  await pumpPhone(t, const TaxiListScreenV2(root: true), toastHost: toast);
  await t.pump(const Duration(milliseconds: 400));
  return c;
}

Future<void> _results(WidgetTester t, FakeRepo repo, {DateTime? date}) async {
  Get.put(
    TaxiResultsController(
      args: TaxiResultsArgs(from: _p('Delhi', 28.61, 77.21), fromNearYou: false, to: _p('Rishikesh', 30.09, 78.27), date: date ?? TaxiJourneyDate.today()),
      repo: repo,
      waysRepo: FakeWaysRepo(answer: false),
    ),
    tag: TaxiResultsController.tag,
  );
  await pumpPhone(t, const TaxiResultsScreen());
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => shotsDir = _dir);
  tearDown(Get.reset);

  testWidgets('V3 search card: From is the city, Search on', (t) async {
    _base();
    await _tab(t, _repo());
    await settlePhone(t);
    expect(find.text('Haldwani'), findsOneWidget);
    expect(find.text('Near you'), findsNothing);
    expect(find.text('Taxis near Haldwani'), findsOneWidget);
    await shot(t, 'V3_search');
    expect(t.takeException(), isNull);
  });

  testWidgets('V3 search card: tapped Search with To empty', (t) async {
    _base();
    await _tab(t, _repo());
    await settlePhone(t);
    await t.tap(find.text('Search taxis'));
    await settlePhone(t);
    expect(find.text('Choose where you are going'), findsOneWidget);
    await shot(t, 'V3_error');
    expect(t.takeException(), isNull);
  });

  testWidgets('V3 results: route card + drivers', (t) async {
    _base();
    final repo = _repo()
      ..routeFeed = TaxiRouteFeed(freeCount: 9, tiers: [
        TaxiTier(key: TaxiTierKey.onRoute, items: [_taxi('r1', 'Pradeep Kumar'), _taxi('r2', 'Rakesh Singh', fare: 949)]),
      ]);
    await _results(t, repo);
    await settlePhone(t);
    expect(find.byType(TaxiRouteCard), findsOneWidget);
    await shot(t, 'V3_results');
    expect(t.takeException(), isNull);
  });
}
