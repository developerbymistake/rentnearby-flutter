import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/seeker_home/seeker_feed_controller.dart';
import 'package:bakhli/features/seeker_home/seeker_feed_model.dart';
import 'package:bakhli/features/seeker_home/seeker_home_parts.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/widgets/trip_city_tile.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/instagram_look.dart';
import 'package:bakhli/features/seeker_home/build_circle_card.dart';
import 'package:bakhli/features/seeker_home/home_updates.dart';
import 'package:bakhli/features/seeker_home/seeker_trip_card.dart';
import 'package:bakhli/features/social/b/rail/trips_to_join_rail.dart';
import 'package:bakhli/features/social/b/widgets/find_buddies_post_card.dart';
import 'package:bakhli/widgets/home_hero_carousel.dart';

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
        'Plan your trip',
        'Post your trip',
        'Your updates',
        'Popular destinations',
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

    testWidgets('I-17 o_sk_1_onlyTheTripSlide_noDots_noStayOrTaxiSlide', (t) async {
      _tall(t, h: 2600);
      registerHome(feed: fixtureNoTrip());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      expect(find.bySemanticsLabel(RegExp(r'^Slide \d of \d$')), findsNothing);
      expect(find.text('Find your stay', skipOffstage: false), findsNothing);
      expect(find.text('Find a taxi', skipOffstage: false), findsNothing);
      expect(find.byType(SeekerTripSlide), findsOneWidget);
    });

    for (final (name, feed) in [('no trip', fixtureNoTrip), ('in progress', fixtureInProgress), ('on trip', fixtureOnTrip)]) {
      for (final w in [360.0, 412.0]) {
        testWidgets('Bug 5 + Bug 10: the trip hero card keeps its action pill inside ($name, $w)', (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = Size(w, 1600);
          addTearDown(t.view.reset);
          registerHome(feed: feed());
          await t.pumpWidget(_app(homeHost()));
          await _settle(t);
          expect(find.byType(PageView), findsNothing);
          final tripOwner = find.byType(SeekerTripCardView).first;
          final trip = t.getRect(find.descendant(of: tripOwner, matching: find.byType(DecoratedBox)).first);
          final p = t.getRect(find.descendant(of: tripOwner, matching: find.byType(WorkoutActionPill)));
          expect(trip.right - p.right, moreOrLessEquals(DS.s(20), epsilon: 0.5));
          expect(trip.bottom - p.bottom, moreOrLessEquals(DS.s(20), epsilon: 0.5));
          expect(p.top, greaterThanOrEqualTo(trip.top));
          expect(t.takeException(), isNull);
        });
      }
    }

    testWidgets('I-31: Your updates has three tiles in order, Quick actions is gone, every other card still builds', (t) async {
      _tall(t, h: 2600);
      registerHome(feed: fixtureNoTrip());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      expect(find.text('Quick actions'), findsNothing);
      for (final s in ['Plan a trip', 'Buddies', 'Pick a city and go', 'Continue or review', 'Travel together']) {
        expect(find.byKey(ValueKey('seeker-qa-$s'), skipOffstage: false), findsNothing, reason: s);
      }
      expect(find.byType(HomeHeroCarousel), findsOneWidget);
      expect(find.byType(BuildCircleCard), findsOneWidget);
      expect(find.byType(FindBuddiesPostCard), findsOneWidget);
      expect(find.byType(HomeUpdates), findsOneWidget);
      expect(find.byType(TripsToJoinRail), findsOneWidget);
      expect(find.text('Follow us'), findsOneWidget);
      final xs = <double>[];
      for (final id in ['invites', 'follow', 'join']) {
        final f = find.byKey(ValueKey('home-upd-$id'));
        expect(f, findsOneWidget, reason: id);
        xs.add(t.getTopLeft(f).dx);
      }
      expect(xs, orderedEquals([...xs]..sort()));
      expect(t.getRect(find.byKey(const ValueKey('home-upd-join'))).right, lessThanOrEqualTo(392));
      expect(find.bySemanticsLabel('Trip invites, 0'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('I-31: tiles open My trips Joined, People Requests and the travel buddies feed', (t) async {
      _tall(t, h: 1600);
      registerHome(feed: fixtureNoTrip());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('home-upd-invites')));
      await _settle(t);
      expect(Get.arguments, {'tab': 'joined'});
      Get.back();
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('home-upd-follow')));
      await _settle(t);
      expect(Get.arguments, {'tab': 'requests'});
      Get.back();
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('home-upd-join')));
      await _settle(t);
      expect(visitedRoutes, [AppRoutes.myTrips, AppRoutes.people, AppRoutes.travelBuddies]);
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

    testWidgets('Change 7: no stays, taxis or recently added section on Home', (t) async {
      _tall(t, h: 2600);
      registerHome(feed: fixtureNoTrip());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      for (final s in ['Stays near you', 'Taxis near you', 'Nearest stays', 'Nearest taxis', 'Recently added stays']) {
        expect(find.text(s), findsNothing, reason: s);
      }
      expect(find.text('Popular destinations'), findsOneWidget);
      expect(find.text('Follow us'), findsOneWidget);
    });

    testWidgets('no popular cities: no rail header without cards', (t) async {
      _tall(t, h: 2600);
      registerHome(feed: fixtureNoTrip(), cities: false);
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      expect(find.text('Popular destinations'), findsNothing);
      expect(find.byType(SeekerRailsErrorCard), findsNothing);
      expect(find.text('Follow us'), findsOneWidget);
    });
  });

  group('o_sk_2..4 trip states on Home', () {
    testWidgets('Bug 6: header line stays Where to next? with a trip in progress', (t) async {
      _tall(t);
      registerHome(feed: fixtureInProgress(status: const SeekerStatus(kind: SeekerStatusKind.confirmed, listingName: 'Deodar Heights', key: 'k1')));
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      expect(find.text('Where to next?'), findsOneWidget);
      expect(find.text('Nainital trip, 26 to 29 Nov'), findsNothing);
      expect(find.text('Deodar Heights confirmed your stay'), findsWidgets);
    });

    testWidgets('Bug 6: header line stays Where to next? while on the trip', (t) async {
      _tall(t);
      registerHome(feed: fixtureOnTrip());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      expect(find.text('Where to next?'), findsOneWidget);
      expect(find.text('Day 2 in Nainital'), findsNothing);
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
      registerHome(feed: null, railsLoading: true);
      await t.pumpWidget(_app(homeHost()));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Hi, Rohit'), findsOneWidget);
      expect(find.text('Where to next?'), findsOneWidget);
      expect(find.byType(SeekerHomeSkeleton), findsOneWidget);
      expect(find.text('Your updates'), findsNothing);
    });

    testWidgets('o_sk_5_savedCopyExists_noSkeletonAtAll', (t) async {
      _tall(t, h: 1200);
      registerHome(feed: fixtureNoTrip(), railsLoading: true);
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      expect(find.byType(SeekerHomeSkeleton), findsNothing);
      expect(find.text('Plan your trip'), findsWidgets);
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
      expect(find.text('Plan your trip'), findsWidgets);
      expect(find.text('Your updates'), findsOneWidget);
      expect(find.text('Follow us'), findsOneWidget);
    });

    testWidgets('o_sk_6_feedFailsWithCopy_keepsCopyNoErrorCard', (t) async {
      _tall(t, h: 2600);
      final home = registerHome(feed: fixtureNoTrip());
      home.popularFailed.value = true;
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      expect(find.byType(SeekerRailsErrorCard), findsNothing);
      expect(find.text('Nainital'), findsWidgets);
    });

    testWidgets('o_sk_6_retrySingleFlight and o_sk_6_retrySuccess_replacesCardWithRails', (t) async {
      _tall(t, h: 2600);
      final home = registerHome(feed: fixtureNoTrip(), railsFailed: true);
      home.onRetry = () async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        TripCityCatalog.to.seedForTest(fixtureCities);
        home.popularFailed.value = false;
        home.popularVersion.value++;
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
      expect(find.text('Popular destinations'), findsOneWidget);
      expect(find.text('Nainital'), findsWidgets);
    });
  });

  group('o_sk_9 board checks', () {
    testWidgets('Change 9: popular destinations use the trip picker hub card; Instagram is the last block', (t) async {
      _tall(t, h: 2600);
      registerHome(feed: fixtureNoTrip());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      final tiles = find.byWidgetPredicate((w) => w is TripCityTile && w.hub);
      expect(tiles, findsWidgets);
      expect(find.text('Uttarakhand'), findsWidgets);
      expect(t.getTopLeft(find.text('Follow us')).dy, greaterThan(t.getBottomLeft(tiles.first).dy));
    });

    testWidgets('Instagram card keeps its shape with the Instagram gradient and magenta Follow', (t) async {
      _tall(t, h: 2600);
      registerHome(feed: fixtureNoTrip());
      await t.pumpWidget(_app(homeHost()));
      await _settle(t);
      final ig = t.widget<WorkoutCard>(find.ancestor(of: find.text('Follow us'), matching: find.byType(WorkoutCard)));
      expect(ig.gradient, InstagramLook.gradient);
      expect(ig.tone.button, InstagramLook.magenta);
      expect(ig.art, ListingArt.camera);
      expect(ig.ctaLabel, 'Follow');
    });

  });

  group('sizes (S-STD)', () {
    for (final variant in ['noTrip', 'inProgress', 'onTrip', 'full', 'error']) {
      testOwnerSizes('Home $variant', () => homeHost(), setUpEach: () {
        switch (variant) {
          case 'noTrip':
            registerHome(feed: fixtureNoTrip());
          case 'inProgress':
            registerHome(feed: fixtureInProgress(status: const SeekerStatus(kind: SeekerStatusKind.confirmed, listingName: 'Deodar Heights', key: 'k')));
          case 'onTrip':
            registerHome(feed: fixtureOnTrip());
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
      registerHome(feed: null, railsLoading: true);
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

