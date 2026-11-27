import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/b/feed/travel_buddies_screen.dart';
import 'package:bakhli/features/social/b/post/join_request_sheet.dart';
import 'package:bakhli/features/social/b/post/trip_post_screen.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/social/shared/widgets/public_trip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

final _pages = [
  GetPage(name: AppRoutes.joinRequests, page: () => const Scaffold(body: Text('REQUESTS'))),
  GetPage(name: AppRoutes.tripView, page: () => const Scaffold(body: Text('TRIP'))),
];

Map<String, dynamic> _full({bool mine = false, int seatsLeft = 2, int? waiting}) =>
    {...publicTripJson(isMine: mine, seatsLeft: seatsLeft, waitingRequests: waiting), 'requestsFull': true};

GradientPillButton _pill(WidgetTester t, Key key) => t.widget<GradientPillButton>(find.byKey(key));

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
  });
  tearDown(Get.reset);

  group('UC15 Full: 50 pending requests', () {
    for (final mode in PublicTripCardMode.values) {
      testWidgets('${mode.name} card: others see Full in the seats pill', (t) async {
        await pumpSocial(t, Scaffold(body: SingleChildScrollView(child: PublicTripCard(trip: PublicTrip.fromJson(_full()), mode: mode))));
        expect(find.byKey(PublicTripCard.fullKey), findsOneWidget);
        expect(find.text(SocialStringsB.full), findsOneWidget);
        await drain(t);
      });
    }

    testWidgets('the host never sees his own post as Full on the card', (t) async {
      await pumpSocial(t, Scaffold(body: SingleChildScrollView(child: PublicTripCard(trip: PublicTrip.fromJson(_full(mine: true))))));
      expect(find.byKey(PublicTripCard.fullKey), findsNothing);
      await drain(t);
    });

    testWidgets('feed: a Full post has no Request button, a calm disabled Full line', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', '/social/trips/feed', {'mine': [], 'items': [_full()], 'nextCursor': null});
      await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
      expect(find.byKey(const ValueKey('feed_request_trip-1')), findsNothing);
      expect(_pill(t, const ValueKey('feed_full_trip-1')).enabled, isFalse);
      expect(find.text('${SocialStringsB.full} · ${SocialStringsB.requestsFullLine}'), findsOneWidget);
      await drain(t);
    });

    testWidgets('feed: the 51st request is refused with TripRequestsFull: calm text in the sheet and the card turns Full at once', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', '/social/trips/feed', {'mine': [], 'items': [publicTripJson()], 'nextCursor': null});
      server.refuse('POST', '/social/trips/trip-1/join-requests', status: 409, type: 'TripRequestsFull', message: 'Server words');
      await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
      await t.tap(find.byKey(const ValueKey('feed_request_trip-1')));
      await settle(t);
      server.on('GET', '/social/trips/feed', {'mine': [], 'items': [_full()], 'nextCursor': null});
      await t.tap(find.byKey(JoinRequestSheet.sendKey));
      await settle(t);
      expect(find.text(SocialStringsB.requestsFullNow), findsOneWidget);
      expect(find.text('Server words'), findsNothing);
      await t.tapAt(const Offset(10, 10));
      await settle(t);
      expect(find.byKey(const ValueKey('feed_request_trip-1')), findsNothing);
      expect(find.byKey(const ValueKey('feed_full_trip-1')), findsOneWidget);
      await drain(t);
    });

    testWidgets('post page: others see Full in the facts and a disabled Full bar', (t) async {
      final server = installServer();
      server.on('GET', '/social/trips/trip-1', _full());
      await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
      expect(_pill(t, TripPostScreen.fullKey).enabled, isFalse);
      expect(find.byKey(TripPostScreen.requestKey), findsNothing);
      await drain(t);
    });

    testWidgets('post page: the host keeps Join requests and reads how many wait', (t) async {
      final server = installServer();
      server.on('GET', '/social/trips/trip-1', _full(mine: true, waiting: 50));
      await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
      expect(find.byKey(TripPostScreen.joinRequestsKey), findsOneWidget);
      expect(find.text(SocialStringsB.requestsFullOwner(50)), findsOneWidget);
      expect(find.byKey(TripPostScreen.fullKey), findsNothing);
      await drain(t);
    });

    testWidgets('a declined request frees a slot: the server answer without requestsFull shows Request again', (t) async {
      final server = installServer();
      server.on('GET', '/social/trips/trip-1', publicTripJson());
      await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
      expect(find.byKey(TripPostScreen.requestKey), findsOneWidget);
      await drain(t);
    });
  });

  group('UC16 a member the host removed cannot ask again', () {
    testWidgets('feed: myJoin removed shows the calm line, no Request', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', '/social/trips/feed', {'mine': [], 'items': [publicTripJson(myJoin: 'removed')], 'nextCursor': null});
      await pumpSocial(t, const TravelBuddiesScreen(), pages: _pages);
      expect(find.byKey(const ValueKey('feed_request_trip-1')), findsNothing);
      expect(find.text(SocialStringsB.cannotRejoin), findsOneWidget);
      await drain(t);
    });

    testWidgets('post page: a CannotRejoin refusal shows the calm text and the bar locks', (t) async {
      final server = installServer();
      putSocialMe(server, socialMeWith());
      server.on('GET', '/social/trips/trip-1', publicTripJson());
      server.refuse('POST', '/social/trips/trip-1/join-requests', status: 409, type: 'CannotRejoin', message: 'Server words');
      await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
      await t.tap(find.byKey(TripPostScreen.requestKey));
      await settle(t);
      server.on('GET', '/social/trips/trip-1', publicTripJson(myJoin: 'removed'));
      await t.tap(find.byKey(JoinRequestSheet.sendKey));
      await settle(t);
      expect(find.text(SocialStringsB.cannotRejoin), findsWidgets);
      expect(find.text('Server words'), findsNothing);
      await t.tapAt(const Offset(10, 10));
      await settle(t);
      expect(find.byKey(TripPostScreen.removedKey), findsOneWidget);
      expect(find.byKey(TripPostScreen.requestKey), findsNothing);
      await drain(t);
    });
  });

  group('poster feedback', () {
    testWidgets('own post with nearby ON and not sent yet: the 7 am line', (t) async {
      final server = installServer();
      server.on('GET', '/social/trips/trip-1', {...publicTripJson(isMine: true), 'notifyNearby': true});
      await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
      expect(find.byKey(TripPostScreen.ownerNoteKey), findsOneWidget);
      expect(find.text(SocialStringsB.nearbyTomorrow), findsOneWidget);
      await drain(t);
    });

    testWidgets('after the morning send, or for others, no line', (t) async {
      final server = installServer();
      server.on('GET', '/social/trips/trip-1', {...publicTripJson(isMine: true), 'notifyNearby': true, 'nearbyNotifiedAt': '2026-11-28T01:30:00Z'});
      await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
      expect(find.byKey(TripPostScreen.ownerNoteKey), findsNothing);
      await drain(t);
    });
  });
}
