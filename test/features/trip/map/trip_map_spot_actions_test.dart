import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/trip_map_spot_actions.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/trip_constants.dart';
import 'package:bakhli/features/trip/trip_strings_v2_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/real_phone.dart';

TripSpotRef _ref(String id) => TripSpotRef(id: id, name: id, latitude: 31.1, longitude: 77.1, category: 'temple', visitMinutes: 45, imageUrl: 'https://x/$id.jpg');

TripPlan _plan({int day1 = 2}) => TripPlan(
      legs: const [
        TripCityLeg(index: 1, cityKey: 10, cityName: 'Hill Town', latitude: 31.1, longitude: 77.1),
        TripCityLeg(index: 2, cityKey: 20, cityName: 'Lake Town', latitude: 30.1, longitude: 78.1),
      ],
      days: [
        TripDay(day: 1, leg: 1, spots: [for (var i = 0; i < day1; i++) _ref('p$i')]),
        const TripDay(day: 2, leg: 1),
        const TripDay(day: 3, leg: 2),
      ],
    );

const _hill = DiscoverySpot(id: 'n1', lat: 31.1, lon: 77.17, category: 'temple', rank: 4, name: 'Jakhoo Temple', cityKey: 10, thumbUrl: 'https://x/image/upload/a.jpg');
const _lake = DiscoverySpot(id: 'n2', lat: 30.1, lon: 78.1, category: 'lake', rank: 9, name: 'Lake', cityKey: 20);
const _away = DiscoverySpot(id: 'n3', lat: 30.1, lon: 78.1, category: 'lake', rank: 9, name: 'Away', cityKey: 99);

class _Rig {
  TripPlan? plan;
  int selected;
  final added = <({List<TripSpotModel> spots, int? leg, int? day})>[];
  final removed = <String>[];
  final inserted = <({TripSpotRef ref, int day, int index})>[];
  final sheets = <({TripSpotModel spot, bool selected, bool locked, bool hasToggle, int? cityKey, String? version, bool partial})>[];
  bool addResult = true;
  bool removeSticks = false;
  Map<int, List<TripSpotModel>> cache = {};
  BuildContext? ctx;

  _Rig(this.plan, {this.selected = TripPlanController.mapAll});

  TripMapSpotActions build() => TripMapSpotActions(
        plan: () => plan,
        selectedDay: () => selected,
        addSpots: (spots, {legIndex, day}) {
          added.add((spots: spots, leg: legIndex, day: day));
          return addResult;
        },
        removeSpot: (id, {keepEmptyDays = false}) {
          removed.add(id);
          final p = plan;
          if (removeSticks || p == null) return;
          plan = TripPlan(legs: p.legs, days: [for (final d in p.days) d.copyWith(spots: d.spots.where((s) => s.id != id).toList())]);
        },
        insertSpotAt: (ref, day, index) => inserted.add((ref: ref, day: day, index: index)),
        context: () => ctx!,
        cachedSpots: (k) => cache[k],
        cachedVersion: (k) => cache.containsKey(k) ? 'v$k' : null,
        cityName: (k) => k == 10 ? 'Shimla' : null,
        sheet: (context, spot, {required selected, required locked, onToggle, cityKey, version, required partial}) =>
            sheets.add((spot: spot, selected: selected, locked: locked, hasToggle: onToggle != null, cityKey: cityKey, version: version, partial: partial)),
      );
}

void main() {
  group('target day (D21)', () {
    test('All selected: first day of the spot city leg', () {
      final a = _Rig(_plan()).build();
      expect(a.targetDayFor(_hill), 1);
      expect(a.targetDayFor(_lake), 3);
    });

    test('picked day in the same city wins; a picked day in another city falls back to the leg start', () {
      final r = _Rig(_plan(), selected: 2);
      final a = r.build();
      expect(a.targetDayFor(_hill), 2);
      expect(a.targetDayFor(_lake), 3);
    });

    test('a city outside the trip or no plan gives null', () {
      expect(_Rig(_plan()).build().targetDayFor(_away), isNull);
      expect(_Rig(null).build().targetDayFor(_hill), isNull);
    });

    test('a spot without a city key goes to day 1 of a one-city trip only', () {
      const free = DiscoverySpot(id: 'f', lat: 1, lon: 1, category: 'park', rank: 1, name: 'F');
      final one = TripPlan(legs: const [TripCityLeg(index: 1, cityKey: 10, cityName: 'Hill', latitude: 1, longitude: 1)], days: const [TripDay(day: 1), TripDay(day: 2)]);
      expect(_Rig(one).build().targetDayFor(free), 1);
      expect(_Rig(_plan()).build().targetDayFor(free), isNull);
    });
  });

  group('add', () {
    test('calls addSpots with the leg and target day and a pack-built model', () {
      final r = _Rig(_plan(), selected: 2);
      expect(r.build().add(_hill), isTrue);
      final call = r.added.single;
      expect((call.leg, call.day), (1, 2));
      final m = call.spots.single;
      expect((m.id, m.title, m.category, m.latitude, m.longitude, m.imageUrl), ('n1', 'Jakhoo Temple', 'temple', 31.1, 77.17, 'https://x/image/upload/a.jpg'));
      expect(m.visitMinutes, TripSpotModel.fromJson(const {}).visitMinutes);
    });

    test('refused: full day, trip at the place cap, already planned, refused by the controller', () {
      final full = _Rig(_plan(day1: TripConstants.maxSpotsPerDay), selected: 1);
      expect(full.build().add(_hill), isFalse);
      expect(full.added, isEmpty);

      final capped = _Rig(TripPlan(
        legs: _plan().legs,
        days: [
          for (var d = 1; d <= 10; d++) TripDay(day: d, leg: d == 10 ? 2 : 1, spots: [for (var i = 0; i < TripConstants.maxSpots ~/ 10; i++) _ref('c$d-$i')]),
          const TripDay(day: 11, leg: 1),
        ],
      ), selected: 11);
      expect(capped.build().add(_hill), isFalse);
      expect(capped.added, isEmpty);

      final planned = _Rig(_plan());
      expect(planned.build().add(const DiscoverySpot(id: 'p0', lat: 1, lon: 1, category: 'temple', rank: 1, name: 'p0', cityKey: 10)), isFalse);

      final locked = _Rig(_plan())..addResult = false;
      expect(locked.build().add(_hill), isFalse);
      expect(locked.added, hasLength(1));
    });

    test('a cached full model is used instead of the pack row', () {
      final r = _Rig(_plan())
        ..cache = {
          10: [const TripSpotModel(id: 'n1', source: 'atlas', name: 'Jakhoo', description: 'Hilltop temple', latitude: 31.1, longitude: 77.17, category: 'temple', visitMinutes: 90)],
        };
      final a = r.build();
      a.add(_hill);
      expect(r.added.single.spots.single.visitMinutes, 90);
      expect(a.modelFor(_hill).partial, isFalse);
      expect(a.modelFor(_lake).partial, isTrue);
    });
  });

  group('line (R2)', () {
    test('cached description, else city name from the catalog, else the leg name, else null', () {
      final r = _Rig(_plan())
        ..cache = {
          10: [const TripSpotModel(id: 'n1', source: 'a', name: 'J', description: ' Hilltop temple ', latitude: 1, longitude: 1, category: 'temple', visitMinutes: 60)],
        };
      final a = r.build();
      expect(a.lineFor(_hill), 'Hilltop temple');
      expect(a.lineFor(const DiscoverySpot(id: 'x', lat: 1, lon: 1, category: 'temple', rank: 1, name: 'x', cityKey: 10)), 'Shimla');
      expect(a.lineFor(_lake), 'Lake Town');
      expect(a.lineFor(_away), isNull);
      expect(a.lineFor(const DiscoverySpot(id: 'y', lat: 1, lon: 1, category: 'park', rank: 1, name: 'y')), isNull);
    });
  });

  testWidgets('remove: removes with keepEmptyDays, shows Place removed with Undo that reinserts at the old place', (tester) async {
    final r = _Rig(_plan(day1: 3));
    await pumpPhone(tester, Scaffold(body: Builder(builder: (c) {
      r.ctx = c;
      return const SizedBox.expand();
    })));
    final a = r.build();
    expect(a.remove(const DiscoverySpot(id: 'p1', lat: 1, lon: 1, category: 'temple', rank: 1, name: 'p1', cityKey: 10)), isTrue);
    expect(r.removed, ['p1']);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.text(TripStringsV2Plan.placeRemoved), findsOneWidget);
    await tester.tap(find.text(TripStringsV2Plan.undo));
    await tester.pump();
    expect(r.inserted.single.ref.id, 'p1');
    expect((r.inserted.single.day, r.inserted.single.index), (1, 1));
  });

  testWidgets('remove blocked by the controller shows no snackbar', (tester) async {
    final r = _Rig(_plan())..removeSticks = true;
    await pumpPhone(tester, Scaffold(body: Builder(builder: (c) {
      r.ctx = c;
      return const SizedBox.expand();
    })));
    expect(r.build().remove(const DiscoverySpot(id: 'p0', lat: 1, lon: 1, category: 'temple', rank: 1, name: 'p0', cityKey: 10)), isFalse);
    await tester.pump();
    expect(find.text(TripStringsV2Plan.placeRemoved), findsNothing);
  });

  test('details: planned = selected with a toggle; unplanned in trip = add toggle; outside the trip = locked, no toggle; partial and version passed', () {
    final r = _Rig(_plan());
    r.ctx = _NoContext();
    final a = r.build();
    a.details(const DiscoverySpot(id: 'p0', lat: 1, lon: 1, category: 'temple', rank: 1, name: 'p0', cityKey: 10));
    a.details(_hill);
    a.details(_away);
    expect([for (final s in r.sheets) (s.selected, s.locked, s.hasToggle)], [(true, false, true), (false, false, true), (false, true, false)]);
    expect(r.sheets[1].partial, isTrue);
    expect(r.sheets[1].cityKey, 10);
    expect(r.sheets[1].version, '');
    expect(r.sheets[0].spot.visitMinutes, 45, reason: 'a planned spot keeps its plan visit minutes');
  });
}

class _NoContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
