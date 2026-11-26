import 'dart:async';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/taxi/guest/taxi_browse_repository.dart';
import 'package:bakhli/features/taxi/guest/taxi_card.dart';
import 'package:bakhli/features/taxi/guest/taxi_list_controller.dart';
import 'package:bakhli/features/taxi/guest/taxi_list_screen.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_availability.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_strings.dart';
import 'package:bakhli/features/taxi/ways/widgets/taxi_ways_entry_card.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import 'fake_ways_repo.dart';

TaxiBrowseItem _item(String id) => TaxiBrowseItem(
      id: id,
      driverName: 'Driver $id',
      vehicleTypeName: 'Sedan',
      plateDisplay: '',
      routeCount: 1,
      matchReversed: false,
      createdAt: DateTime(2026),
    );

class _Browse extends TaxiBrowseRepository {
  List<TaxiBrowseItem> items = const [];
  final searches = <({double fromLat, double toLat, DateTime date})>[];

  @override
  Future<TaxiBrowsePage> search({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required DateTime date,
    String? category,
    int page = 1,
    int pageSize = 20,
  }) {
    searches.add((fromLat: fromLat, toLat: toLat, date: date));
    return Future.value((items: items, hasMore: false));
  }
}

PlaceResult _place(String n, double lat) => PlaceResult(name: n, subtitle: '', latLng: LatLng(lat, 79.5));

final _from = _place('Haldwani', 29.2);
final _to = _place('Almora', 29.6);

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

late _Browse _browse;
late FakeWaysRepo _ways;

void _setUp({bool answer = true}) {
  Get.reset();
  Get.put<LocationController>(JLoc());
  Get.put<AuthController>(JAuth());
  Get.put<TabConfigController>(JTabs());
  _browse = _Browse();
  _ways = FakeWaysRepo(answer: answer);
}

TaxiListController _put({PlaceResult? to, DateTime Function()? now}) => Get.put(
      TaxiListController(
        preset: TaxiPreset(from: _from, to: to ?? _to),
        waysRepo: _ways,
        browseRepo: _browse,
        now: now,
      ),
      tag: TaxiListController.pushTag,
    );

void main() {
  tearDown(Get.reset);

  group('controller', () {
    test('a route search asks once with the same From, To and my-location flag', () async {
      _setUp();
      final c = _put();
      await _settle();
      expect(_ways.calls, hasLength(1));
      expect(_ways.calls.single.fromLat, _from.latLng.latitude);
      expect(_ways.calls.single.toLat, _to.latLng.latitude);
      expect(_ways.calls.single.fromMyLocation, c.fromIsCurrent.value);
      expect(_browse.searches, hasLength(1));
    });

    test('the list is for IST today: 20:00 UTC on 26 Nov asks for 27 Nov', () async {
      _setUp();
      _put(now: () => DateTime.utc(2026, 11, 26, 20));
      await _settle();
      expect(_browse.searches.single.date, DateTime(2026, 11, 27));
    });

    test('a refresh on a new IST day asks for that day', () async {
      _setUp();
      var now = DateTime.utc(2026, 11, 26, 10);
      final c = _put(now: () => now);
      await _settle();
      now = DateTime.utc(2026, 11, 27, 10);
      await c.pullRefresh();
      expect(_browse.searches.map((s) => s.date), [DateTime(2026, 11, 26), DateTime(2026, 11, 27)]);
    });

    test('a way exists gives available', () async {
      _setUp(answer: true);
      final c = _put();
      await _settle();
      expect(c.waysCheck.state.value, WaysAvailability.available);
      expect(c.waysCheck.isAvailable, isTrue);
    });

    test('no way gives not available', () async {
      _setUp(answer: false);
      final c = _put();
      await _settle();
      expect(c.waysCheck.state.value, WaysAvailability.unavailable);
      expect(c.waysCheck.isAvailable, isFalse);
    });

    test('a failed check is never available', () async {
      _setUp();
      _ways.error = StateError('503');
      final c = _put();
      await _settle();
      expect(c.waysCheck.state.value, WaysAvailability.failed);
      expect(c.waysCheck.isAvailable, isFalse);
    });

    test('changing To goes back to loading and drops the old answer', () async {
      _setUp();
      _ways.manual = true;
      final c = _put();
      await _settle();
      expect(c.waysCheck.state.value, WaysAvailability.loading);
      c.applyPreset(TaxiPreset(from: _from, to: _place('Nainital', 29.4)));
      await _settle();
      expect(_ways.calls, hasLength(2));
      expect(c.waysCheck.state.value, WaysAvailability.loading);
      _ways.pending.first.complete(true);
      await _settle();
      expect(c.waysCheck.state.value, WaysAvailability.loading);
      _ways.pending.last.complete(false);
      await _settle();
      expect(c.waysCheck.state.value, WaysAvailability.unavailable);
    });

    test('clearing To resets to idle and asks nothing more', () async {
      _setUp();
      final c = _put();
      await _settle();
      expect(c.waysCheck.isAvailable, isTrue);
      c.clearTo();
      await _settle();
      expect(c.waysCheck.state.value, WaysAvailability.idle);
      expect(_ways.calls, hasLength(1));
    });

    test('closing the list resets to idle', () async {
      _setUp();
      final c = _put();
      await _settle();
      expect(c.waysCheck.isAvailable, isTrue);
      Get.delete<TaxiListController>(tag: TaxiListController.pushTag);
      expect(c.waysCheck.state.value, WaysAvailability.idle);
    });
  });

  group('screen', () {
    Future<void> open(WidgetTester t) => pumpJourney(t, const TaxiListScreen(), width: 360, scale: 1);

    testWidgets('no route taxis: skeleton while the check loads, never No taxis yet first', (t) async {
      _setUp();
      _ways.manual = true;
      _put();
      await open(t);
      expect(find.byType(TaxiCardSkeleton), findsWidgets);
      expect(find.text('No taxis yet'), findsNothing);
      expect(find.byType(TaxiWaysEntryCard), findsNothing);
      _ways.pending.single.complete(true);
      await flush(t);
      expect(find.text('No taxis yet'), findsNothing);
      expect(find.byType(TaxiWaysEntryCard), findsOneWidget);
      expect(t.widget<TaxiWaysEntryCard>(find.byType(TaxiWaysEntryCard)).empty, isTrue);
      expect(find.text(TaxiWaysStrings.entryEmptyTitle), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('no route taxis and no way: the empty state, no card', (t) async {
      _setUp();
      _ways.manual = true;
      _put();
      await open(t);
      _ways.pending.single.complete(false);
      await flush(t);
      expect(find.text('No taxis yet'), findsOneWidget);
      expect(find.byType(TaxiWaysEntryCard), findsNothing);
    });

    testWidgets('no route taxis and a failed check: the empty state, no card', (t) async {
      _setUp();
      _ways.error = StateError('503');
      _put();
      await open(t);
      expect(find.text('No taxis yet'), findsOneWidget);
      expect(find.byType(TaxiWaysEntryCard), findsNothing);
    });

    testWidgets('route taxis listed: card hidden while loading, then the normal card', (t) async {
      _setUp();
      _ways.manual = true;
      _browse.items = [_item('a')];
      _put();
      await open(t);
      expect(find.text('Driver a'), findsOneWidget);
      expect(find.byType(TaxiWaysEntryCard), findsNothing);
      _ways.pending.single.complete(true);
      await flush(t);
      expect(find.byType(TaxiWaysEntryCard), findsOneWidget);
      expect(t.widget<TaxiWaysEntryCard>(find.byType(TaxiWaysEntryCard)).empty, isFalse);
      expect(find.text(TaxiWaysStrings.entryTitle), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('route taxis listed and no way: no card', (t) async {
      _setUp(answer: false);
      _browse.items = [_item('a')];
      _put();
      await open(t);
      expect(find.text('Driver a'), findsOneWidget);
      expect(find.byType(TaxiWaysEntryCard), findsNothing);
    });
  });
}
