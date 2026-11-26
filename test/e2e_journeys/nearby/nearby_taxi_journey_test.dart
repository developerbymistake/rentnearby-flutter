import 'dart:io';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_controller_v2.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_screen_v2.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_journey_date.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_popular_routes.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_results_controller.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_results_screen.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_search_strings.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_seeker_cache.dart';
import 'package:bakhli/features/taxi/setup/taxi_rate_rules.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_strings.dart';
import 'package:bakhli/features/taxi/ways/widgets/taxi_ways_entry_card.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../nearby_taxi/fake_ways_repo.dart';
import '../../ui_golden/golden_support.dart';
import 'nearby_support.dart';

Map<String, dynamic> _taxi(String id, {double? km, String label = 'near', String city = 'Haldwani', bool route = false}) => {
      'id': id,
      'driverName': 'Driver $id',
      'vehicleTypeName': 'Sedan',
      'plateDisplay': 'UK04',
      'routeCount': 2,
      'createdAt': '2026-11-01T00:00:00Z',
      'cityName': city,
      'stateName': 'Uttarakhand',
      'distanceKm': ?km,
      'labelKey': label,
      'listedForRoute': route,
      'minFare': 900,
    };

TaxiFeedItem _fi(String id, {double? km, String label = 'near', String city = 'Haldwani', bool route = false}) =>
    TaxiFeedItem.fromJson(_taxi(id, km: km, label: label, city: city, route: route));

TaxiTier _tier(String key, List<TaxiFeedItem> items, {String? city}) => TaxiTier(
      key: key,
      headerKey: key,
      items: items,
      header: city == null ? null : NearbyHeader(centreCityName: city),
    );

class _Repo extends TaxiFeedRepository {
  NearbyPage<TaxiFeedItem> page = const NearbyPage();
  TaxiRouteFeed feed = const TaxiRouteFeed();
  final centres = <double>[];

  @override
  Future<List<TaxiPopularRoute>> popularRoutes() async => const [];

  @override
  Future<NearbyPage<TaxiFeedItem>> local({required double lat, required double lng, String? pageToken, int pageSize = 20, String? category, String? date}) async {
    centres.add(lat);
    return page;
  }

  @override
  Future<TaxiRouteFeed> route({required double fromLat, required double fromLng, required double toLat, required double toLng, String? category, String? date, String sort = 'nearest', TaxiCityPair? cities}) async => feed;
}

PlaceResult _place(String n, double lat, double lng) => PlaceResult(name: n, subtitle: '', latLng: LatLng(lat, lng));

late _Repo _repo;
late FakeWaysRepo _ways;
late TaxiListControllerV2 _ctrl;
late JLoc _loc;

void _setUpApp({LatLng gps = const LatLng(29.2, 79.5), bool waysAvailable = false}) {
  Get.reset();
  _loc = Get.put<LocationController>(JLoc()) as JLoc;
  _loc.userLocation.value = gps;
  Get.put<AuthController>(JAuth());
  Get.put<TabConfigController>(JTabs());
  Get.put(NearbyCentreController());
  _repo = _Repo();
  _ways = FakeWaysRepo(answer: waysAvailable);
  _ctrl = Get.put(TaxiListControllerV2(root: false, repo: _repo), tag: TaxiListControllerV2.tag);
  TaxiSeekerCache.clearMemory();
}

Future<void> _open(WidgetTester t, {double w = 360, double s = 1}) {
  _ctrl.retry();
  return pumpJourney(t, const TaxiListScreenV2(root: false), width: w, scale: s);
}

Future<void> _openResults(WidgetTester t, {PlaceResult? from, required PlaceResult to, double w = 360, double s = 1}) {
  Get.put(
    TaxiResultsController(
      args: TaxiResultsArgs(
        from: from ?? _place('Near you', 29.2, 79.5),
        fromNearYou: from == null,
        to: to,
        date: TaxiJourneyDate.today(),
      ),
      repo: _repo,
      waysRepo: _ways,
    ),
    tag: TaxiResultsController.tag,
  );
  return pumpJourney(t, const TaxiResultsScreen(), width: w, scale: s);
}

Future<void> _settle(WidgetTester t) async {
  await flush(t);
  await t.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  testWidgets('local list: driver base shown as based near, distance in whole steps', (t) async {
    _setUpApp();
    _repo.page = NearbyPage(items: [_fi('a', km: 5), _fi('b', km: 25, label: 'far', city: 'Nainital')]);
    await _open(t);
    expect(find.text('Taxis near you'), findsNWidgets(2));
    expect(find.text('Haldwani. About 5 km'), findsOneWidget);
    expect(find.text('Nainital. About 25 km'), findsOneWidget);
    expect(find.textContaining('By road it can take longer.'), findsNothing);
    expect(find.textContaining('Ask for a price'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('a far user sees nearest taxis, never near you', (t) async {
    _setUpApp(gps: const LatLng(28.6, 77.2));
    _repo.page = NearbyPage(
      header: const NearbyHeader(farAway: true),
      items: [_fi('a', km: 210, label: 'far', city: 'Haridwar')],
    );
    await _open(t);
    expect(find.text('Nearest taxis'), findsOneWidget);
    expect(find.text('Haridwar. About 210 km'), findsOneWidget);
    expect(find.textContaining('near you'), findsNothing);
  });

  testWidgets('From and To: every layer is titled so a based-near driver never reads as on the route', (t) async {
    _setUpApp();
    _repo.feed = TaxiRouteFeed(tiers: [
      _tier(TaxiTierKey.onRoute, [_fi('r', route: true)]),
      _tier(TaxiTierKey.passing, [_fi('p', km: 10, city: 'Kathgodam')]),
      _tier(TaxiTierKey.basedNearFrom, [_fi('f', km: 5, label: 'near')], city: 'Haldwani'),
      _tier(TaxiTierKey.inTo, [_fi('i', km: 15, label: 'far', city: 'Nainital')], city: 'Nainital'),
    ]);
    await _openResults(t, from: _place('Haldwani', 29.2, 79.5), to: _place('Nainital', 29.4, 79.45));
    await _settle(t);
    expect(find.text('Drivers on this route'), findsOneWidget);
    expect(find.text('Drivers passing your area'), findsOneWidget);
    expect(find.text('More drivers nearby'), findsOneWidget);
    expect(find.text('Taxis in Nainital'), findsOneWidget);
    expect(find.text('Driver r'), findsOneWidget);
    expect(find.text('Driver f'), findsOneWidget);
    expect(find.text('No driver is listed on this route yet.'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('From and To with only based-near drivers still gives a useful list', (t) async {
    _setUpApp();
    _repo.feed = TaxiRouteFeed(tiers: [
      _tier(TaxiTierKey.onRoute, const []),
      _tier(TaxiTierKey.basedNearFrom, [_fi('f', km: 5)], city: 'Haldwani'),
    ]);
    await _openResults(t, to: _place('Mussoorie', 30.45, 78.07));
    await _settle(t);
    expect(find.text('Drivers on this route'), findsNothing);
    expect(find.text('More drivers nearby'), findsOneWidget);
    expect(find.text('Driver f'), findsOneWidget);
  });

  testWidgets('From and To with nothing anywhere: no taxi is free on the day', (t) async {
    _setUpApp();
    _repo.feed = const TaxiRouteFeed();
    await _openResults(t, to: _place('Mussoorie', 30.45, 78.07));
    await _settle(t);
    expect(find.text(TaxiSearchStrings.emptyTitle(TaxiJourneyDate.today())), findsOneWidget);
    expect(find.text('Try another day or another place.'), findsOneWidget);
    expect(find.text('Drivers on this route'), findsNothing);
    expect(t.takeException(), isNull);
  });

  group('ways entry card', () {
    TaxiRouteFeed routeAndLocal() => TaxiRouteFeed(tiers: [
          _tier(TaxiTierKey.onRoute, [_fi('r', route: true)]),
          _tier(TaxiTierKey.basedNearFrom, [_fi('f', km: 5)], city: 'Haldwani'),
        ]);
    TaxiRouteFeed localOnly() => TaxiRouteFeed(tiers: [
          _tier(TaxiTierKey.onRoute, const []),
          _tier(TaxiTierKey.passing, const []),
          _tier(TaxiTierKey.basedNearFrom, [_fi('f', km: 5)], city: 'Haldwani'),
          _tier(TaxiTierKey.inTo, [_fi('i', km: 15, label: 'far', city: 'Almora')], city: 'Almora'),
        ]);

    testWidgets('shown when a way exists, with route drivers it is the normal card, builds never refetch', (t) async {
      _setUpApp(waysAvailable: true);
      _repo.feed = routeAndLocal();
      await _openResults(t, to: _place('Almora', 29.6, 79.66));
      await _settle(t);
      expect(find.byType(TaxiWaysEntryCard), findsOneWidget);
      expect(t.widget<TaxiWaysEntryCard>(find.byType(TaxiWaysEntryCard)).empty, isFalse);
      expect(find.text(TaxiWaysStrings.entryTitle), findsOneWidget);
      await _settle(t);
      await _settle(t);
      expect(_ways.calls, hasLength(1));
      expect(t.takeException(), isNull);
    });

    testWidgets('local taxis are not route drivers: a way exists gives the empty variant', (t) async {
      _setUpApp(waysAvailable: true);
      _repo.feed = localOnly();
      await _openResults(t, to: _place('Almora', 29.6, 79.66));
      await _settle(t);
      expect(find.text('More drivers nearby'), findsOneWidget);
      expect(t.widget<TaxiWaysEntryCard>(find.byType(TaxiWaysEntryCard)).empty, isTrue);
      expect(find.text(TaxiWaysStrings.entryEmptyTitle), findsOneWidget);
      expect(find.text(TaxiWaysStrings.entryTitle), findsNothing);
    });

    testWidgets('hidden when no way exists, even with local taxis listed', (t) async {
      _setUpApp(waysAvailable: false);
      _repo.feed = localOnly();
      await _openResults(t, to: _place('Almora', 29.6, 79.66));
      await _settle(t);
      expect(find.text('More drivers nearby'), findsOneWidget);
      expect(find.byType(TaxiWaysEntryCard), findsNothing);
      expect(find.text(TaxiWaysStrings.entryTitle), findsNothing);
    });

    testWidgets('hidden when the check fails', (t) async {
      _setUpApp(waysAvailable: true);
      _ways.error = StateError('503');
      _repo.feed = routeAndLocal();
      await _openResults(t, to: _place('Almora', 29.6, 79.66));
      await _settle(t);
      expect(find.text('Drivers on this route'), findsOneWidget);
      expect(find.byType(TaxiWaysEntryCard), findsNothing);
    });

    testWidgets('nothing while the check is loading, then the card simply appears', (t) async {
      _setUpApp(waysAvailable: true);
      _ways.manual = true;
      _repo.feed = routeAndLocal();
      await _openResults(t, to: _place('Almora', 29.6, 79.66));
      await _settle(t);
      expect(find.text('Drivers on this route'), findsOneWidget);
      expect(find.byType(TaxiWaysEntryCard), findsNothing);
      _ways.pending.last.complete(true);
      await _settle(t);
      expect(find.byType(TaxiWaysEntryCard), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a new search never shows the old answer', (t) async {
      _setUpApp(waysAvailable: true);
      _repo.feed = routeAndLocal();
      await _openResults(t, to: _place('Almora', 29.6, 79.66));
      await _settle(t);
      expect(find.byType(TaxiWaysEntryCard), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      _ways.manual = true;
      await _openResults(t, to: _place('Nainital', 29.4, 79.45));
      await _settle(t);
      expect(find.byType(TaxiWaysEntryCard), findsNothing);
      _ways.pending.last.complete(false);
      await _settle(t);
      expect(find.byType(TaxiWaysEntryCard), findsNothing);
      expect(_ways.calls.last.toLat, 29.4);
    });

    for (final w in journeyWidths) {
      for (final s in journeyScales) {
        testWidgets('card fits at ${w.toInt()} dp, text scale $s', (t) async {
          _setUpApp(waysAvailable: true);
          _repo.feed = localOnly();
          await _openResults(t, to: _place('Another very long destination name', 29.6, 79.66), w: w, s: s);
          await _settle(t);
          expect(find.byType(TaxiWaysEntryCard), findsOneWidget);
          expect(t.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('Photon pin moves the local list centre', (t) async {
    _setUpApp();
    _repo.page = NearbyPage(items: [_fi('a', km: 5)]);
    await _open(t);
    expect(_repo.centres.last, 29.2);
    NearbyCentreController.to.setPin(const LatLng(31.1, 77.17), 'Shimla');
    await _settle(t);
    expect(_repo.centres.last, 31.1);
    expect(find.text('Shimla'), findsOneWidget);
    expect(find.textContaining('Showing near'), findsNothing);
    expect(find.text('Search any place'), findsNothing);
  });

  testWidgets('whole system empty is the only empty state', (t) async {
    _setUpApp();
    await _open(t);
    expect(find.text('No taxis listed yet'), findsOneWidget);
  });

  for (final w in journeyWidths) {
    for (final s in journeyScales) {
      testWidgets('layers fit at ${w.toInt()} dp, text scale $s', (t) async {
        _setUpApp();
        _repo.feed = TaxiRouteFeed(tiers: [
          _tier(TaxiTierKey.onRoute, [_fi('r', route: true)]),
          _tier(TaxiTierKey.passing, [_fi('p', km: 10, city: 'A very long city name here')]),
          _tier(TaxiTierKey.basedNearFrom, [_fi('f', km: 5)], city: 'Haldwani'),
          _tier(TaxiTierKey.inTo, [_fi('i', km: 15, label: 'far', city: 'Nainital')], city: 'Nainital'),
        ]);
        await _openResults(t, from: _place('A very long place name in the hills', 29.2, 79.5), to: _place('Another very long destination name', 29.4, 79.45), w: w, s: s);
        await _settle(t);
        expect(find.text('Drivers on this route'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }

  group('driver onboarding rate is compulsory', () {
    test('empty or out of range rate and km are rejected', () {
      expect(TaxiRateRules.validate('', ''), isNotNull);
      expect(TaxiRateRules.validate('', '120'), isNotNull);
      expect(TaxiRateRules.validate('2500', ''), isNotNull);
      expect(TaxiRateRules.validate('50', '120'), isNotNull);
      expect(TaxiRateRules.validate('2500', '0'), isNotNull);
      expect(TaxiRateRules.validate('2500', '120'), isNull);
      expect(TaxiRateRules.done(), isFalse);
    });

    test('the form validates through the rules and offers no way to skip', () {
      final form = File('lib/features/taxi/setup/taxi_rate_form.dart').readAsStringSync();
      expect(form.contains('TaxiRateRules.validate'), isTrue);
      for (final word in ['(optional)', 'ask for a price', 'skip', 'add later']) {
        expect(form.toLowerCase().contains(word), isFalse, reason: word);
      }
      final wizard = File('lib/features/taxi/setup/taxi_vehicle_screen.dart').readAsStringSync();
      final submit = wizard.substring(wizard.indexOf('Future<void> _submit()'));
      final check = submit.indexOf('_rate.check()');
      expect(check, isNonNegative);
      expect(check, lessThan(submit.indexOf('saveLocalRate')));
      expect(submit.substring(check, submit.indexOf('saveLocalRate')).contains('return;'), isTrue);
      expect(wizard.contains('(optional)'), isFalse);
      expect(wizard.toLowerCase().contains('ask for a price'), isFalse);
    });

    test('no screen anywhere says Ask for a price', () {
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        expect(f.readAsStringSync().contains('Ask for a price'), isFalse, reason: f.path);
      }
    });
  });
}
