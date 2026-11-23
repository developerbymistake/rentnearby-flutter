import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/config/app_tour_state.dart';
import 'package:bakhli/controllers/tour_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/navigation/tour_keys.dart';
import 'package:bakhli/widgets/tour_overlay.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'trips_tour_harness.dart';

Rect _spotlight(WidgetTester t) {
  final paint = find.descendant(of: find.byType(TourOverlay), matching: find.byType(CustomPaint)).evaluate()
      .map((e) => e.widget as CustomPaint)
      .firstWhere((w) => w.painter != null && w.painter.runtimeType.toString() == '_SpotlightPainter');
  return (paint.painter as dynamic).targetRect as Rect;
}

bool _inside(Rect inner, Size screen) =>
    inner.left >= 0 && inner.top >= 0 && inner.right <= screen.width && inner.bottom <= screen.height;

void _expectHittable(WidgetTester t, Finder f) {
  final center = t.getCenter(f);
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(result, center, t.view.viewId);
  final target = f.evaluate().single.renderObject!;
  expect(result.path.any((e) => e.target == target), isTrue, reason: 'not hit-testable: $f');
}

void main() {
  setUpAll(initTourStorage);
  setUp(eraseTourStorage);
  tearDown(() async {
    if (Get.isRegistered<TourController>()) Get.delete<TourController>(force: true);
    currentTourStep.value = null;
    tourInProgress.value = false;
    Get.reset();
  });

  Future<void> checkStep(WidgetTester t, Size size, int step) async {
    final key = step == 0 ? TourKeys.tripsWhereTile : TourKeys.tripsBuddyTile;
    final tile = t.getRect(find.byKey(key));
    final spot = _spotlight(t);
    final expected = tile.inflate(DS.s(8));
    expect(spot.left, moreOrLessEquals(expected.left, epsilon: 0.5));
    expect(spot.top, moreOrLessEquals(expected.top, epsilon: 0.5));
    expect(spot.right, moreOrLessEquals(expected.right, epsilon: 0.5));
    expect(spot.bottom, moreOrLessEquals(expected.bottom, epsilon: 0.5));
    expect(_inside(tile, size), isTrue, reason: 'tile $tile off screen $size');
    final card = t.getRect(find.byKey(ValueKey('tour-card-$step')));
    expect(_inside(card, size), isTrue, reason: 'card $card off screen $size');
    expect(card.overlaps(spot), isFalse, reason: 'card $card covers spotlight $spot');
    _expectHittable(t, find.text('Skip'));
    _expectHittable(t, find.text(step == 0 ? 'Next' : 'Finish'));
  }

  for (final size in const [Size(360, 800), Size(360, 640)]) {
    for (final scale in const [1.0, 1.3]) {
      final tag = '${size.width.toInt()}x${size.height.toInt()} text $scale';
      testWidgets('both steps fit, spotlight the tile and keep the card clear @ $tag', (t) async {
        await pumpTourHarness(t, size: size, scale: scale, tab: AppTabs.trips, disableAnimations: true);
        await advance(t, const Duration(milliseconds: 2400));
        expect(tourStepIndex.value, 0);
        await checkStep(t, size, 0);
        expect(t.takeException(), isNull);
        if (size.height == 800) {
          await expectLater(find.byKey(harnessRoot), matchesGoldenFile('goldens/trips_tour_step1_$scale.png'));
        }
        await t.tap(find.text('Next'));
        await advance(t, const Duration(milliseconds: 1200));
        expect(tourStepIndex.value, 1);
        await checkStep(t, size, 1);
        expect(t.takeException(), isNull);
        if (size.height == 800) {
          await expectLater(find.byKey(harnessRoot), matchesGoldenFile('goldens/trips_tour_step2_$scale.png'));
        }
      });
    }
  }

  testWidgets('reduce motion: the pulse does not run and the card still shows', (t) async {
    await pumpTourHarness(t, tab: AppTabs.trips, disableAnimations: true);
    await advance(t, const Duration(milliseconds: 2400));
    expect(find.byType(TourOverlay), findsOneWidget);
    expect(find.byKey(const ValueKey('tour-card-0')), findsOneWidget);
    expect(find.text('Where to next?'), findsOneWidget);
    await t.pumpAndSettle();
    expect(t.binding.hasScheduledFrame, isFalse);
    expect(find.byKey(const ValueKey('tour-card-0')), findsOneWidget);
  });
}
