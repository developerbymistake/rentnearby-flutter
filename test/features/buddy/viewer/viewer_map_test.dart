import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:bakhli/features/buddy/buddy_live.dart';
import 'package:bakhli/features/buddy/shared/widgets/segment_tabs.dart';
import 'package:bakhli/features/buddy/viewer/controllers/viewer_trip_controller.dart';
import 'package:bakhli/features/buddy/viewer/data/viewer_spot_photos.dart';
import 'package:bakhli/features/buddy/viewer/data/viewer_trip_cache.dart';
import 'package:bakhli/features/buddy/viewer/models/viewer_models.dart';
import 'package:bakhli/features/buddy/viewer/screens/viewer_map_screen.dart';
import 'package:bakhli/features/buddy/viewer/viewer_deps.dart';
import 'package:bakhli/features/buddy/viewer/viewer_look.dart';
import 'package:bakhli/features/buddy/viewer/viewer_strings.dart';
import 'package:bakhli/features/buddy/viewer/widgets/viewer_map_scene.dart';
import 'package:bakhli/features/buddy/viewer/widgets/viewer_route_map.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_index.dart';
import 'package:bakhli/features/map_discovery/pack/map_pack_models.dart';
import 'package:bakhli/features/trip/widgets/trip_map_controls.dart';
import 'package:bakhli/features/trip/widgets/trip_map_spot_card.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'viewer_fixtures.dart';

const _photo = 'https://res.cloudinary.com/x/image/upload/v1/atlas/spots/naini.jpg';

Map<String, dynamic> _road() => {
      'type': 'LineString',
      'coordinates': [
        [79.4622, 29.3861],
        [79.4600, 29.3880],
        [79.4573, 29.3907],
        [79.4633, 29.4006],
      ],
    };

ViewerTrip _trip() {
  final j = s14Json();
  ((j['days'] as List).first as Map<String, dynamic>)['routeGeoJson'] = _road();
  return ViewerTrip.fromJson(j);
}

class _FakeMap extends StatefulWidget {
  const _FakeMap(this.view);

  final ViewerMapView view;

  static int created = 0;
  static ViewerMapView? last;

  @override
  State<_FakeMap> createState() => _FakeMapState();
}

class _FakeMapState extends State<_FakeMap> {
  @override
  void initState() {
    super.initState();
    _FakeMap.created++;
  }

  @override
  Widget build(BuildContext context) {
    _FakeMap.last = widget.view;
    return const ColoredBox(color: Colors.white);
  }
}

Future<ViewerTripController> _pumpMap(WidgetTester t, {int? day}) async {
  t.view.devicePixelRatio = 2;
  t.view.physicalSize = const Size(784, 1600);
  addTearDown(t.view.reset);
  final c = Get.put(ViewerTripController(tripId, api: FakeViewerApi(), ledger: FakeViewerLedger()), tag: tripId);
  c.trip.value = _trip();
  await t.pumpWidget(app(ViewerMapScreen(tripId: tripId, day: day, mapBuilder: (_, v) => _FakeMap(v))));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
  return c;
}

void main() {
  setUp(() {
    DS.applyApproved();
    useMemoryCache();
    _FakeMap.created = 0;
    _FakeMap.last = null;
  });
  tearDown(() {
    ViewerSpotPhotos.indexForTest = null;
    DS.debugReset();
    ViewerDeps.debugReset();
    ViewerTripCache.debugReset();
    BuddyLive.reset();
    Get.reset();
  });

  group('scene', () {
    test('day colours are the owner trip map route colours', () {
      expect(ViewerLook.routeColors, [TripLook.headerGlow, TripLook.mapRouteDay2, TripLook.dayCyan]);
      final scene = ViewerMapScene.of(_trip().days, _trip().legs, photoOf: (_) => null);
      expect(scene.days.map((d) => d.color), [ViewerLook.routeColor(1), ViewerLook.routeColor(2)]);
      expect(scene.stops.where((s) => s.day == 2).map((s) => s.route.ring).toSet(), {TripLook.mapRouteDay2});
    });

    test('other days dim: lines 0.25, circles 0.45; all days full', () {
      final trip = _trip();
      final scene = ViewerMapScene.of(trip.days, trip.legs, photoOf: (_) => null);
      expect(scene.lineOpacity(1, 2), 0.25);
      expect(scene.stopOpacity(1, 2), 0.45);
      expect(scene.lineOpacity(2, 2), 1);
      expect(scene.stopOpacity(2, 2), 1);
      expect(scene.stopOpacities(ViewerMapScene.all).toSet(), {1.0});
      expect(scene.stopOpacities(2), [for (final s in scene.stops) s.day == 2 ? 1.0 : 0.45]);
    });

    test('numbered stops per day, city key from the leg, stop line from the viewer data', () {
      final trip = _trip();
      final scene = ViewerMapScene.of(trip.days, trip.legs, photoOf: (_) => null);
      final s = scene.stopAt(2, 2)!;
      expect(s.spot.id, 'sp-7');
      expect(s.number, 3);
      expect(s.route.number, 3);
      expect(s.cityKey, 210000101);
      expect(s.line, 'Day 2 · Stop 3 · About 1 h 30 m here');
      expect(ViewerMapScene.tuning.photoDp, DS.s(54));
    });

    test('a day without a road line is dashed with round dots; a road day is solid', () {
      final trip = _trip();
      final scene = ViewerMapScene.of(trip.days, trip.legs, photoOf: (_) => null);
      final road = scene.days.firstWhere((d) => d.day == 1);
      final none = scene.days.firstWhere((d) => d.day == 2);
      expect(road.dashed, isFalse);
      expect(none.dashed, isTrue);
      final dashed = ViewerRouteMap.lineLayers(none, 1).last.$2;
      expect(dashed.lineDasharray, ViewerRouteMap.noRoadDots);
      expect(dashed.lineCap, 'round');
      expect(ViewerRouteMap.lineLayers(road, 1).last.$2.lineDasharray, isNull);
      expect(scene.dashedShown(ViewerMapScene.all), isTrue);
      expect(scene.dashedShown(1), isFalse);
      expect(scene.dashedShown(2), isTrue);
    });

    test('a bad road geometry falls back to the dashed line', () {
      expect(ViewerMapScene.roadOf(null), isNull);
      expect(ViewerMapScene.roadOf({'type': 'LineString', 'coordinates': []}), isNull);
      expect(ViewerMapScene.roadOf(_road())?['type'], 'FeatureCollection');
    });

    test('circles take the photo from ViewerSpotPhotos, else the category art', () {
      final index = MapPackIndex.of([
        const MapPack(version: 'v1', stateId: 's1', spots: [
          MapPackSpot(id: 'sp-1', lat: 29.3861, lon: 79.4622, category: 'lake', rank: 1, name: 'Naini Lake', thumbUrl: _photo),
        ]),
      ]);
      ViewerSpotPhotos.indexForTest = () => index;
      final trip = _trip();
      final scene = ViewerMapScene.of(trip.days, trip.legs);
      final withPhoto = scene.stopAt(1, 0)!;
      expect(withPhoto.route.spot.thumbUrl, _photo);
      expect(withPhoto.route.spot.hasThumb, isTrue);
      expect(scene.stopAt(1, 1)!.route.spot.hasThumb, isFalse);
      expect(scene.stopAt(1, 1)!.route.spot.category, 'temple');
    });
  });

  group('screen', () {
    testWidgets('header subtitle, view only chip, day dots and controls', (t) async {
      final c = await _pumpMap(t);
      final trip = c.trip.value!;
      expect(find.text(trip.title), findsOneWidget);
      expect(find.text(ViewerStrings.mapSubtitle(trip.owner.name, trip.dayCount, trip.spotCount)), findsOneWidget);
      expect(find.text('Shared by Rahul · 7 days · 18 places'), findsOneWidget);
      final tabs = t.widget<SegmentTabs>(find.byType(SegmentTabs));
      expect(tabs.dayDots!.skip(1), [ViewerLook.routeColor(1), ViewerLook.routeColor(2)]);
      expect(find.byType(TripMapControls), findsOneWidget);
      expect(find.byKey(const ValueKey('disc-zoom-in')), findsOneWidget);
      expect(find.byKey(const ValueKey('disc-locate')), findsOneWidget);
      expect(find.byKey(const ValueKey('disc-eye')), findsNothing);
    });

    testWidgets('one map for all days: a day pick dims, never rebuilds the map', (t) async {
      await _pumpMap(t);
      expect(_FakeMap.created, 1);
      expect(_FakeMap.last!.selected, ViewerMapScene.all);
      await t.tap(find.text('Day 2'));
      await t.pump();
      expect(_FakeMap.created, 1);
      expect(_FakeMap.last!.selected, 2);
      expect(_FakeMap.last!.scene.lineOpacity(1, _FakeMap.last!.selected), ViewerMapScene.dimLine);
      await t.tap(find.text('All days'));
      await t.pump();
      expect(_FakeMap.created, 1);
      expect(_FakeMap.last!.selected, ViewerMapScene.all);
    });

    testWidgets('tap a place: read-only card with only Details; chevron and empty map close it', (t) async {
      await _pumpMap(t);
      final view = _FakeMap.last!;
      view.onTap(view.scene.stopAt(2, 2));
      await t.pump();
      expect(find.byType(TripMapSpotCard), findsOneWidget);
      expect(t.widget<TripMapSpotCard>(find.byType(TripMapSpotCard)).onAdd, isNull);
      expect(find.text('Kainchi Dham'), findsOneWidget);
      expect(find.text('Day 2 · Stop 3 · About 1 h 30 m here'), findsOneWidget);
      expect(find.byKey(const ValueKey('disc-card-details')), findsOneWidget);
      expect(find.byKey(const ValueKey('disc-card-add')), findsNothing);
      expect(find.byKey(const ValueKey('disc-card-remove')), findsNothing);
      expect(_FakeMap.last!.picked?.spot.id, 'sp-7');

      await t.tap(find.byKey(const ValueKey('disc-card-close')));
      await t.pump();
      expect(find.byType(TripMapSpotCard), findsNothing);

      _FakeMap.last!.onTap(_FakeMap.last!.scene.stopAt(1, 0));
      await t.pump();
      expect(find.byType(TripMapSpotCard), findsOneWidget);
      _FakeMap.last!.onTap(null);
      await t.pump();
      expect(find.byType(TripMapSpotCard), findsNothing);
      expect(_FakeMap.created, 1);
    });

    testWidgets('Details opens the place page without an action', (t) async {
      await _pumpMap(t);
      _FakeMap.last!.onTap(_FakeMap.last!.scene.stopAt(2, 0));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('disc-card-details')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      final sheet = t.widget<TripSpotDetailSheet>(find.byType(TripSpotDetailSheet));
      expect(sheet.showAction, isFalse);
      expect(sheet.spot.id, 'sp-5');
      expect(sheet.cityKey, isNotNull);
    });

    testWidgets('no road line note shows only while a dashed day is shown', (t) async {
      await _pumpMap(t);
      expect(find.text(ViewerStrings.noRoadLine), findsOneWidget);
      await t.tap(find.text('Day 1'));
      await t.pump();
      expect(find.byKey(ViewerMapScreen.noRoadKey), findsNothing);
      await t.tap(find.text('Day 2'));
      await t.pump();
      expect(find.text('Road line not available'), findsOneWidget);
    });
  });
}
