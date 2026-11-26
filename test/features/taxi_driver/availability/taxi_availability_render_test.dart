import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_grid.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_models.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_screen.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_store.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_bookings_tab.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_controller.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_screen.dart';
import 'package:bakhli/features/taxi_driver/taxi_driver_deps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';
import '../calendar/taxi_cal_fixtures.dart';
import '../core/taxi_fixtures.dart';
import 'taxi_avail_fixtures.dart';

// Renders ta_d1 .. ta_d6 for the eye check against the mock frames D1 to D6.
void main() {
  setUpAll(() => initTestStorage('taxi_avail_render'));
  useOwnerRenderScale();
  setUp(OwnerCache.clearAll);
  tearDown(availTearDown);

  Future<void> settleHome(WidgetTester t) async {
    await t.runAsync(() async => TaxiHarnessProbe.home?.checkNotifications());
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<void> page(WidgetTester t, String id, AvailFake fake, {String? part, Future<void> Function(WidgetTester t)? arrange}) async {
    final h = await t.runAsync(() => availSetUp(fake));
    await renderOwnerFrame(t, id, TaxiAvailabilityScreen(controller: h!.controller), part: part, arrange: arrange);
    expect(t.takeException(), isNull);
  }

  Finder day(int n) => find.byWidgetPredicate((w) => w is TaxiAvailDayBox && w.cell.inMonth && w.cell.date.day == n);

  testWidgets('render ta_d1 Home with the Availability card', (t) async {
    final h = TaxiHarness.setUp(homeJson(taxi: {'newRequests': 2, 'missedRequests': 1, 'ratingAvg': 4.8, 'ratingCount': 72}));
    TaxiHarnessProbe.home = h.home;
    await renderOwnerFrame(t, 'ta_d1', const TaxiDriverHomeScreen(), arrange: settleHome);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    Get.delete<TaxiDriverHomeController>(force: true);
  });

  testWidgets('render ta_d2 Availability page', (t) async {
    await page(t, 'ta_d2', AvailFake(read: availJson()));
  });

  testWidgets('render ta_d3 sheet on a free day', (t) async {
    await page(t, 'ta_d3', AvailFake(read: availJson()), part: 'A', arrange: (t) async {
      await t.tap(day(27).hitTestable().first);
      await t.pump(const Duration(milliseconds: 400));
    });
  });

  testWidgets('render ta_d3 sheet at the limit', (t) async {
    await page(t, 'ta_d3', AvailFake(read: availJson(daysOff: const [])), part: 'B', arrange: (t) async {
      await t.tap(day(27).hitTestable().first);
      await t.pump(const Duration(milliseconds: 400));
      await t.enterText(find.byType(TextField), 'My daughter wedding in Almora, whole family travelling, taxi stays at home and I will not take any trip on these days. Back on Monday, will switch on again in the evening and check requests. Please wait');
      await t.pump();
    });
  });

  testWidgets('render ta_d3 sheet on an off day', (t) async {
    await page(t, 'ta_d3', AvailFake(read: availJson()), part: 'C', arrange: (t) async {
      await t.tap(day(27).hitTestable().first);
      await t.pump(const Duration(milliseconds: 400));
    });
  });

  testWidgets('render ta_d4 Home after Save', (t) async {
    final h = TaxiHarness.setUp(homeJson(taxi: {'newRequests': 2, 'ratingAvg': 4.8, 'ratingCount': 72}, availability: const {'month': '2026-11', 'bookings': 3, 'daysOff': 2}));
    TaxiHarnessProbe.home = h.home;
    await renderOwnerFrame(t, 'ta_d4', const TaxiDriverHomeScreen(), arrange: settleHome);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    Get.delete<TaxiDriverHomeController>(force: true);
  });

  testWidgets('render ta_d5 nothing changed', (t) async {
    await page(t, 'ta_d5', AvailFake(read: availJson(daysOff: const [])), part: 'A');
  });

  testWidgets('render ta_d5 switch off', (t) async {
    await page(t, 'ta_d5', AvailFake(read: availJson(daysOff: [dayRow('2026-11-27')], switchOn: false)), part: 'B');
  });

  testWidgets('render ta_d6 Bookings with OFF days', (t) async {
    final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
    final s = Get.put(TaxiAvailabilityStore(userId: () => 'user-a', clock: () => calToday));
    s.apply(TaxiAvailability.fromJson(availJson(today: '2026-11-21', daysOff: [dayRow('2026-11-27'), dayRow('2026-11-29'), dayRow('2026-11-30')], booked: const [])));
    TaxiDriverDeps.isDayOff = s.isOff;
    await renderOwnerFrame(t, 'ta_d6', TaxiBookingsTab(root: true, controller: c), arrange: (t) async {
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 120));
      }
    });
    expect(t.takeException(), isNull);
  });
}
