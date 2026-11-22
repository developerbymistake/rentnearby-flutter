import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/buddy/sharing/models/sharing_models.dart';
import 'package:bakhli/features/seeker_home/seeker_feed_model.dart';
import 'package:bakhli/features/seeker_home/seeker_trip_card.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/owner_fakes.dart';
import '../buddy/sharing/sharing_fixtures.dart' as fx;

SeekerTripCard _card({String? role, bool onTrip = false, SeekerNextStep? next}) => SeekerTripCard.fromJson({
      'state': onTrip ? 'OnTrip' : 'InProgress',
      'tripId': 'trip-1',
      'title': 'Nainital trip',
      'startDate': '2026-11-26',
      'endDate': '2026-11-29',
      'done': 3,
      'total': 5,
      'nextStep': next?.toJson(),
      if (onTrip) 'today': {'dayNumber': 2, 'totalDays': 4, 'cityName': 'Mukteshwar', 'placeCount': 4, 'placesSeen': 1},
      'role': ?role,
    });

const _reply = SeekerStatus(kind: SeekerStatusKind.reply, count: 2, key: 'k2');

final _seen = <String, Object?>{};

GetPage _stub(String name) => GetPage(
      name: name,
      page: () {
        _seen[name] = Get.arguments;
        return Scaffold(body: Text(name));
      },
    );

Widget _app(Widget home) => GetMaterialApp(
      getPages: [
        for (final r in [AppRoutes.tripPlan, AppRoutes.tripDayPlan, AppRoutes.tripView, AppRoutes.tripOverview, AppRoutes.tripReplies]) _stub(r),
      ],
      home: Scaffold(body: SingleChildScrollView(child: home)),
    );

void main() {
  setUp(_seen.clear);
  tearDown(Get.reset);

  test('role: Viewer is a viewer card; unknown, missing or wrong type is the owner card', () {
    expect(_card(role: 'Viewer').isViewer, isTrue);
    expect(_card(role: 'Owner').isViewer, isFalse);
    expect(_card(role: 'Admin').isViewer, isFalse);
    expect(_card().isViewer, isFalse);
    expect(SeekerTripCard.fromJson({'state': 'InProgress', 'tripId': 't', 'role': 7}).isViewer, isFalse);
    expect(SeekerTripCard.fromJson(_card(role: 'Viewer').toJson()).isViewer, isTrue);
  });

  testWidgets('viewer card: no progress, no next step, no status pill; Open trip opens the trip view', (t) async {
    final card = _card(role: 'Viewer', next: const SeekerNextStep(key: 'taxi', kind: SeekerStepKind.taxi));
    await t.pumpWidget(_app(SeekerTripCardView(feed: SeekerFeed(tripCard: card), status: _reply)));
    expect(find.text('Shared with me'), findsOneWidget);
    expect(find.text('3 of 5 done'), findsNothing);
    expect(find.text('Next: book a taxi'), findsNothing);
    expect(find.text('2 stays replied. Pick one.'), findsNothing);
    await t.tap(find.text('Open trip'));
    await t.pumpAndSettle();
    expect(_seen[AppRoutes.tripView], {'tripId': 'trip-1'});
    expect(_seen.containsKey(AppRoutes.tripOverview), isFalse);
  });

  testWidgets('owner card on the trip: Today’s plan opens the owner plan on today', (t) async {
    await t.pumpWidget(_app(SeekerTripCardView(feed: SeekerFeed(tripCard: _card(onTrip: true)))));
    await t.tap(find.text('Today’s plan'));
    await t.pumpAndSettle();
    expect((_seen[AppRoutes.tripPlan] as Map)['tripId'], 'trip-1');
    expect((_seen[AppRoutes.tripPlan] as Map)['day'], 2);
    expect(_seen.containsKey(AppRoutes.tripDayPlan), isFalse);
  });

  testWidgets('viewer card on the trip: Today’s plan opens the viewer day plan, no places-seen line', (t) async {
    await t.pumpWidget(_app(SeekerTripCardView(feed: SeekerFeed(tripCard: _card(role: 'Viewer', onTrip: true)))));
    expect(find.text('1 of 4 places seen'), findsNothing);
    await t.tap(find.text('Today’s plan'));
    await t.pumpAndSettle();
    expect(_seen[AppRoutes.tripDayPlan], {'tripId': 'trip-1', 'day': 2});
  });

  testWidgets('owner card: status pill still shows', (t) async {
    await t.pumpWidget(_app(SeekerTripCardView(feed: SeekerFeed(tripCard: _card()), status: _reply)));
    expect(find.text('2 stays replied. Pick one.'), findsOneWidget);
    expect(find.text('Continue your trip'), findsOneWidget);
  });

  group('Continue opens the next step over the overview (D-18)', () {
    test('journey and unknown kinds open the overview only', () async {
      expect(await SeekerTripActions.openStepWhenReady('trip-1', const SeekerNextStep(key: 'gettingThere', kind: SeekerStepKind.journey)), isFalse);
      expect(await SeekerTripActions.openStepWhenReady('trip-1', const SeekerNextStep(key: 'x', kind: SeekerStepKind.unknown)), isFalse);
    });

    testWidgets('plan kind waits for the trip, then opens the plan on top of the overview', (t) async {
      Get.put<TabConfigController>(FakeTabs());
      final c = Get.put(TripPlanController());
      await t.pumpWidget(_app(const SizedBox()));
      Get.toNamed(AppRoutes.tripOverview, arguments: {'tripId': fx.tripId});
      await t.pumpAndSettle();
      final opened = SeekerTripActions.openStepWhenReady(fx.tripId, const SeekerNextStep(key: 'plan', kind: SeekerStepKind.plan),
          timeout: const Duration(seconds: 2));
      await t.pump();
      expect(_seen.containsKey(AppRoutes.tripPlan), isFalse);
      final trip = fx.trip(sharing: const TripSharingBlock(travellerCount: 1, viewerCount: 0, pendingInvites: 0, firstTravellers: [], expenses: TripExpenseCard.none));
      c.plan.value = trip.plan;
      c.trip.value = trip;
      await t.pumpAndSettle();
      expect((_seen[AppRoutes.tripPlan] as Map)['tripId'], fx.tripId);
      expect(Get.previousRoute, AppRoutes.tripOverview);
      await t.runAsync(() => opened.timeout(const Duration(seconds: 1), onTimeout: () => true));
    });

    testWidgets('the step is not opened when the trip never loads', (t) async {
      Get.put<TabConfigController>(FakeTabs());
      Get.put(TripPlanController());
      await t.pumpWidget(_app(const SizedBox()));
      Get.toNamed(AppRoutes.tripOverview, arguments: {'tripId': 'trip-1'});
      await t.pumpAndSettle();
      final r = await t.runAsync(() => SeekerTripActions.openStepWhenReady('trip-1', const SeekerNextStep(key: 'plan', kind: SeekerStepKind.plan),
          timeout: const Duration(milliseconds: 200)));
      expect(r, isFalse);
      expect(_seen.containsKey(AppRoutes.tripPlan), isFalse);
    });
  });
}
