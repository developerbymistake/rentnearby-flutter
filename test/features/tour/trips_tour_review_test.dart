import 'dart:io';

import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/config/app_tour_state.dart';
import 'package:bakhli/controllers/tour_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/navigation/tour_keys.dart';
import 'package:bakhli/widgets/tour_overlay.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'trips_tour_harness.dart';

Rect _spotlight(WidgetTester t) {
  final paint = find
      .descendant(of: find.byType(TourOverlay), matching: find.byType(CustomPaint))
      .evaluate()
      .map((e) => e.widget as CustomPaint)
      .firstWhere((w) => w.painter != null && w.painter.runtimeType.toString() == '_SpotlightPainter');
  return (paint.painter as dynamic).targetRect as Rect;
}

bool _inside(Rect inner, Size screen) =>
    inner.left >= 0 && inner.top >= 0 && inner.right <= screen.width && inner.bottom <= screen.height;

void _expectSpotOnTile(WidgetTester t, GlobalKey key) {
  final expected = t.getRect(find.byKey(key)).inflate(DS.s(8));
  final spot = _spotlight(t);
  expect(spot.left, moreOrLessEquals(expected.left, epsilon: 0.5));
  expect(spot.top, moreOrLessEquals(expected.top, epsilon: 0.5));
  expect(spot.right, moreOrLessEquals(expected.right, epsilon: 0.5));
  expect(spot.bottom, moreOrLessEquals(expected.bottom, epsilon: 0.5));
}

void _expectHittable(WidgetTester t, Finder f) {
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(result, t.getCenter(f), t.view.viewId);
  final target = f.evaluate().single.renderObject!;
  expect(result.path.any((e) => e.target == target), isTrue, reason: 'not hit-testable: $f');
}

void _checkStep(WidgetTester t, Size size, int step, {bool roomForCard = true}) {
  final key = step == 0 ? TourKeys.tripsWhereTile : TourKeys.tripsBuddyTile;
  _expectSpotOnTile(t, key);
  final spot = _spotlight(t);
  expect(_inside(t.getRect(find.byKey(key)), size), isTrue, reason: 'tile off screen $size');
  final card = t.getRect(find.byKey(ValueKey('tour-card-$step')));
  expect(_inside(card, size), isTrue, reason: 'card $card off screen $size');
  if (roomForCard) expect(card.overlaps(spot), isFalse, reason: 'card $card covers spotlight $spot');
  _expectHittable(t, find.text('Skip'));
  _expectHittable(t, find.text(step == 0 ? 'Next' : 'Finish'));
}

TripSummaryModel _trip() => TripSummaryModel.fromJson({
      'id': 'trip-1',
      'title': 'Trip number 1',
      'status': 'Planned',
      'cityName': 'Nainital',
      'dayCount': 2,
      'spotCount': 4,
      'category': 'attraction',
      'startDate': '2030-01-11',
      'endDate': '2030-01-13',
      'updatedAt': '2026-11-01T10:00:00Z',
      'progress': {'total': 4, 'done': 1, 'percent': 25},
    });

void main() {
  setUpAll(initTourStorage);
  setUp(eraseTourStorage);
  tearDown(() async {
    if (Get.isRegistered<TourController>()) Get.delete<TourController>(force: true);
    currentTourStep.value = null;
    tourInProgress.value = false;
    Get.reset();
  });

  for (final size in const [Size(320, 568), Size(412, 915), Size(800, 1280)]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('motion on: both steps sit on their tile @ ${size.width.toInt()}x${size.height.toInt()} text $scale',
          (t) async {
        // 320x568 at 1.3 has no side with room for the whole card: it must stay on screen.
        final room = !(size.height < 640 && scale > 1);
        await pumpTourHarness(t, size: size, scale: scale, tab: AppTabs.trips);
        await advance(t, const Duration(milliseconds: 2400));
        expect(tourStepIndex.value, 0);
        _checkStep(t, size, 0, roomForCard: room);
        await t.tap(find.text('Next'));
        await advance(t, const Duration(milliseconds: 1200));
        expect(tourStepIndex.value, 1);
        _checkStep(t, size, 1, roomForCard: room);
        expect(t.takeException(), isNull);
      });
    }
  }

  for (final reduce in const [false, true]) {
    testWidgets('the spotlight follows the tile when the page shifts under it (reduce motion $reduce)', (t) async {
      await pumpTourHarness(t, tab: AppTabs.trips, disableAnimations: reduce);
      await advance(t, const Duration(milliseconds: 2400));
      expect(tourStepIndex.value, 0);
      final before = t.getRect(find.byKey(TourKeys.tripsWhereTile));
      Get.find<MyTripsController>().active.assignAll([_trip()]);
      await advance(t, const Duration(milliseconds: 600));
      expect(find.text('Continue your trip'), findsOneWidget);
      final after = t.getRect(find.byKey(TourKeys.tripsWhereTile));
      expect(after.top, greaterThan(before.top));
      _expectSpotOnTile(t, TourKeys.tripsWhereTile);
      final card = t.getRect(find.byKey(const ValueKey('tour-card-0')));
      expect(card.overlaps(_spotlight(t)), isFalse);
    });
  }

  test('one engine, one host: created only in MainScreen, mounted only in main.dart', () {
    final files = {
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')))
        f.path.replaceAll('\\', '/'): f.readAsStringSync(),
    };
    List<String> having(Pattern p, {String? except}) =>
        [for (final e in files.entries) if (e.key != except && e.value.contains(p)) e.key];
    expect(having(RegExp(r'Get\.put(<TourController>)?\(TourController\(')), ['lib/screens/main_screen.dart']);
    expect(having(RegExp(r'\bTourHost\('), except: 'lib/widgets/tour_host.dart'), ['lib/main.dart']);
    expect(having(RegExp(r'\bTourOverlay\('), except: 'lib/widgets/tour_overlay.dart'), ['lib/widgets/tour_host.dart']);
    expect(having(RegExp(r'\bTourStep\('), except: 'lib/config/tour_registry.dart'),
        ['lib/features/trip/trips_tour_steps.dart']);
    expect(having(RegExp(r'TourKeys\.trips\w+'), except: 'lib/features/trip/trips_tour_steps.dart'),
        ['lib/features/trip/screens/trips_discovery_screen.dart']);
    expect(having('saveTourSeen(').toSet(), {
      'lib/controllers/tour_controller.dart',
      'lib/services/storage_service.dart',
      'lib/screens/intro/intro_scaffold.dart',
    });
    final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
    for (final dep in ['showcase', 'coach_mark', 'tutorial_coach', 'feature_discovery', 'intro_views']) {
      expect(pubspec.contains(dep), isFalse, reason: dep);
    }
  });
}
