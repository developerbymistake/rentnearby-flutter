import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/config/app_tour_state.dart';
import 'package:bakhli/config/shell_kind.dart';
import 'package:bakhli/controllers/tour_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/navigation/tour_keys.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:bakhli/widgets/tour_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'trips_tour_harness.dart';

const _seenKey = 'tour_trips_seen_v1';
bool get _seen => StorageService.getTourSeen(_seenKey);

Future<void> _wait(WidgetTester t, [int ms = 1600]) => advance(t, Duration(milliseconds: ms));

Future<void> _goTab(WidgetTester t, TourHarness h, int tab, [int ms = 1600]) async {
  h.auth.tabIndex.value = tab;
  await _wait(t, ms);
}

void _expectNothing() {
  expect(tourInProgress.value, isFalse);
  expect(currentTourStep.value, isNull);
  expect(find.byType(TourOverlay), findsNothing);
}

void _expectStep(int index) {
  expect(tourInProgress.value, isTrue);
  expect(find.byType(TourOverlay), findsOneWidget);
  expect(tourStepIndex.value, index);
  expect(tourTotalSteps.value, 2);
  expect(currentTourLabel.value, 'Trips Tour');
  expect(currentTourStep.value!.key, index == 0 ? TourKeys.tripsWhereTile : TourKeys.tripsBuddyTile);
}

Rect _rectOf(WidgetTester t, GlobalKey key) => t.getRect(find.byKey(key));

void main() {
  setUpAll(initTourStorage);
  setUp(eraseTourStorage);
  tearDown(() async {
    if (Get.isRegistered<TourController>()) Get.delete<TourController>(force: true);
    currentTourStep.value = null;
    tourInProgress.value = false;
    Get.reset();
  });

  testWidgets('never on Home, Stays, Taxi or Profile in the seeker shell', (t) async {
    final h = await pumpTourHarness(t);
    await _wait(t, 3000);
    _expectNothing();
    for (final tab in [AppTabs.stays, AppTabs.taxi, AppTabs.profile, AppTabs.home]) {
      await _goTab(t, h, tab, 3000);
      _expectNothing();
    }
    expect(_seen, isFalse);
  });

  for (final shell in [ShellKind.stayOwner, ShellKind.taxiDriver]) {
    testWidgets('never on any tab in the $shell shell', (t) async {
      final h = await pumpTourHarness(t, shell: shell);
      await _wait(t, 3000);
      for (var tab = 0; tab < AppTabs.count; tab++) {
        await _goTab(t, h, tab, 3000);
        _expectNothing();
      }
      expect(_seen, isFalse);
    });
  }

  testWidgets('starts on Trips after the pause with step 1 of 2', (t) async {
    final h = await pumpTourHarness(t);
    await _wait(t, 2000);
    h.auth.tabIndex.value = AppTabs.trips;
    await _wait(t, 600);
    _expectNothing();
    await _wait(t, 1000);
    _expectStep(0);
    expect(find.text('TRIPS TOUR · 1 OF 2'), findsOneWidget);
    expect(find.text('Where to next?'), findsOneWidget);
    expect(_seen, isFalse);
  });

  testWidgets('once only: Next then Finish marks seen, never again, even after a restart', (t) async {
    final h = await pumpTourHarness(t, tab: AppTabs.trips);
    await _wait(t);
    _expectStep(0);
    await t.tap(find.text('Next'));
    await _wait(t, 800);
    _expectStep(1);
    expect(find.text('TRIPS TOUR · 2 OF 2'), findsOneWidget);
    expect(find.text('Find a buddy'), findsOneWidget);
    await t.tap(find.text('Finish'));
    await _wait(t, 300);
    _expectNothing();
    expect(_seen, isTrue);

    await _goTab(t, h, AppTabs.home);
    await _goTab(t, h, AppTabs.trips, 3000);
    _expectNothing();

    h.restartController();
    await _wait(t, 3000);
    _expectNothing();
  });

  testWidgets('skip on step 1 marks seen and closes for good', (t) async {
    final h = await pumpTourHarness(t, tab: AppTabs.trips);
    await _wait(t);
    _expectStep(0);
    await t.tap(find.text('Skip'));
    await _wait(t, 300);
    _expectNothing();
    expect(_seen, isTrue);
    await _goTab(t, h, AppTabs.home);
    await _goTab(t, h, AppTabs.trips, 3000);
    _expectNothing();
  });

  testWidgets('skip on step 2 marks seen and closes for good', (t) async {
    final h = await pumpTourHarness(t, tab: AppTabs.trips);
    await _wait(t);
    await t.tap(find.text('Next'));
    await _wait(t, 800);
    _expectStep(1);
    await t.tap(find.text('Skip'));
    await _wait(t, 300);
    _expectNothing();
    expect(_seen, isTrue);
    await _goTab(t, h, AppTabs.stays);
    await _goTab(t, h, AppTabs.trips, 3000);
    _expectNothing();
  });

  testWidgets('resume: leaving the tab mid-tour does not mark seen, return starts at step 1', (t) async {
    final h = await pumpTourHarness(t, tab: AppTabs.trips);
    await _wait(t);
    await t.tap(find.text('Next'));
    await _wait(t, 800);
    _expectStep(1);
    await _goTab(t, h, AppTabs.home, 300);
    _expectNothing();
    expect(_seen, isFalse);
    await _goTab(t, h, AppTabs.trips);
    _expectStep(0);
    await _wait(t, 1000);
  });

  testWidgets('resume: a pushed root route tears down without marking seen', (t) async {
    final h = await pumpTourHarness(t, tab: AppTabs.trips);
    await _wait(t);
    _expectStep(0);
    Get.toNamed(AppRoutes.notifications);
    await _wait(t, 600);
    _expectNothing();
    expect(_seen, isFalse);
    Get.back();
    await _wait(t, 600);
    await _goTab(t, h, AppTabs.home, 300);
    await _goTab(t, h, AppTabs.trips);
    _expectStep(0);
    await _wait(t, 1000);
  });

  testWidgets('resume: a gate tears down, clearing it starts again at step 1', (t) async {
    final h = await pumpTourHarness(t, tab: AppTabs.trips);
    await _wait(t);
    _expectStep(0);
    h.loc.isOffline.value = true;
    await _wait(t, 300);
    _expectNothing();
    expect(_seen, isFalse);
    await _wait(t, 2000);
    _expectNothing();
    h.loc.isOffline.value = false;
    await _wait(t);
    _expectStep(0);
    await _wait(t, 1000);
  });

  testWidgets('logout tears down and never restarts while signed out', (t) async {
    final h = await pumpTourHarness(t, tab: AppTabs.trips);
    await _wait(t);
    _expectStep(0);
    h.auth.user.value = null;
    await _wait(t, 300);
    _expectNothing();
    expect(_seen, isFalse);
    await _goTab(t, h, AppTabs.home, 300);
    await _goTab(t, h, AppTabs.trips, 3000);
    _expectNothing();
  });

  testWidgets('a tap on the spotlight is Next, on the last step it finishes; the scrim does nothing', (t) async {
    await pumpTourHarness(t, tab: AppTabs.trips);
    await _wait(t);
    _expectStep(0);
    final where = _rectOf(t, TourKeys.tripsWhereTile);
    await t.tapAt(Offset((where.left - DS.s(8)) / 2, where.center.dy));
    await _wait(t, 300);
    _expectStep(0);
    await t.tapAt(where.center);
    await _wait(t, 800);
    _expectStep(1);
    expect(_seen, isFalse);
    await t.tapAt(_rectOf(t, TourKeys.tripsBuddyTile).center);
    await _wait(t, 300);
    _expectNothing();
    expect(_seen, isTrue);
  });

  testWidgets('migration: old Home and Stays flags are dropped and do not block the Trips guide', (t) async {
    final box = GetStorage();
    await box.write('tour_home_seen_v2', true);
    await box.write('tour_stays_seen_v1', true);
    final h = await pumpTourHarness(t);
    await _wait(t, 3000);
    expect(box.read('tour_home_seen_v2'), isNull);
    expect(box.read('tour_stays_seen_v1'), isNull);
    _expectNothing();
    await _goTab(t, h, AppTabs.trips);
    _expectStep(0);
    await _wait(t, 1000);
  });

  testWidgets('migration: with no old flags nothing shows on Home or Stays', (t) async {
    final h = await pumpTourHarness(t);
    await _wait(t, 3000);
    _expectNothing();
    await _goTab(t, h, AppTabs.stays, 3000);
    _expectNothing();
  });
}
