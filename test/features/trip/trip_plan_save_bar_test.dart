import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/screens/trip_dates_sheet.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/features/trip/trip_strings_dayplan.dart';
import 'package:bakhli/features/trip/trip_strings_save_trip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../journeys/fake_api.dart';
import '../../support/five_sizes.dart';
import 'support/engine_rig.dart';
import 'trip_day_plan_screen_test.dart';

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  testWidgets('saved_plan_reads_back_to_overview_and_replaces_when_no_overview_under', (t) async {
    final plan = dayPlanFixture();
    final api = installFakeApi([FakeRoute.value('PUT', '/trips/{id}', engineTripJson(plan))]);
    Object? args;
    await pumpDayPlan(t, plan, size: const Size(360, 800), pages: [
      GetPage(name: AppRoutes.tripOverview, page: () {
        args = Get.arguments;
        return const Scaffold(body: Text('overview'));
      }),
    ]);
    final button = find.byKey(TripPlanScreen.saveTripKey);
    expect(button, findsOneWidget);
    expect(find.descendant(of: button, matching: find.text(TripStringsDayplan.backToOverview)), findsOneWidget);
    expect(find.text(TripStringsDayplan.saveTrip), findsNothing);

    await t.tap(button);
    await t.pumpAndSettle();
    expect(api.calls('POST', '/trips'), isEmpty);
    expect(find.text('overview'), findsOneWidget);
    expect(find.byType(TripPlanScreen), findsNothing);
    expect(args, {'tripId': 't1'});
    await drainSave(t);
  });

  testWidgets('saved_plan_back_to_overview_pops_when_the_overview_is_under', (t) async {
    final plan = dayPlanFixture();
    installFakeApi([FakeRoute.value('PUT', '/trips/{id}', engineTripJson(plan))]);
    var built = 0;
    await pumpDayPlan(t, plan, size: const Size(360, 800), pages: [
      GetPage(name: AppRoutes.tripOverview, page: () {
        built++;
        return const Scaffold(body: Text('overview'));
      }),
      GetPage(name: AppRoutes.tripPlan, page: () => const TripPlanScreen()),
    ]);
    Get.toNamed(AppRoutes.tripOverview);
    await _settle(t);
    Get.toNamed(AppRoutes.tripPlan, arguments: {'tripId': 't1'});
    await _settle(t);
    expect(Get.currentRoute, AppRoutes.tripPlan);
    await t.tap(find.byKey(TripPlanScreen.saveTripKey));
    await _settle(t);
    expect(Get.currentRoute, AppRoutes.tripOverview);
    expect(find.text('overview'), findsOneWidget);
    expect(built, 1);
    await drainSave(t);
  });

  testWidgets('saved_plan_failed_flush_stays_on_the_plan', (t) async {
    final plan = dayPlanFixture();
    installFakeApi([FakeRoute.value('PUT', '/trips/{id}', null, code: 500, errorType: 'ServerError')]);
    var opened = 0;
    final c = await pumpDayPlan(t, plan, size: const Size(360, 800), pages: [
      GetPage(name: AppRoutes.tripOverview, page: () {
        opened++;
        return const Scaffold(body: Text('overview'));
      }),
    ]);
    c.scheduleSave();
    await t.tap(find.byKey(TripPlanScreen.saveTripKey));
    await t.pumpAndSettle();
    expect(opened, 0);
    expect(find.byType(TripPlanScreen), findsOneWidget);
    await drainSave(t);
  });

  testWidgets('unsaved_plan_reads_save_trip_and_opens_the_sheet', (t) async {
    final plan = dayPlanFixture();
    final api = installFakeApi([
      FakeRoute('POST', '/trips', (o) => engineTripJson(TripPlan.fromJson(Map<String, dynamic>.from((o.data as Map)['plan'] as Map)))),
    ]);
    final c = await pumpDayPlan(t, plan, size: const Size(360, 800), pages: [
      GetPage(name: AppRoutes.tripOverview, page: () => const Scaffold(body: Text('overview'))),
    ]);
    c.trip.value = null;
    c.markNewUnsavedForTest();
    await _settle(t);
    final button = find.byKey(TripPlanScreen.saveTripKey);
    expect(find.descendant(of: button, matching: find.text(TripStringsDayplan.saveTrip)), findsOneWidget);
    await t.tap(button);
    await _settle(t);
    expect(find.text(TripStringsSaveTrip.title), findsOneWidget);
    expect(api.calls('POST', '/trips'), isEmpty);

    await t.enterText(find.descendant(of: find.byKey(TripDatesSheet.nameKey), matching: find.byType(EditableText)), 'Lake Days');
    await t.pump();
    await t.tap(find.byKey(TripDatesSheet.ctaKey));
    await _settle(t);
    await _settle(t);
    expect(api.calls('POST', '/trips'), hasLength(1));
    expect(find.text('overview'), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.tripOverview);
    expect(c.isNewUnsaved, isFalse);
    await drainSave(t);
  });

  testWidgets('save_bar_five_sizes', (t) async {
    for (final size in fiveSizes) {
      await t.pumpWidget(const SizedBox.shrink());
      Get.reset();
      await pumpDayPlan(t, dayPlanFixture(perLeg: const [[2, 2], [1, 1]]), size: size);
      expect(t.takeException(), isNull, reason: sizeLabel(size));
      final button = find.byKey(TripPlanScreen.saveTripKey);
      expect(button, findsOneWidget, reason: sizeLabel(size));
      final r = t.getRect(button);
      expect(r.bottom, lessThanOrEqualTo(size.height), reason: sizeLabel(size));
      expect(r.left, greaterThanOrEqualTo(0), reason: sizeLabel(size));
      expect(r.right, lessThanOrEqualTo(size.width), reason: sizeLabel(size));
      expect(r.bottom, greaterThan(size.height * 0.75), reason: sizeLabel(size));
      expect(find.ancestor(of: button, matching: find.byType(Scrollable)), findsNothing, reason: sizeLabel(size));
    }
    await drainSave(t);
  });

  testWidgets('locked_plan_shows_view_button_instead', (t) async {
    for (final size in fiveSizes) {
      await t.pumpWidget(const SizedBox.shrink());
      Get.reset();
      await pumpDayPlan(t, dayPlanFixture(), size: size, lock: lockedByRequest);
      expect(t.takeException(), isNull, reason: sizeLabel(size));
      expect(find.byKey(TripPlanScreen.saveTripKey), findsNothing, reason: sizeLabel(size));
      final view = find.byKey(TripPlanScreen.viewButtonKey);
      expect(view, findsOneWidget, reason: sizeLabel(size));
      expect(t.getRect(view).bottom, lessThanOrEqualTo(size.height), reason: sizeLabel(size));
      expect(find.text(TripStringsDayplan.viewRequest), findsOneWidget, reason: sizeLabel(size));
    }
    await drainSave(t);
  });

  testWidgets('locked_plan_still_has_back_to_overview', (t) async {
    final plan = dayPlanFixture();
    installFakeApi([FakeRoute.value('PUT', '/trips/{id}', engineTripJson(plan))]);
    await pumpDayPlan(t, plan, size: const Size(360, 800), lock: lockedByRequest, pages: [
      GetPage(name: AppRoutes.tripOverview, page: () => const Scaffold(body: Text('overview'))),
    ]);
    final back = find.byKey(TripPlanScreen.lockedOverviewKey);
    expect(back, findsOneWidget);
    expect(t.getRect(back).bottom, lessThanOrEqualTo(800));
    expect(find.byKey(TripPlanScreen.viewButtonKey), findsOneWidget);
    await t.tap(back);
    await t.pumpAndSettle();
    expect(find.text('overview'), findsOneWidget);
    await drainSave(t);
  });
}
