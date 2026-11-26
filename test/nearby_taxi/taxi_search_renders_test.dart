import 'dart:async';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_date_sheet.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_journey_date.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_controller_v2.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_screen_v2.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_popular_routes.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_results_controller.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_results_screen.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_search_strings.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_seeker_cache.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../support/real_phone.dart';
import 'fake_taxi_feed_repo.dart';
import 'fake_ways_repo.dart';

const _dir = r'F:\Dhasu\Buddy_resume\taxi_availability\shots';

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
  (Get.put<LocationController>(JLoc()) as JLoc).userLocation.value = const LatLng(29.2, 79.5);
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

  testWidgets('S1 taxi tab, normal', (t) async {
    _base();
    final c = await _tab(t, _repo());
    c.setFrom(_p('Delhi', 28.61, 77.21));
    c.setTo(_p('Rishikesh', 30.09, 78.27));
    await settlePhone(t);
    await shot(t, 'S1');
    expect(t.takeException(), isNull);
  });

  testWidgets('S2 To empty', (t) async {
    _base();
    await _tab(t, _repo());
    await settlePhone(t);
    await shot(t, 'S2');
    expect(t.takeException(), isNull);
  });

  testWidgets('S3 same place', (t) async {
    _base();
    final c = await _tab(t, _repo(popular: const []), toast: true);
    c.setFrom(_p('Delhi', 28.61, 77.21));
    c.setTo(_p('Delhi', 28.61, 77.21));
    AppToast.warning(TaxiSearchStrings.samePlace);
    await settlePhone(t);
    await shot(t, 'S3');
    expect(t.takeException(), isNull);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('S4 date sheet', (t) async {
    _base();
    await _tab(t, _repo());
    final ctx = t.element(find.byType(TaxiListScreenV2));
    unawaited(TaxiDateSheet.pick(ctx, initial: TaxiJourneyDate.today()));
    await t.pump();
    await settlePhone(t);
    await shot(t, 'S4');
    expect(t.takeException(), isNull);
  });

  testWidgets('S5 results', (t) async {
    _base();
    final repo = _repo()
      ..routeFeed = TaxiRouteFeed(freeCount: 9, tiers: [
        TaxiTier(key: TaxiTierKey.onRoute, items: [_taxi('r1', 'Pradeep Kumar'), _taxi('r2', 'Rakesh Singh', fare: 949)]),
      ]);
    await _results(t, repo);
    await settlePhone(t);
    await shot(t, 'S5');
    expect(t.takeException(), isNull);
  });

  testWidgets('S6 loading', (t) async {
    _base();
    final repo = _repo()..gateRoutes = true;
    await _results(t, repo);
    await shot(t, 'S6_loading');
    repo.routeGates.single.complete(const TaxiRouteFeed());
    await settlePhone(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('S6 empty', (t) async {
    _base();
    final repo = _repo()..routeFeed = const TaxiRouteFeed();
    await _results(t, repo, date: TaxiJourneyDate.addDays(TaxiJourneyDate.today(), 1));
    await settlePhone(t);
    await shot(t, 'S6_empty');
    expect(t.takeException(), isNull);
  });

  testWidgets('S6 error', (t) async {
    _base();
    final repo = _repo()..routeError = StateError('offline');
    await _results(t, repo);
    await settlePhone(t);
    await shot(t, 'S6_error');
    expect(t.takeException(), isNull);
  });
}
