import 'package:bakhli/features/buddy/buddy_live.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/viewer/data/viewer_trip_cache.dart';
import 'package:bakhli/features/buddy/viewer/viewer_deps.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/screens/my_trips_screen.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/real_phone.dart';
import '../buddy/viewer/viewer_fixtures.dart';

Future<FakeViewerApi> _pump(WidgetTester t, {bool shared = true}) async {
  Get.put<MyTripsController>(FakeMyTrips(), permanent: true);
  final api = FakeViewerApi(sharedResult: BuddyOk(shared ? sharedTrips(items: true, invites: true) : sharedTrips()));
  registerViewerFakes(api: api);
  await pumpPhone(t, const MyTripsScreen(), toastHost: true);
  await settlePhone(t);
  return api;
}

Future<void> _tab(WidgetTester t, String label) async {
  await t.tap(find.text(label));
  await settlePhone(t);
}

void main() {
  setUp(() {
    useMemoryCache();
    TripClock.clockUtc = () => DateTime.utc(2026, 5, 10, 6);
  });
  tearDown(() {
    ViewerDeps.debugReset();
    ViewerTripCache.debugReset();
    TripClock.resetClock();
    BuddyLive.reset();
    Get.reset();
  });

  testWidgets('My plans is the first tab: own trips, no shared list', (t) async {
    await _pump(t);
    expect(find.text('My plans'), findsOneWidget);
    expect(find.text('Joined'), findsOneWidget);
    expect(find.text('Rajasthan Forts Trip'), findsOneWidget);
    expect(find.byKey(const ValueKey('shared_with_me')), findsNothing);
    expect(t.takeException(), isNull);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('Joined shows the shared list with the waiting invite, not my own trips', (t) async {
    await _pump(t);
    await _tab(t, 'Joined');
    expect(find.byKey(const ValueKey('shared_with_me')), findsOneWidget);
    expect(find.text('Invite waiting'), findsOneWidget);
    expect(find.text('Rajasthan Forts Trip'), findsNothing);
    expect(find.byKey(const ValueKey('my_trips_joined_empty')), findsNothing);
    await _tab(t, 'My plans');
    expect(find.text('Rajasthan Forts Trip'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('Joined with nothing shows the empty card', (t) async {
    await _pump(t, shared: false);
    await _tab(t, 'Joined');
    expect(find.byKey(const ValueKey('my_trips_joined_empty')), findsOneWidget);
    expect(find.text('No joined trips yet'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('I-20: pull to refresh on Joined reloads the shared list', (t) async {
    final api = await _pump(t);
    await _tab(t, 'Joined');
    final before = api.sharedCalls;
    await t.fling(find.byType(SingleChildScrollView).first, const Offset(0, 500), 1200);
    await settlePhone(t);
    await t.pump(const Duration(seconds: 1));
    await settlePhone(t);
    expect(api.sharedCalls, greaterThan(before));
    expect(t.takeException(), isNull);
    await t.pump(const Duration(seconds: 6));
  });
}
