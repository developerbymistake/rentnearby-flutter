import 'package:bakhli/features/buddy/buddy_live.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/viewer/data/viewer_trip_cache.dart';
import 'package:bakhli/features/buddy/viewer/models/viewer_models.dart';
import 'package:bakhli/features/buddy/viewer/screens/former_share_screen.dart';
import 'package:bakhli/features/buddy/viewer/screens/travellers_viewer_screen.dart';
import 'package:bakhli/features/buddy/viewer/screens/trip_invite_screen.dart';
import 'package:bakhli/features/buddy/viewer/screens/viewer_day_plan_screen.dart';
import 'package:bakhli/features/buddy/viewer/screens/viewer_trip_screen.dart';
import 'package:bakhli/features/buddy/viewer/viewer_deps.dart';
import 'package:bakhli/features/buddy/viewer/widgets/joined_snack.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/screens/my_trips_screen.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'viewer_fixtures.dart';

Future<void> _render(WidgetTester t, String id, Widget screen, {Future<void> Function(WidgetTester)? arrange}) async {
  final f = await renderFrame(t, id, screen, arrange: arrange);
  expect(t.takeException(), isNull);
  expect(f.existsSync(), isTrue);
  await t.pump(const Duration(seconds: 6));
}

Widget _myTrips(SharedTrips s) {
  Get.put<MyTripsController>(FakeMyTrips(), permanent: true);
  registerViewerFakes(api: FakeViewerApi(sharedResult: BuddyOk(s)));
  return const MyTripsScreen();
}

void main() {
  useBuddyRenderScale();
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

  testWidgets('3.6 join as a viewer', (t) async {
    final api = FakeViewerApi(preview: BuddyOk(InvitePreview.fromJson(sample('s7_invite_preview'))));
    await _render(t, '3.6', TripInviteScreen(memberId: memberId, api: api));
  });

  Future<void> joinedTab(WidgetTester t) async {
    await t.tap(find.text('Joined'));
    await t.pump(const Duration(milliseconds: 300));
  }

  testWidgets('3.6a invite waiting', (t) async {
    await _render(t, '3.6a', _myTrips(sharedTrips(invites: true)), arrange: joinedTab);
  });

  testWidgets('3.8 my trips after joining', (t) async {
    await _render(t, '3.8', _myTrips(sharedTrips(items: true)), arrange: (t) async {
      await joinedTab(t);
      JoinedSnack.show(tripId);
      await t.pump(const Duration(milliseconds: 300));
    });
  });

  testWidgets('3.9 viewer overview', (t) async {
    final api = FakeViewerApi()..queueViews([viewOk(s14())]);
    final ledger = FakeViewerLedger(summaryResult: BuddyOk(summaryDay1()));
    await _render(t, '3.9', ViewerTripScreen(tripId: tripId, api: api, ledger: ledger));
  });

  testWidgets('3.9a nothing booked', (t) async {
    final api = FakeViewerApi()..queueViews([viewOk(s14NotBooked())]);
    await _render(t, '3.9a', ViewerTripScreen(tripId: tripId, api: api, ledger: FakeViewerLedger()));
  });

  testWidgets('3.10 day plan', (t) async {
    final api = FakeViewerApi()..queueViews([viewOk(s14())]);
    final ledger = FakeViewerLedger(summaryResult: BuddyOk(summaryDay1()));
    await _render(t, '3.10', ViewerDayPlanScreen(tripId: tripId, api: api, ledger: ledger));
  });

  testWidgets('3.14 travellers viewer', (t) async {
    await _render(t, '3.14', TravellersViewerScreen(tripId: tripId, members: viewerMembers(), api: FakeViewerApi()));
  });

  testWidgets('3.14a former card', (t) async {
    await _render(t, '3.14a', _myTrips(sharedTrips(former: true)));
  });

  testWidgets('3.14b my share', (t) async {
    final ledger = FakeViewerLedger(balancesResult: BuddyOk(formerBalances()));
    final expenses = FakeViewerExpenses(BuddyOk(formerList()));
    await _render(t, '3.14b', FormerShareScreen(tripId: tripId, expenses: expenses, ledger: ledger));
  });

  testWidgets('3.15 invite ended', (t) async {
    final api = FakeViewerApi(
      preview: const BuddyRefused(type: 'InviteEnded', statusCode: 404, data: {'reason': 'Cancelled', 'title': 'Uttarakhand Hills Trip', 'ownerName': 'Rahul'}),
    );
    await _render(t, '3.15', TripInviteScreen(memberId: memberId, api: api));
  });

  testWidgets('3.15a no longer on this trip', (t) async {
    final api = FakeViewerApi()..queueViews([notOnTrip()]);
    await _render(t, '3.15a', ViewerTripScreen(tripId: tripId, api: api, ledger: FakeViewerLedger()));
  });

  testWidgets('3.15b trip deleted', (t) async {
    ViewerTripCache.write(tripId, s14(), '"v1"');
    final api = FakeViewerApi()..queueViews([tripGone()]);
    await _render(t, '3.15b', ViewerTripScreen(tripId: tripId, api: api, ledger: FakeViewerLedger()));
  });
}
