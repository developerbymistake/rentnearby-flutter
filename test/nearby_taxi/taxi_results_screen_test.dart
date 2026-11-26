import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
import 'package:bakhli/features/taxi/guest/taxi_card.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_journey_date.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_results_controller.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_results_screen.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_search_strings.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_seeker_cache.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../ui_golden/golden_support.dart';
import 'fake_taxi_feed_repo.dart';
import 'fake_ways_repo.dart';

TaxiFeedItem _taxi(String id) => TaxiFeedItem.fromJson({
      'id': id,
      'driverName': 'Driver $id',
      'vehicleTypeName': 'Sedan',
      'plateDisplay': 'UK04',
      'routeCount': 2,
      'createdAt': '2026-11-01T00:00:00Z',
      'cityName': 'Haldwani',
      'stateName': 'Uttarakhand',
      'distanceKm': 5.0,
      'labelKey': 'near',
      'listedForRoute': true,
      'minFare': 900,
    });

TaxiRouteFeed _feed(int n, {int? free}) => TaxiRouteFeed(
      freeCount: free,
      tiers: [TaxiTier(key: TaxiTierKey.onRoute, items: [for (var i = 0; i < n; i++) _taxi('t$i')])],
    );

late FakeRepo _repo;
late TaxiResultsController _ctrl;

void _env() {
  Get.reset();
  TaxiSeekerCache.clearMemory();
  (Get.put<LocationController>(JLoc()) as JLoc).userLocation.value = const LatLng(29.2, 79.5);
  Get.put<AuthController>(JAuth());
  Get.put<TabConfigController>(JTabs());
  Get.put(NearbyCentreController());
  _repo = FakeRepo();
}

// The controller loads in onInit, so the fake must be arranged before it is put.
void _setUp({DateTime? date, void Function(FakeRepo r)? arrange}) {
  _env();
  arrange?.call(_repo);
  _ctrl = Get.put(
    TaxiResultsController(
      args: TaxiResultsArgs(
        from: PlaceResult(name: 'Delhi', subtitle: '', latLng: const LatLng(28.6, 77.2)),
        fromNearYou: false,
        to: PlaceResult(name: 'Rishikesh', subtitle: '', latLng: const LatLng(30.1, 78.3)),
        date: date ?? TaxiJourneyDate.today(),
      ),
      repo: _repo,
      waysRepo: FakeWaysRepo(answer: false),
    ),
    tag: TaxiResultsController.tag,
  );
}

Future<void> _open(WidgetTester t, {double w = 360, double s = 1}) =>
    pumpJourney(t, const TaxiResultsScreen(), width: w, scale: s, height: 1600);

Future<void> _settle(WidgetTester t) async {
  await flush(t);
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  for (final w in [320.0, 360.0, 411.0]) {
    for (final s in [1.0, 1.3]) {
      for (final n in [0, 1, 6]) {
        testWidgets('$n rows fit at ${w.toInt()} dp, text scale $s', (t) async {
          _setUp(arrange: (r) => r.routeFeed = _feed(n, free: n));
          await _open(t, w: w, s: s);
          await _settle(t);
          expect(t.takeException(), isNull);
          expect(find.text('Taxi'), findsOneWidget);
          expect(find.text('Taxis for your route'), findsOneWidget);
          if (n == 0) {
            expect(find.text(TaxiSearchStrings.emptyTitle(TaxiJourneyDate.today())), findsOneWidget);
            expect(find.text('Nearest'), findsNothing);
          } else {
            expect(find.text('Drivers on this route'), findsOneWidget);
            expect(find.text(TaxiSearchStrings.freeCount(n, TaxiJourneyDate.today())), findsOneWidget);
          }
        });
      }
    }
  }

  testWidgets('loading shows skeletons with the date bar and sort row', (t) async {
    _setUp(arrange: (r) => r.gateRoutes = true);
    await _open(t);
    expect(find.byType(TaxiCardSkeleton), findsWidgets);
    expect(find.text(TaxiSearchStrings.barText(TaxiJourneyDate.today(), isToday: true)), findsOneWidget);
    expect(find.text('Nearest'), findsOneWidget);
    expect(find.text('Cheapest'), findsOneWidget);
    _repo.routeGates.single.complete(_feed(1));
    await _settle(t);
    expect(find.byType(TaxiCardSkeleton), findsNothing);
  });

  testWidgets('error with Try again, date bar and sort hidden', (t) async {
    _setUp(arrange: (r) => r.routeError = StateError('offline'));
    await _open(t);
    await _settle(t);
    expect(find.text('Could not load taxis'), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(find.text('Nearest'), findsNothing);
    expect(find.text(TaxiSearchStrings.barText(TaxiJourneyDate.today(), isToday: true)), findsNothing);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget, reason: 'only the top bar back button');
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    _repo.routeError = null;
    _repo.routeFeed = _feed(2, free: 2);
    await t.tap(find.text('Try again'));
    await _settle(t);
    expect(find.text('Driver t1'), findsOneWidget);
  });

  testWidgets('previous is off on today, next off on day 90', (t) async {
    VoidCallback? arrow(IconData icon) =>
        t.widget<Tap3D>(find.ancestor(of: find.byIcon(icon), matching: find.byType(Tap3D)).first).onTap;
    _setUp(arrange: (r) => r.routeFeed = _feed(1));
    await _open(t);
    await _settle(t);
    expect(_ctrl.canPrev, isFalse);
    expect(arrow(Icons.chevron_left_rounded), isNull);
    expect(arrow(Icons.chevron_right_rounded), isNotNull);
    await t.pumpWidget(const SizedBox());
    _setUp(date: TaxiJourneyDate.last(TaxiJourneyDate.today()), arrange: (r) => r.routeFeed = _feed(1));
    await _open(t);
    await _settle(t);
    expect(arrow(Icons.chevron_right_rounded), isNull);
    expect(arrow(Icons.chevron_left_rounded), isNotNull);
  });

  testWidgets('next day moves the bar and reloads after the debounce', (t) async {
    _setUp(arrange: (r) => r.routeFeed = _feed(1));
    await _open(t);
    await _settle(t);
    final tomorrow = TaxiJourneyDate.addDays(TaxiJourneyDate.today(), 1);
    await t.tap(find.byIcon(Icons.chevron_right_rounded));
    await t.pump();
    expect(find.text(TaxiSearchStrings.dayText(tomorrow)), findsOneWidget);
    await t.pump(const Duration(milliseconds: 300));
    await _settle(t);
    expect(_repo.routeCalls.last.date, TaxiJourneyDate.apiText(tomorrow));
  });

  testWidgets('no count line when only nearby tiers have taxis', (t) async {
    _setUp(arrange: (r) => r.routeFeed = TaxiRouteFeed(freeCount: 0, tiers: [TaxiTier(key: TaxiTierKey.basedNearFrom, items: [_taxi('n')])]));
    await _open(t);
    await _settle(t);
    expect(find.text('More drivers nearby'), findsOneWidget);
    expect(find.textContaining('free on'), findsNothing);
  });

  testWidgets('cards show Call and WhatsApp and never Ask or Enquiry', (t) async {
    _setUp(arrange: (r) => r.routeFeed = _feed(2, free: 2));
    await _open(t);
    await _settle(t);
    expect(find.text('Call'), findsWidgets);
    expect(find.text('WhatsApp'), findsWidgets);
    expect(find.text('Ask'), findsNothing);
    expect(find.text('Enquiry'), findsNothing);
  });

  testWidgets('sort chips switch to Cheapest', (t) async {
    _setUp(arrange: (r) => r.routeFeed = _feed(1));
    await _open(t);
    await _settle(t);
    expect(_repo.routeCalls.single.sort, 'nearest');
    await t.tap(find.text('Cheapest'));
    await t.pump(const Duration(milliseconds: 300));
    await _settle(t);
    expect(_repo.routeCalls.last.sort, 'cheapest');
  });

  testWidgets('a second search during the pop gets its own controller', (t) async {
    _env();
    _repo.routeFeed = _feed(0);
    final made = <TaxiResultsController>[];
    final original = TaxiResultsScreen.create;
    addTearDown(() => TaxiResultsScreen.create = original);
    TaxiResultsScreen.create = (a) {
      final c = TaxiResultsController(args: a, repo: _repo, waysRepo: FakeWaysRepo(answer: false));
      made.add(c);
      return c;
    };
    Map<String, dynamic> args(String to, double lat) => TaxiResultsArgs(
          from: PlaceResult(name: 'Delhi', subtitle: '', latLng: const LatLng(28.6, 77.2)),
          fromNearYou: false,
          to: PlaceResult(name: to, subtitle: '', latLng: LatLng(lat, 78.3)),
          date: TaxiJourneyDate.today(),
        ).toMap();
    setGoldenView(t, const Size(360, 1600));
    await t.pumpWidget(GetMaterialApp(theme: ThemeData(fontFamily: 'WorkSans'), home: const SizedBox()));
    Get.to<void>(() => const TaxiResultsScreen(), arguments: args('Rishikesh', 30.1));
    await _settle(t);
    await t.pump(const Duration(milliseconds: 700));
    expect(made.single.to.name, 'Rishikesh');
    Get.back<void>();
    await t.pump(const Duration(milliseconds: 50));
    Get.to<void>(() => const TaxiResultsScreen(), arguments: args('Haridwar', 29.9));
    await t.pump(const Duration(milliseconds: 50));
    expect(made, hasLength(2));
    expect(made.last.to.name, 'Haridwar');
    expect(made.first.isClosed, isFalse, reason: 'the page animating out keeps its own controller');
    expect(made.last.initialized, isTrue);
    await t.pump(const Duration(seconds: 1));
    await _settle(t);
    expect(t.takeException(), isNull);
    expect(made.first.isClosed, isTrue, reason: 'closed by its own page once that page is gone');
    expect(made.last.isClosed, isFalse);
    expect(made.last.isLoading.value, isFalse);
    expect(made.last.route.value, isNotNull);
    expect(_repo.routeCalls.map((c) => c.toLat), [30.1, 29.9]);
    expect(find.text('Haridwar'), findsOneWidget);
    expect(find.text('Rishikesh'), findsNothing);
    await t.pumpWidget(const SizedBox());
    expect(made.last.isClosed, isTrue);
  });
}
