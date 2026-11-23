import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/data/spot_gallery_loader.dart';
import 'package:bakhli/features/trip/data/trip_repository.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/trip_map_spot_actions.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/utils/spot_gallery_cache.dart';
import 'package:bakhli/features/trip/utils/trip_spots_cache.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../support/real_phone.dart';

// Journeys through the trip map actions with the real place page (APP-2) and the real plan controller (APP-6).

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Repo extends TripRepository {
  int calls = 0;
  SpotDetail answer = const SpotDetail();

  @override
  Future<SpotDetail> spotDetail(int cityKey, String spotId) async {
    calls++;
    return answer;
  }
}

String _u(String n) => 'https://res.cloudinary.com/demo/image/upload/v1/$n.jpg';

TripPlan _plan() => TripPlan(
      legs: const [TripCityLeg(index: 1, cityKey: 10, cityName: 'Hill Town', latitude: 31.1, longitude: 77.1)],
      days: const [TripDay(day: 1, leg: 1), TripDay(day: 2, leg: 1)],
    );

const _spot = DiscoverySpot(id: 'n1', lat: 31.1, lon: 77.17, category: 'temple', rank: 4, name: 'Jakhoo Temple', cityKey: 10, visitMinutes: 120);

TripSpotModel _row(String photo) => TripSpotModel.fromJson({
      'id': 'n1',
      'name': 'Jakhoo Temple',
      'latitude': 31.1,
      'longitude': 77.17,
      'category': 'temple',
      'rank': 4,
      'description': 'Old text.',
      'images': [photo],
    });

void main() {
  late _Repo repo;
  final shown = <String>[];

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('trip_map_journey').path,
    );
    await GetStorage.init();
    await TripSpotsCache.init();
  });

  setUp(() async {
    Get.testMode = true;
    await GetStorage(TripSpotsCache.container).erase();
    SpotGalleryLoader.debugReset();
    SpotGalleryCache.clear();
    repo = _Repo();
    SpotGalleryLoader.repository = repo;
    shown.clear();
    TripSpotMedia.debugImageBuilder = (url, fit, fallback) {
      shown.add(url);
      return const ColoredBox(color: Color(0xFF88AACC));
    };
  });

  tearDown(() {
    TripSpotMedia.debugImageBuilder = null;
    SpotGalleryLoader.debugReset();
    Get.reset();
  });

  TripPlanController controller() {
    Get.put<TabConfigController>(_Tabs());
    final c = Get.put(TripPlanController());
    c.plan.value = _plan();
    return c;
  }

  testWidgets('APP-2: list cached with photo A, server now has photo B + gallery of 2: Details shows B and the collage, one request', (t) async {
    TripSpotsCache.save(10, [_row(_u('photoA'))], '2026-11-22T10:00:00.000');
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    repo.answer = SpotDetail(
      spot: TripSpotModel.fromJson({
        'id': 'n1',
        'name': 'Jakhoo Temple',
        'latitude': 31.1,
        'longitude': 77.17,
        'category': 'temple',
        'description': 'Edited by the admin.',
        'images': [_u('photoB')],
        'galleryCount': 2,
      }),
      gallery: [_u('g1'), _u('g2')],
      version: '2026-11-23T10:00:00.000',
    );
    final c = controller();
    late BuildContext ctx;
    await pumpPhone(t, Scaffold(body: Builder(builder: (b) {
      ctx = b;
      return const SizedBox.expand();
    })));
    final actions = TripMapSpotActions.of(c, context: () => ctx);
    for (var i = 0; i < 20; i++) {
      actions.modelFor(_spot);
      actions.lineFor(_spot);
      actions.targetDayFor(_spot);
    }
    expect(repo.calls, 0, reason: 'card work while panning makes no request');
    actions.details(_spot);
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    await t.pump(const Duration(milliseconds: 100));
    expect(repo.calls, 1);
    expect(find.text('Edited by the admin.'), findsOneWidget);
    expect(find.text('Old text.'), findsNothing);
    expect(shown.any((u) => u.contains('photoB')), isTrue);
    expect(find.text('2 photos'), findsOneWidget);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    expect(TripSpotsCache.versionOf(10), isNull, reason: 'the stale city list is dropped after a newer answer');
    expect(actions.modelFor(_spot).partial, isTrue);
  });

  test('APP-6: add a place from the map with no cached list: the plan day and the autosave body carry the pack minutes', () {
    final c = controller();
    final actions = TripMapSpotActions.of(c, context: () => throw StateError('no context needed'));
    expect(actions.add(_spot), isTrue);
    final ref = c.plan.value!.dayAt(1)!.spots.single;
    expect(ref.id, 'n1');
    expect(ref.visitMinutes, 120);
    final body = c.plan.value!.toJson();
    final days = body['days'] as List;
    final spots = (days.first as Map)['spots'] as List;
    expect((spots.single as Map)['visitMinutes'], 120);
  });
}
