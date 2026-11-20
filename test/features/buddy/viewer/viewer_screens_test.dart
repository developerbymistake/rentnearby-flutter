import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:bakhli/features/buddy/buddy_live.dart';
import 'package:bakhli/features/buddy/ledger/models/ledger_models.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/viewer/controllers/shared_trips_controller.dart';
import 'package:bakhli/features/buddy/viewer/data/viewer_trip_cache.dart';
import 'package:bakhli/features/buddy/viewer/models/viewer_models.dart';
import 'package:bakhli/features/buddy/viewer/screens/former_share_screen.dart';
import 'package:bakhli/features/buddy/viewer/screens/travellers_viewer_screen.dart';
import 'package:bakhli/features/buddy/viewer/screens/trip_invite_screen.dart';
import 'package:bakhli/features/buddy/viewer/screens/viewer_day_plan_screen.dart';
import 'package:bakhli/features/buddy/viewer/screens/viewer_trip_screen.dart';
import 'package:bakhli/features/buddy/viewer/viewer_deps.dart';
import 'package:bakhli/features/buddy/viewer/viewer_rules.dart';
import 'package:bakhli/features/buddy/viewer/widgets/shared_with_me_section.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'viewer_fixtures.dart';

Future<void> _pump(WidgetTester t, Widget home) async {
  t.view.devicePixelRatio = 2;
  t.view.physicalSize = const Size(784, 1600);
  addTearDown(t.view.reset);
  await t.pumpWidget(app(home));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _drain(WidgetTester t) async => t.pump(const Duration(seconds: 6));

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f.last);
  await t.tap(f.last);
  await _settle(t);
}

Future<void> _tapText(WidgetTester t, String text) => _tap(t, find.text(text));

void _expectOpened(String route, Map<String, Object> args) {
  expect(opened.last.$1, route);
  expect(Map<String, Object?>.from(opened.last.$2! as Map), args);
}

Widget _launcher(Widget screen) => Builder(
      builder: (context) => Scaffold(
        body: Center(child: TextButton(onPressed: () => Get.to<void>(() => screen), child: const Text('launch'))),
      ),
    );

void main() {
  setUp(() {
    DS.applyApproved();
    opened.clear();
    toMyTripsCalls = 0;
    useMemoryCache();
    TripClock.clockUtc = () => DateTime.utc(2026, 5, 10, 6);
  });
  tearDown(() {
    DS.debugReset();
    ViewerDeps.debugReset();
    ViewerTripCache.debugReset();
    TripClock.resetClock();
    BuddyLive.reset();
    Get.reset();
  });

  group('rules', () {
    test('foot line follows the dates', () {
      final s = DateTime(2026, 5, 16);
      final e = DateTime(2026, 5, 22);
      expect(ViewerRules.footLine(start: s, end: e, dayCount: 7, today: DateTime(2026, 5, 10)), 'Starts 16 May');
      expect(ViewerRules.footLine(start: s, end: e, dayCount: 7, today: DateTime(2026, 5, 18)), 'Day 3 of 7');
      expect(ViewerRules.footLine(start: s, end: e, dayCount: 7, today: DateTime(2026, 5, 23)), 'Ended 22 May');
      expect(ViewerRules.footLine(dayCount: 7, today: DateTime(2026, 5, 23)), 'Dates not set');
    });

    test('durations, road time, leg dates, money line', () {
      expect(ViewerRules.duration(370), '6 h 10 m');
      expect(ViewerRules.duration(45), '45 m');
      expect(ViewerRules.duration(60), '1 h');
      expect(ViewerRules.road(10), '10 min');
      final t = s14();
      expect(ViewerRules.legDates(t, t.legs.first), '16-18 May');
      expect(ViewerRules.taxiWhen(t.taxi), '16 May, 9:00 am');
      expect(ViewerRules.moneyLine(-11816, 'Rahul'), 'You owe Rahul ₹11,816');
      expect(ViewerRules.moneyLine(500, 'Rahul'), 'You get back ₹500');
    });

    test('offline copy keeps the etag and drops on gone', () {
      ViewerTripCache.write(tripId, s14(), '"v1"');
      expect(ViewerTripCache.read(tripId)?.etag, '"v1"');
      ViewerTripCache.watchGone();
      BuddyLive.goneTrip.value = tripId;
      expect(ViewerTripCache.read(tripId), isNull);
    });
  });

  group('3.6 trip invite', () {
    testWidgets('ready shows every line, Join goes to My trips with the snack', (t) async {
      final api = FakeViewerApi(preview: BuddyOk(InvitePreview.fromJson(sample('s7_invite_preview'))));
      registerViewerFakes(api: api);
      await _pump(t, TripInviteScreen(memberId: memberId, api: api));
      for (final s in [
        'Trip invite',
        'From Rahul · Bakhli#48291736',
        'YOU ARE INVITED',
        'Join Rahul’s Uttarakhand Hills Trip as a viewer',
        'Nainital',
        'Rishikesh',
        'Mussoorie',
        '16 – 22 May',
        '7 days',
        '1 traveller',
        'You will see',
        'Day plan and dates',
        'Stay and taxi summary',
        'Expenses and your share',
        'You will not see',
        'Chats and offers',
        'Phone numbers',
        'Payment ids',
        'Not now',
        'Join trip',
      ]) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      final before = BuddyLive.sharedTrips.value;
      await _tapText(t, 'Join trip');
      expect(api.acceptCalls, 1);
      expect(toMyTripsCalls, 1);
      expect(BuddyLive.sharedTrips.value, before + 1);
      expect(find.text('You joined as a viewer'), findsOneWidget);
      await _tapText(t, 'Open');
      expect(opened.last.$1, AppRoutes.tripView);
      await _drain(t);
    });

    testWidgets('no dates reads Not set; Not now keeps the invite', (t) async {
      final j = sample('s7_invite_preview')
        ..['startDate'] = null
        ..['endDate'] = null;
      final api = FakeViewerApi(preview: BuddyOk(InvitePreview.fromJson(j)));
      registerViewerFakes(api: api);
      await _pump(t, _launcher(TripInviteScreen(memberId: memberId, api: api)));
      await _tapText(t, 'launch');
      expect(find.text('Not set'), findsOneWidget);
      await _tapText(t, 'Not now');
      expect(find.text('launch'), findsOneWidget);
      expect(api.acceptCalls + api.declineCalls, 0);
    });

    testWidgets('Decline sits in the menu and is silent', (t) async {
      final api = FakeViewerApi(preview: BuddyOk(InvitePreview.fromJson(sample('s7_invite_preview'))));
      registerViewerFakes(api: api);
      await _pump(t, TripInviteScreen(memberId: memberId, api: api));
      expect(find.text('Decline'), findsNothing);
      await _tap(t, find.byKey(const ValueKey('invite_menu')));
      await _tapText(t, 'Decline');
      expect(api.declineCalls, 1);
      expect(toMyTripsCalls, 1);
      expect(find.text('Invite declined'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('already a member opens the trip view', (t) async {
      final j = sample('s7_invite_preview')
        ..['alreadyMember'] = true
        ..['tripId'] = tripId;
      final api = FakeViewerApi(preview: BuddyOk(InvitePreview.fromJson(j)));
      registerViewerFakes(api: api);
      await _pump(t, TripInviteScreen(memberId: memberId, api: api));
      await _settle(t);
      expect(opened.any((o) => o.$1 == AppRoutes.tripView), isTrue);
    });

    testWidgets('3.15 ended invite: reasons and the full trip form', (t) async {
      final api = FakeViewerApi(
        preview: const BuddyRefused(type: 'InviteEnded', statusCode: 404, data: {'reason': 'Cancelled', 'title': 'Uttarakhand Hills Trip', 'ownerName': 'Rahul'}),
      );
      registerViewerFakes(api: api);
      await _pump(t, TripInviteScreen(memberId: memberId, api: api));
      expect(find.text('From Rahul'), findsOneWidget);
      expect(find.text('This invite has ended'), findsOneWidget);
      expect(find.text('Ask Rahul for a new one.'), findsOneWidget);
      expect(find.text('Uttarakhand Hills Trip'), findsOneWidget);
      expect(find.text('Invite cancelled by the owner'), findsOneWidget);
      await _tapText(t, 'Go to my trips');
      expect(toMyTripsCalls, 1);
    });

    testWidgets('expired and declined reasons; unknown has no card', (t) async {
      for (final (reason, line) in [('Expired', 'Invite expired'), ('Declined', 'You declined this invite')]) {
        final api = FakeViewerApi(preview: BuddyRefused(type: 'InviteEnded', statusCode: 404, data: {'reason': reason, 'title': 'Goa', 'ownerName': 'Neha'}));
        await _pump(t, TripInviteScreen(key: ValueKey(reason), memberId: memberId, api: api));
        expect(find.text(line), findsOneWidget);
      }
      final api = FakeViewerApi(preview: const BuddyRefused(type: 'InviteEnded', statusCode: 404, data: {'reason': 'Unknown'}));
      await _pump(t, TripInviteScreen(key: const ValueKey('u'), memberId: memberId, api: api));
      expect(find.text('Ask the owner for a new one.'), findsOneWidget);
      expect(find.byKey(const ValueKey('viewer_ghost')), findsNothing);
    });

    testWidgets('join on a full trip shows This trip is full', (t) async {
      final api = FakeViewerApi(
        preview: BuddyOk(InvitePreview.fromJson(sample('s7_invite_preview'))),
        accept: const BuddyRefused(type: 'TripFull', statusCode: 409),
      );
      registerViewerFakes(api: api);
      await _pump(t, TripInviteScreen(memberId: memberId, api: api));
      await _tapText(t, 'Join trip');
      expect(find.text('This trip is full'), findsOneWidget);
      expect(find.text('Ask Rahul to make room.'), findsOneWidget);
    });

    testWidgets('load failure shows Retry', (t) async {
      final api = FakeViewerApi(preview: const BuddyFailed(message: 'x'));
      await _pump(t, TripInviteScreen(memberId: memberId, api: api));
      expect(find.text('Could not load'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('3.6a 3.8 3.14a shared with me', () {
    testWidgets('nothing shared draws nothing', (t) async {
      final api = FakeViewerApi(sharedResult: BuddyOk(sharedTrips()));
      registerViewerFakes(api: api);
      await _pump(t, const Scaffold(body: SingleChildScrollView(child: SharedWithMeSection())));
      expect(find.text('Shared with me'), findsNothing);
    });

    testWidgets('invite, joined and former cards with their taps', (t) async {
      final api = FakeViewerApi(sharedResult: BuddyOk(sharedTrips(items: true, invites: true, former: true)));
      registerViewerFakes(api: api);
      await _pump(t, const Scaffold(body: SingleChildScrollView(child: SharedWithMeSection())));
      for (final s in [
        'Shared with me',
        'Trip invite',
        'Invite waiting',
        'from Rahul · 16 – 22 May',
        'Rahul invited you to Uttarakhand Hills Trip',
        '7 days · 3 cities',
        'View',
        'Viewer',
        'by Rahul · 16 – 22 May',
        '18 places',
        '2',
        'travellers',
        '100%',
        'ready',
        'booked',
        'saved',
        'Starts 16 May',
        'Open the plan',
        'Left',
        'You owe Rahul ₹11,816',
        '6 expenses you share',
        'See my share',
      ]) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
      await _tapText(t, 'View');
      _expectOpened(AppRoutes.tripInvite, {'memberId': memberId});
      Get.back<void>();
      await _settle(t);
      await _tapText(t, 'Open the plan');
      expect(opened.last.$1, AppRoutes.tripView);
      Get.back<void>();
      await _settle(t);
      await _tapText(t, 'See my share');
      expect(opened.last.$1, AppRoutes.tripMyShare);
    });

    testWidgets('a tick reloads; removed reads Removed; you get back', (t) async {
      final api = FakeViewerApi(sharedResult: BuddyOk(sharedTrips()));
      registerViewerFakes(api: api);
      await _pump(t, const Scaffold(body: SingleChildScrollView(child: SharedWithMeSection())));
      api.sharedResult = BuddyOk(SharedTrips(
        items: const [],
        invites: const [],
        former: const [FormerTripCard(tripId: tripId, title: 'Goa', ownerName: 'Neha', endedHow: 'Removed', myNet: 500, sharedCount: 1)],
        counts: const SharedTripCounts(),
      ));
      BuddyLive.sharedTrips.value++;
      await _settle(t);
      expect(find.text('Removed'), findsOneWidget);
      expect(find.text('You get back ₹500'), findsOneWidget);
      expect(find.text('1 expense you share'), findsOneWidget);
    });

    testWidgets('past shared trips row loads state=past', (t) async {
      final api = FakeViewerApi(sharedResult: BuddyOk(sharedTrips(past: 2)), pastResult: BuddyOk(sharedTrips(items: true)));
      registerViewerFakes(api: api);
      await _pump(t, const Scaffold(body: SingleChildScrollView(child: SharedWithMeSection())));
      expect(find.text('Past shared trips (2)'), findsOneWidget);
      await _tapText(t, 'Past shared trips (2)');
      expect(find.text('Open the plan'), findsOneWidget);
      expect(SharedTripsController.to.past.length, 1);
    });
  });

  group('3.9 3.9a viewer overview', () {
    testWidgets('booked trip: five cards, view only, taps', (t) async {
      final api = FakeViewerApi()..queueViews([viewOk(s14())]);
      final ledger = FakeViewerLedger(summaryResult: BuddyOk(summaryDay1()));
      registerViewerFakes(api: api, ledger: ledger);
      await _pump(t, ViewerTripScreen(tripId: tripId, api: api, ledger: ledger));
      for (final s in [
        'Trip overview',
        'Shared by Rahul',
        'View only',
        'Uttarakhand Hills Trip',
        '3 cities · 7 days · 2 travellers',
        'Itinerary',
        'Saved',
        '7 days, 18 places',
        'Taxi',
        'Booked',
        'Dzire · Suresh · 16 May, 9:00 am',
        'View booking',
        'Stay',
        'Snow View Hotel, 3 nights',
        'View stays',
        'Travellers',
        '2 joined',
        'See all',
        'Expenses',
        'Day 1',
        'Spent ₹9,000 · Your share ₹4,500',
      ]) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      for (final s in ['Request taxi', 'Find stays', 'Add expense', 'Chat']) {
        expect(find.text(s), findsNothing, reason: s);
      }
      expect(ViewerTripCache.read(tripId)?.etag, '"v1"');
      await _tap(t, find.byKey(const ValueKey('viewer_taxi_button')));
      expect(find.text('Dzire'), findsOneWidget);
      expect(find.text('Suresh'), findsOneWidget);
      await t.tapAt(const Offset(10, 10));
      await _settle(t);
      await _tap(t, find.byKey(const ValueKey('viewer_itinerary_button')));
      expect(opened.last.$1, AppRoutes.tripDayPlan);
      Get.back<void>();
      await _settle(t);
      await _tap(t, find.byKey(const ValueKey('viewer_travellers_button')));
      expect(opened.last.$1, AppRoutes.tripTravellers);
      Get.back<void>();
      await _settle(t);
      await _tap(t, find.byKey(const ValueKey('viewer_expenses_button')));
      expect(opened.last.$1, AppRoutes.tripExpenses);
    });

    testWidgets('stays sheet lists only the allowed fields', (t) async {
      final api = FakeViewerApi()..queueViews([viewOk(s14())]);
      registerViewerFakes(api: api, ledger: FakeViewerLedger());
      await _pump(t, ViewerTripScreen(tripId: tripId, api: api));
      await _tap(t, find.byKey(const ValueKey('viewer_stay_button')));
      expect(find.text('Nainital · Snow View Hotel'), findsOneWidget);
      expect(find.text('3 nights'), findsOneWidget);
      expect(find.text('Sat 16 May'), findsOneWidget);
      expect(find.text('Tue 19 May'), findsOneWidget);
    });

    testWidgets('3.9a nothing booked: no buttons but Itinerary and Travellers', (t) async {
      final api = FakeViewerApi()..queueViews([viewOk(s14NotBooked())]);
      registerViewerFakes(api: api, ledger: FakeViewerLedger());
      await _pump(t, ViewerTripScreen(tripId: tripId, api: api));
      expect(find.text('7 days, 18 places · Dates not set'), findsOneWidget);
      expect(find.text('Not booked yet'), findsNWidgets(2));
      expect(find.text('Rahul has not added any expense yet'), findsOneWidget);
      expect(find.text('View booking'), findsNothing);
      expect(find.text('View stays'), findsNothing);
      expect(find.text('Booked'), findsNothing);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
    });

    testWidgets('arranging taxi shows the chip and no button', (t) async {
      final j = s14Json()..['taxi'] = {'state': 'Arranging'};
      final api = FakeViewerApi()..queueViews([viewOk(ViewerTrip.fromJson(j))]);
      registerViewerFakes(api: api, ledger: FakeViewerLedger());
      await _pump(t, ViewerTripScreen(tripId: tripId, api: api));
      expect(find.text('Arranging'), findsOneWidget);
      expect(find.text('View booking'), findsNothing);
    });

    testWidgets('304 keeps the copy and sends If-None-Match; offline shows the saved line', (t) async {
      ViewerTripCache.write(tripId, s14(), '"v1"');
      final api = FakeViewerApi()..queueViews([notModified()]);
      registerViewerFakes(api: api, ledger: FakeViewerLedger());
      await _pump(t, ViewerTripScreen(tripId: tripId, api: api));
      expect(api.etags.first, '"v1"');
      expect(find.text('Snow View Hotel, 3 nights'), findsOneWidget);
      expect(find.text('Offline. Showing the saved copy.'), findsNothing);
      api.views
        ..clear()
        ..add(const BuddyOffline<ViewerTripResponse>());
      BuddyLive.tripView(tripId).value++;
      await _settle(t);
      expect(find.text('Offline. Showing the saved copy.'), findsOneWidget);
      expect(find.text('Snow View Hotel, 3 nights'), findsOneWidget);
    });

    testWidgets('load failure without a copy shows Retry', (t) async {
      final api = FakeViewerApi()..queueViews([const BuddyFailed<ViewerTripResponse>(message: 'x')]);
      registerViewerFakes(api: api, ledger: FakeViewerLedger());
      await _pump(t, ViewerTripScreen(tripId: tripId, api: api));
      expect(find.text('Could not load'), findsOneWidget);
      api.views
        ..clear()
        ..add(viewOk(s14()));
      await _tapText(t, 'Retry');
      expect(find.text('Trip overview'), findsOneWidget);
      expect(find.text('2 joined'), findsOneWidget);
    });

    testWidgets('role Owner replaces with the owner overview', (t) async {
      final api = FakeViewerApi()..queueViews([viewOk(s14(role: 'Owner'))]);
      registerViewerFakes(api: api, ledger: FakeViewerLedger());
      await _pump(t, ViewerTripScreen(tripId: tripId, api: api));
      await _settle(t);
      expect(opened.last.$1, AppRoutes.tripOverview);
    });

    testWidgets('3.15a 403 NotOnTrip clears the copy, See my share', (t) async {
      ViewerTripCache.write(tripId, s14(), '"v1"');
      final api = FakeViewerApi()..queueViews([notOnTrip()]);
      registerViewerFakes(api: api, ledger: FakeViewerLedger());
      await _pump(t, ViewerTripScreen(tripId: tripId, api: api));
      expect(ViewerTripCache.read(tripId), isNull);
      expect(find.text('Shared by Rahul'), findsOneWidget);
      expect(find.text('You are no longer on this trip.'), findsOneWidget);
      expect(find.text('Your share is still open.'), findsOneWidget);
      expect(find.text('16 – 22 May · by Rahul'), findsOneWidget);
      await _tapText(t, 'See my share');
      expect(opened.last.$1, AppRoutes.tripMyShare);
    });

    testWidgets('3.15a with nothing open: Go to my trips', (t) async {
      final api = FakeViewerApi()..queueViews([notOnTrip(hasShare: false)]);
      registerViewerFakes(api: api, ledger: FakeViewerLedger());
      await _pump(t, ViewerTripScreen(tripId: tripId, api: api));
      expect(find.text('Your share is still open.'), findsNothing);
      await _tapText(t, 'Go to my trips');
      expect(toMyTripsCalls, 1);
    });

    testWidgets('3.15b 404 deletes the copy, keeps its words', (t) async {
      ViewerTripCache.write(tripId, s14(), '"v1"');
      final api = FakeViewerApi()..queueViews([tripGone()]);
      registerViewerFakes(api: api, ledger: FakeViewerLedger());
      await _pump(t, ViewerTripScreen(tripId: tripId, api: api));
      expect(find.text('This trip was deleted.'), findsOneWidget);
      expect(find.text('The plan and the expenses are gone.'), findsOneWidget);
      expect(find.text('Shared by Rahul'), findsOneWidget);
      expect(find.text('16 – 22 May · by Rahul'), findsOneWidget);
      expect(ViewerTripCache.read(tripId), isNull);
      await _tapText(t, 'Go to my trips');
      expect(toMyTripsCalls, 1);
    });

    testWidgets('3.15b opened with deleted: true and no copy has no ghost', (t) async {
      final api = FakeViewerApi();
      registerViewerFakes(api: api, ledger: FakeViewerLedger());
      await _pump(t, ViewerTripScreen(tripId: tripId, deleted: true, api: api));
      expect(find.text('This trip was deleted.'), findsOneWidget);
      expect(find.byKey(const ValueKey('viewer_ghost')), findsNothing);
      expect(api.etags, isEmpty);
    });

    testWidgets('a removed push clears the copy while the trip is open', (t) async {
      final api = FakeViewerApi()..queueViews([viewOk(s14())]);
      registerViewerFakes(api: api, ledger: FakeViewerLedger());
      await _pump(t, ViewerTripScreen(tripId: tripId, api: api));
      expect(ViewerTripCache.read(tripId), isNotNull);
      api.views
        ..clear()
        ..add(notOnTrip());
      BuddyLive.goneTrip.value = tripId;
      await _settle(t);
      expect(ViewerTripCache.read(tripId), isNull);
      expect(find.text('You are no longer on this trip.'), findsOneWidget);
    });
  });

  group('3.10 day plan', () {
    testWidgets('legs, days, places, road time and the spent row', (t) async {
      final api = FakeViewerApi()..queueViews([viewOk(s14())]);
      final ledger = FakeViewerLedger(summaryResult: BuddyOk(summaryDay1()));
      registerViewerFakes(api: api, ledger: ledger);
      await _pump(t, ViewerDayPlanScreen(tripId: tripId, api: api, ledger: ledger));
      for (final s in [
        'Uttarakhand Hills Trip',
        '7 days · 16 – 22 May · by Rahul',
        'Map',
        'Nainital',
        'Day 1-3 · 16-18 May',
        '12 spots · 3 nights',
        'View only',
        'Day 1 · Sat 16 May',
        '6 h 10 m',
        '4 places',
        '9:00 am',
        'Naini Lake',
        'Lake · 1 h 30 m',
        '10 min',
        'Naina Devi Temple',
        'Temple · 45 m',
        'Mall Road',
        'Market · 1 h',
        'Spent ₹9,000 on this day',
        'Day 2 · Sun 17 May',
        '7 h 40 m',
      ]) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      expect(find.byKey(const ValueKey('viewer_spent_2')), findsNothing);
      expect(find.byType(ReorderableListView), findsNothing);
      await _tap(t, find.byKey(const ValueKey('viewer_spent_1')));
      _expectOpened(AppRoutes.tripExpenses, {'tripId': tripId, 'day': 1});
      Get.back<void>();
      await _settle(t);
      await _tap(t, find.byKey(const ValueKey('viewer_map')));
      expect(opened.last.$1, AppRoutes.tripDayMap);
    });

    testWidgets('uses the open overview copy without a second S14 call', (t) async {
      final api = FakeViewerApi()..queueViews([viewOk(s14())]);
      registerViewerFakes(api: api, ledger: FakeViewerLedger());
      await _pump(t, _launcher(ViewerTripScreen(tripId: tripId, api: api)));
      await _tapText(t, 'launch');
      final calls = api.etags.length;
      Get.to<void>(() => ViewerDayPlanScreen(tripId: tripId, api: api));
      await _settle(t);
      expect(api.etags.length, calls);
      expect(find.text('Naini Lake'), findsOneWidget);
    });

    testWidgets('a rest day reads Rest day', (t) async {
      final j = s14Json();
      (j['days'] as List).add({'day': 3, 'leg': 1, 'restDay': true, 'date': '2026-05-18', 'totalMinutes': 0, 'placeCount': 0, 'spots': <Object>[]});
      final api = FakeViewerApi()..queueViews([viewOk(ViewerTrip.fromJson(j))]);
      registerViewerFakes(api: api, ledger: FakeViewerLedger());
      await _pump(t, ViewerDayPlanScreen(tripId: tripId, api: api));
      await t.scrollUntilVisible(find.text('Rest day'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Rest day'), findsOneWidget);
    });
  });

  group('3.14 travellers viewer', () {
    testWidgets('list, no menus, Leave asks then leaves', (t) async {
      final api = FakeViewerApi();
      registerViewerFakes(api: api);
      ViewerTripCache.write(tripId, s14(), '"v1"');
      await _pump(t, TravellersViewerScreen(tripId: tripId, members: viewerMembers(), api: api));
      for (final s in [
        'Travellers',
        'Uttarakhand Hills Trip',
        'View only',
        '3 travellers',
        'Shared by Rahul',
        'JOINED',
        'Rahul',
        'Bakhli#48291736 · Created the trip',
        'Owner',
        'Aman (You)',
        'Bakhli#61408275 · Joined 16 May',
        'Priya',
        'Joined 18 May',
        'Only Rahul can invite or remove people.',
        'Leave trip',
      ]) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      expect(find.text('Viewer'), findsNWidgets(2));
      expect(find.textContaining('7139'), findsNothing);
      expect(find.text('Invite'), findsNothing);
      await _tapText(t, 'Leave trip');
      expect(find.text('Leave this trip?'), findsOneWidget);
      expect(find.text('You will lose the plan. Your share stays until it is settled.'), findsOneWidget);
      await _tapText(t, 'Cancel');
      expect(api.leaveCalls, 0);
      await _tapText(t, 'Leave trip');
      await _tapText(t, 'Leave');
      expect(api.leaveCalls, 1);
      expect(ViewerTripCache.read(tripId), isNull);
      expect(toMyTripsCalls, 1);
      expect(find.text('You left the trip'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('leave on a deleted trip opens 3.15b', (t) async {
      final api = FakeViewerApi(leaveResult: const BuddyRefused(type: 'TripNotFound', statusCode: 404));
      registerViewerFakes(api: api);
      await _pump(t, TravellersViewerScreen(tripId: tripId, members: viewerMembers(), api: api));
      await _tapText(t, 'Leave trip');
      await _tapText(t, 'Leave');
      _expectOpened(AppRoutes.tripView, {'tripId': tripId, 'deleted': true});
    });
  });

  group('3.14b my share', () {
    testWidgets('only my money, I have paid asks then calls', (t) async {
      final ledger = FakeViewerLedger(balancesResult: BuddyOk(formerBalances()));
      final expenses = FakeViewerExpenses(BuddyOk(formerList()));
      registerViewerFakes(ledger: ledger, expenses: expenses);
      await _pump(t, FormerShareScreen(tripId: tripId, expenses: expenses, ledger: ledger));
      for (final s in [
        'My share',
        'Uttarakhand Hills Trip · by Rahul',
        'You are no longer on this trip.',
        'You owe Rahul 1736',
        '₹11,816',
        '₹12,816',
        'Your share',
        '₹1,000',
        'You paid',
        'YOUR PAYMENT',
        'You pay Rahul 1736',
        'Not paid yet',
        'Open',
        'I have paid',
        'EXPENSES YOU SHARE · 6',
        'Rafting in Rishikesh',
        'Day 4 · Paid by Rahul 1736',
        '₹2,400',
        'Your share ₹1,200',
        'Day 3 · Paid by Priya 7139',
      ]) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      expect(find.textContaining('6,366'), findsNothing);
      await _tapText(t, 'I have paid');
      expect(find.text('Have you paid ₹11,816?'), findsOneWidget);
      await _tapText(t, 'Yes, I paid');
      expect(ledger.saidPaidCalls, [(rahul, 11816)]);
    });

    testWidgets('trip gone opens the deleted screen', (t) async {
      final ledger = FakeViewerLedger(balancesResult: const BuddyRefused(type: 'TripNotFound', statusCode: 404));
      final expenses = FakeViewerExpenses(const BuddyRefused(type: 'TripNotFound', statusCode: 404));
      registerViewerFakes(ledger: ledger, expenses: expenses);
      await _pump(t, FormerShareScreen(tripId: tripId, expenses: expenses, ledger: ledger));
      await _settle(t);
      _expectOpened(AppRoutes.tripView, {'tripId': tripId, 'deleted': true});
    });

    testWidgets('said paid shows Says paid and Not paid', (t) async {
      final j = sample('e8_balances_viewer')..['role'] = 'Former';
      (j['payments'] as List).first
        ..['state'] = 'SaidPaid'
        ..['paymentId'] = 'p1'
        ..['canSayPaid'] = false
        ..['canWithdraw'] = true;
      final ledger = FakeViewerLedger(balancesResult: BuddyOk(TripBalances.fromJson(j)));
      final expenses = FakeViewerExpenses(BuddyOk(formerList()));
      registerViewerFakes(ledger: ledger, expenses: expenses);
      await _pump(t, FormerShareScreen(tripId: tripId, expenses: expenses, ledger: ledger));
      expect(find.text('Says paid'), findsOneWidget);
      expect(find.text('I have paid'), findsNothing);
      await _tapText(t, 'Not paid');
      expect(find.text('Mark as not paid?'), findsOneWidget);
      await _tap(t, find.text('Not paid'));
      expect(ledger.withdrawCalls, ['p1']);
    });
  });
}
