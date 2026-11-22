import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/config/tour_registry.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/seeker_home/seeker_feed_controller.dart';
import 'package:bakhli/features/seeker_home/seeker_feed_model.dart';
import 'package:bakhli/features/seeker_home/seeker_home_parts.dart';
import 'package:bakhli/features/seeker_home/seeker_tour_steps.dart';
import 'package:bakhli/features/seeker_home/seeker_trip_card.dart';

import 'package:bakhli/navigation/tour_keys.dart';
import 'package:bakhli/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../support/owner_fakes.dart';
import '../../support/owner_render.dart';
import '../../support/owner_sizes.dart';
import 'seeker_home_harness.dart';

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

Widget _app(Widget home) => GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      getPages: routeStubs(),
      home: home,
    );

void _tall(WidgetTester t, {double h = 2400}) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(392, h);
  addTearDown(t.view.reset);
}

void main() {
  late GetStorage box;
  setUpAll(() async {
    await initTestStorage('seeker_home_screen');
    box = GetStorage();
  });
  setUp(() async {
    await box.erase();
    await GetStorage(OwnerCache.container).erase();
  });
  tearDown(Get.reset);

  group('o_sk_1 first launch', () {
    testWidgets('o_sk_1_everyBlockOfTodaysHomeStillBuilt and o_sk_1_blockOrder', (t) async {
      _tall(t, h: 2600);
      registerHome(feed: fixtureNoTrip());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      final order = [
        'Hi, Rohit',
        'Where to next?',
        'Plan your first trip',
        'Quick actions',
        'Popular destinations',
        'Stays near you',
        'Taxis near you',
        'Recently added stays',
        'Follow us',
      ];
      double last = -1;
      for (final s in order) {
        final f = find.text(s);
        expect(f, findsWidgets, reason: s);
        final y = t.getTopLeft(f.first).dy;
        expect(y, greaterThanOrEqualTo(last), reason: '$s is out of order');
        last = y;
      }
      expect(find.byType(SeekerTripSlide), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets('o_sk_1_dotsShowThreeSlides_stayAndTaxiSlidesStillBuilt', (t) async {
      _tall(t, h: 2600);
      registerHome(feed: fixtureNoTrip());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      expect(find.bySemanticsLabel('Slide 1 of 3'), findsOneWidget);
      expect(find.text('Find your stay', skipOffstage: false), findsWidgets);
      expect(find.text('Find a taxi', skipOffstage: false), findsWidgets);
    });

    testWidgets('o_sk_1_quickActions_fourTilesInOrder_fourthPeeks', (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(392, 1600);
      addTearDown(t.view.reset);
      registerHome(feed: fixtureNoTrip());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      final titles = ['Plan a trip', 'My trips', 'Add expense', 'Find a buddy'];
      final xs = <double>[];
      for (final s in titles) {
        final f = find.byKey(ValueKey('seeker-qa-$s'));
        expect(f, findsOneWidget, reason: s);
        xs.add(t.getTopLeft(f).dx);
      }
      expect(find.bySemanticsLabel('Plan a trip, Pick a city and go'), findsOneWidget);
      expect(xs, orderedEquals([...xs]..sort()));
      final peek = t.getTopLeft(find.byKey(const ValueKey('seeker-qa-Find a buddy'))).dx;
      expect(peek, lessThan(392));
      expect(peek + 100, greaterThan(392));
      expect(find.text('Pick a city and go'), findsOneWidget);
      expect(find.text('Continue or review'), findsOneWidget);
      expect(find.text('Split with friends'), findsOneWidget);
      expect(find.text('Travel together', skipOffstage: false), findsOneWidget);
    });

    testWidgets('o_sk_1_tapMyTrips_pushesMyTrips, o_sk_1_tapAddExpense_noTrip_opensMyTrips, o_sk_1_tapFindABuddy_pushesBuddies', (t) async {
      _tall(t, h: 1600);
      registerHome(feed: fixtureNoTrip());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      await t.tap(find.text('Continue or review'));
      await _settle(t);
      Get.back();
      await _settle(t);
      await t.tap(find.text('Split with friends'));
      await _settle(t);
      Get.back();
      await _settle(t);
      await t.drag(find.text('Split with friends'), const Offset(-300, 0));
      await _settle(t);
      await t.tap(find.text('Travel together'));
      await _settle(t);
      expect(visitedRoutes, [AppRoutes.myTrips, AppRoutes.buddies], reason: 'Add expense with no open trip toasts and opens the Trips tab (D-21), no route');
    });

    testWidgets('add expense with a trip opens Trip Expenses of that trip', (t) async {
      _tall(t, h: 1600);
      registerHome(feed: fixtureInProgress());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      await t.tap(find.text('Split with friends'));
      await _settle(t);
      expect(visitedRoutes.last, AppRoutes.tripExpenses);
    });

    testWidgets('o_sk_1_noOwnerTilesNoPlanNudge', (t) async {
      _tall(t, h: 2600);
      registerHome(feed: fixtureNoTrip());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      for (final s in ['Add Stay', 'Add Taxi', 'My Stays', 'My Taxi', 'Post Job', 'My Jobs', 'Renew', 'Resubscribe']) {
        expect(find.text(s), findsNothing, reason: s);
      }
      expect(find.byWidgetPredicate((w) => w.key is GateKey), findsNothing);
    });

    testWidgets('empty rails are not drawn (no header without cards)', (t) async {
      _tall(t, h: 2600);
      registerHome(feed: fixtureNoTrip(), stays: 0, taxis: 0, recent: false);
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      expect(find.text('Stays near you'), findsNothing);
      expect(find.text('Taxis near you'), findsNothing);
      expect(find.text('Recently added stays'), findsNothing);
      expect(find.text('Follow us'), findsOneWidget);
    });
  });

  group('o_sk_2..4 trip states on Home', () {
    testWidgets('o_sk_2_headerSubtitleFollowsTrip', (t) async {
      _tall(t);
      registerHome(feed: fixtureInProgress(status: const SeekerStatus(kind: SeekerStatusKind.confirmed, listingName: 'Deodar Heights', key: 'k1')));
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      expect(find.text('Nainital trip, 26 to 29 Nov'), findsOneWidget);
      expect(find.text('Deodar Heights confirmed your stay'), findsWidgets);
    });

    testWidgets('o_sk_3 subtitle Day 2 in Nainital', (t) async {
      _tall(t);
      registerHome(feed: fixtureOnTrip());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      expect(find.text('Day 2 in Nainital'), findsOneWidget);
      expect(find.text('Today in Mukteshwar'), findsWidgets);
    });

    testWidgets('o_sk_2 status tap stores the key: the line goes away', (t) async {
      _tall(t);
      registerHome(feed: fixtureInProgress(status: const SeekerStatus(kind: SeekerStatusKind.reply, count: 2, tripId: 'trip-1', key: 'k2')));
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      await t.tap(find.text('2 stays replied. Pick one.').hitTestable().first);
      await _settle(t);
      expect(visitedRoutes.last, AppRoutes.tripReplies);
      Get.back();
      await _settle(t);
      expect(find.text('2 stays replied. Pick one.'), findsNothing);
    });
  });

  group('o_sk_5 loading', () {
    testWidgets('o_sk_5_firstOpenNoCopy_showsSkeletonUnderLiveHeader', (t) async {
      _tall(t, h: 1200);
      registerHome(feed: null, railsLoading: true, stays: 0, taxis: 0, recent: false);
      await t.pumpWidget(_app(homeHost()));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Hi, Rohit'), findsOneWidget);
      expect(find.text('Where to next?'), findsOneWidget);
      expect(find.byType(SeekerHomeSkeleton), findsOneWidget);
      expect(find.text('Quick actions'), findsNothing);
    });

    testWidgets('o_sk_5_savedCopyExists_noSkeletonAtAll', (t) async {
      _tall(t, h: 1200);
      registerHome(feed: fixtureNoTrip(), railsLoading: true, stays: 0, taxis: 0, recent: false);
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      expect(find.byType(SeekerHomeSkeleton), findsNothing);
      expect(find.text('Plan your first trip'), findsWidgets);
    });
  });

  group('o_sk_6 error', () {
    testWidgets('o_sk_6_feedFailsNoCopy_showsOneErrorCardWithRetry and o_sk_6_noTapToRetryTextAnywhere', (t) async {
      _tall(t, h: 1600);
      registerHome(feed: fixtureNoTrip(), railsFailed: true);
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      expect(find.byType(SeekerRailsErrorCard), findsOneWidget);
      expect(find.text('Couldn’t load'), findsOneWidget);
      expect(find.text('Check your internet and try again.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Tap to retry'), findsNothing);
      expect(find.text('Popular destinations'), findsNothing);
      expect(find.text('Plan your first trip'), findsWidgets);
      expect(find.text('Quick actions'), findsOneWidget);
      expect(find.text('Follow us'), findsOneWidget);
    });

    testWidgets('o_sk_6_feedFailsWithCopy_keepsCopyNoErrorCard', (t) async {
      _tall(t, h: 2600);
      final home = registerHome(feed: fixtureNoTrip());
      home.failedSections.addAll({HomeSectionKeys.stays});
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      expect(find.byType(SeekerRailsErrorCard), findsNothing);
      expect(find.textContaining('Deodar'), findsWidgets);
    });

    testWidgets('o_sk_6_retrySingleFlight and o_sk_6_retrySuccess_replacesCardWithRails', (t) async {
      _tall(t, h: 2600);
      final home = registerHome(feed: fixtureNoTrip(), railsFailed: true);
      home.onRetry = () async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        home.failedSections.clear();
        home.stays.assignAll(fixtureStays(3));
      };
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      await t.tap(find.text('Retry'));
      await t.pump();
      final again = find.text('Retry');
      if (again.evaluate().isNotEmpty) await t.tap(again, warnIfMissed: false);
      await _settle(t);
      expect(home.retries, 1);
      expect(find.byType(SeekerRailsErrorCard), findsNothing);
      expect(find.text('Stays near you'), findsOneWidget);
    });
  });

  group('o_sk_9 board checks', () {
    testWidgets('o_sk_9_stays_typeDistancePricePerNight and o_sk_9_taxis_vehicleTypePricePerDay', (t) async {
      _tall(t, h: 2600);
      registerHome(feed: fixtureNoTrip());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      for (final s in ['HOMESTAY', 'GUEST HOUSE', 'COTTAGE', 'Mukteshwar · 2.1 km', 'SEDAN', 'TEMPO TRAVELLER', 'SUV', '/day', '/night']) {
        expect(find.textContaining(s), findsWidgets, reason: s);
      }
    });

    testWidgets('o_sk_9_popular_cardShowsStateName and o_sk_9_recentlyAdded_rowWithArrow and o_sk_9_instagram_lastBlock', (t) async {
      _tall(t, h: 2600);
      registerHome(feed: fixtureNoTrip());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      expect(find.text('Uttarakhand'), findsNWidgets(3));
      expect(find.byType(SeekerRecentRow), findsNWidgets(2));
      expect(find.text('›'), findsNWidgets(2));
      final ig = t.getTopLeft(find.text('Follow us')).dy;
      final recent = t.getTopLeft(find.text('River Bend Stay')).dy;
      expect(ig, greaterThan(recent));
    });

    test('o_sk_9_tourStep1_targetsTripCard and o_sk_9_tourHasNoOwnerTileSteps', () {
      final keys = [TourKeys.homeManageListingsCard, TourKeys.homeQuickActionAddStay, TourKeys.homeQuickActionAddTaxi, TourKeys.homeQuickActionLeads, TourKeys.homeInstagramCard];
      final steps = seekerStepsFrom([
        for (final k in keys) TourStep(key: k, title: 'Plan your trip', body: 'b', icon: Icons.add),
      ]);
      expect(steps.first.key, SeekerTourKeys.homeTripCard);
      expect(steps.map((s) => s.key), isNot(contains(TourKeys.homeQuickActionAddStay)));
      expect(steps.map((s) => s.key), isNot(contains(TourKeys.homeQuickActionLeads)));
      expect(steps.length, 2);
    });
  });

  group('sizes (S-STD)', () {
    for (final variant in ['noTrip', 'inProgress', 'onTrip', 'full', 'error']) {
      testOwnerSizes('Home $variant', () => homeHost(), setUpEach: () {
        switch (variant) {
          case 'noTrip':
            registerHome(feed: fixtureNoTrip(), stays: 12, taxis: 12);
          case 'inProgress':
            registerHome(feed: fixtureInProgress(status: const SeekerStatus(kind: SeekerStatusKind.confirmed, listingName: 'Deodar Heights', key: 'k')));
          case 'onTrip':
            registerHome(feed: fixtureOnTrip(), stays: 1, taxis: 1);
          case 'full':
            registerHome(feed: fixtureInProgress(full: true));
          default:
            registerHome(feed: fixtureNoTrip(), railsFailed: true);
        }
      }, arrange: (t) => _settle(t));
    }
  });

  testWidgets('dispose: popping Home leaves no exception and no timers', (t) async {
    _tall(t, h: 1600);
    registerHome(feed: fixtureNoTrip());
    await t.pumpWidget(_app(homeHost()));
    await _settle(t);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 5));
    expect(t.takeException(), isNull);
  });

  group('render', () {
    useOwnerRenderScale();
    Future<void> render(WidgetTester t, String id) async {
      await renderOwnerFrame(t, id, homeHost(bar: true), arrange: (t) => _settle(t));
      expect(t.takeException(), isNull);
    }

    testWidgets('render o_sk_1', (t) async {
      registerHome(feed: fixtureNoTrip());
      await render(t, 'o_sk_1');
    });
    testWidgets('render o_sk_2', (t) async {
      registerHome(feed: fixtureInProgress(status: const SeekerStatus(kind: SeekerStatusKind.confirmed, listingName: 'Deodar Heights', key: 'k1')));
      Get.find<NotificationController>().unreadCount.value = 1;
      await render(t, 'o_sk_2');
    });
    testWidgets('render o_sk_3', (t) async {
      registerHome(feed: fixtureOnTrip());
      await render(t, 'o_sk_3');
    });
    testWidgets('render o_sk_4', (t) async {
      registerHome(feed: fixtureInProgress(full: true));
      await render(t, 'o_sk_4');
    });
    testWidgets('render o_sk_5', (t) async {
      registerHome(feed: null, railsLoading: true, stays: 0, taxis: 0, recent: false);
      await renderOwnerFrame(t, 'o_sk_5', homeHost(bar: true), arrange: (t) => t.pump(const Duration(milliseconds: 300)));
    });
    testWidgets('render o_sk_6', (t) async {
      registerHome(feed: fixtureNoTrip(), railsFailed: true);
      await render(t, 'o_sk_6');
    });
  });

  test('o_sk_1_noFestivalWordInEditedFiles (guard)', () {
    final files = [
      'lib/screens/home_screen.dart',
      'lib/controllers/home_controller.dart',
      'lib/widgets/home_hero_carousel.dart',
      'lib/widgets/home_stay_rail_card.dart',
      'lib/widgets/home_taxi_rail_card.dart',
      'lib/features/trip/widgets/trip_popular_rail.dart',
      'lib/features/trip/widgets/trip_bar.dart',
      'lib/features/trip/widgets/trip_stay_row.dart',
      'lib/features/stay/guest/stay_detail_screen.dart',
      'lib/features/stay/models/stay_detail_model.dart',
      'lib/features/stay/models/stay_nearby_model.dart',
      'lib/features/stay/models/stay_price_chip.dart',
      'lib/features/stay/guest/v2/stay_feed_item.dart',
      ...Directory('lib/features/seeker_home').listSync(recursive: true).whereType<File>().map((f) => f.path),
    ];
    for (final f in files) {
      final text = File(f).readAsStringSync().toLowerCase();
      expect(text.contains('festival'), isFalse, reason: f);
      expect(text.contains('diwali'), isFalse, reason: f);
    }
  });

  test('o_sk_7_homeAddsNoOwnGate: no offline or GPS gate widget in seeker_home', () {
    for (final f in Directory('lib/features/seeker_home').listSync(recursive: true).whereType<File>()) {
      final text = File(f.path).readAsStringSync();
      expect(text.contains('No Internet'), isFalse, reason: f.path);
      expect(text.contains('Location Required'), isFalse, reason: f.path);
      expect(text.contains('global_location_gates'), isFalse, reason: f.path);
    }
  });

  test('Home screen is still the Seeker Home root widget', () {
    expect(const HomeScreen(), isA<StatefulWidget>());
    expect(SeekerFeedController.maybe, isNull);
  });
}

