import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/features/trip/trip_strings_dayplan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../journeys/fake_api.dart';
import '../../support/five_sizes.dart';
import 'support/engine_rig.dart';
import 'trip_day_plan_screen_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  testWidgets('save_trip_label_and_action', (t) async {
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
    expect(find.descendant(of: button, matching: find.text(TripStringsDayplan.saveTrip)), findsOneWidget);
    expect(find.text('Next · Make it easy'), findsNothing);

    await t.tap(button);
    await t.pumpAndSettle();
    expect(api.calls('PUT', '/trips/t1'), hasLength(1));
    expect(find.text('overview'), findsOneWidget);
    expect(args, {'tripId': 't1'});
    await drainSave(t);
  });

  testWidgets('save_trip_failure_stays_on_the_plan', (t) async {
    final plan = dayPlanFixture();
    installFakeApi([FakeRoute.value('PUT', '/trips/{id}', null, code: 500, errorType: 'ServerError')]);
    var opened = 0;
    await pumpDayPlan(t, plan, size: const Size(360, 800), pages: [
      GetPage(name: AppRoutes.tripOverview, page: () {
        opened++;
        return const Scaffold(body: Text('overview'));
      }),
    ]);
    await t.tap(find.byKey(TripPlanScreen.saveTripKey));
    await t.pumpAndSettle();
    expect(opened, 0);
    expect(find.byType(TripPlanScreen), findsOneWidget);
    await drainSave(t);
  });

  testWidgets('save_trip_bar_five_sizes', (t) async {
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
}
