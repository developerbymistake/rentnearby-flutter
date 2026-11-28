import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/buddy/buddies/buddies_strings.dart';
import 'package:bakhli/features/buddy/shared/buddy_look.dart';
import 'package:bakhli/features/social/b/post/join_request_sheet.dart';
import 'package:bakhli/features/social/b/post/own_post_menu.dart';
import 'package:bakhli/features/social/b/post/trip_post_screen.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/b/widgets/social_widgets_b.dart';
import 'package:bakhli/features/social/shared/social_live.dart';
import 'package:bakhli/features/social/shared/widgets/follow_button.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

final _pages = [
  GetPage(name: AppRoutes.joinRequests, page: () => Scaffold(body: Text('REQUESTS ${(Get.arguments as Map)['tripId']}'))),
  GetPage(name: AppRoutes.travelBuddies, page: () => const Scaffold(body: Text('FEED'))),
  GetPage(name: AppRoutes.traveller, page: () => const Scaffold(body: Text('PROFILE'))),
];

const _path = '/social/trips/trip-1';

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
  });
  tearDown(Get.reset);

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('an open post: cover, owner, mutuals, facts, about, safety line, Request to join ($size, $scale)', (t) async {
        final server = installServer();
        putSocialMe(server, socialMeWith());
        server.on('GET', _path, publicTripJson(mutuals: {'count': 1, 'names': ['Aman'], 'photoUrls': []}));
        await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), size: size, textScale: scale, pages: _pages);
        expect(find.byKey(TripPostScreen.coverKey), findsOneWidget);
        expect(find.byKey(TripPostScreen.backKey), findsOneWidget);
        expect(find.text(SocialStringsB.tripPost), findsNothing);
        expect(find.descendant(of: find.byKey(TripPostScreen.coverKey), matching: find.text('Rishikesh')), findsOneWidget);
        expect(find.text('Uttarakhand · December'), findsOneWidget);
        expect(find.text('2 seats left'), findsOneWidget);
        expect(find.text('Kavya Sharma'), findsOneWidget);
        expect(find.text('Followed by Aman'), findsOneWidget);
        expect(find.text(SocialStringsB.factWhen), findsOneWidget);
        expect(find.text('December'), findsOneWidget);
        expect(find.text(SocialStringsB.aboutThisTrip), findsOneWidget);
        expect(find.text('5 days'), findsOneWidget);
        expect(find.text('2 left'), findsOneWidget);
        expect(find.text(SocialStrings.safetyMeet), findsOneWidget);
        expect(find.byKey(TripPostScreen.requestKey), findsOneWidget);
        expect(t.widget<GradientPillButton>(find.byKey(TripPostScreen.requestKey)).tone, ListingTone.coral);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('Request to join -> Requested with Cancel request; cancel goes back', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson());
    server.on('POST', '$_path/join-requests', {'id': 'jr-1', 'status': 'Waiting'});
    server.on('DELETE', '$_path/join-requests/mine', {});
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    await t.tap(find.byKey(TripPostScreen.requestKey));
    await settle(t);
    server.on('GET', _path, publicTripJson(myJoin: 'requested'));
    await t.tap(find.byKey(JoinRequestSheet.sendKey));
    await settle(t);
    expect(find.text(SocialStringsB.requested), findsOneWidget);
    final pill = t.widget<GradientPillButton>(find.ancestor(of: find.text(SocialStringsB.requested), matching: find.byType(GradientPillButton)));
    expect(pill.offLabelColor, BuddyLook.subText);
    expect(find.byKey(TripPostScreen.cancelKey), findsOneWidget);
    server.on('GET', _path, publicTripJson());
    await t.tap(find.byKey(TripPostScreen.cancelKey));
    await settle(t);
    expect(server.calls('DELETE', '$_path/join-requests/mine'), hasLength(1));
    expect(find.byKey(TripPostScreen.requestKey), findsOneWidget);
    await drain(t);
  });

  testWidgets('facts stay readable at 320 dp and text scale 1.3: Within 2 months, Women only and every label', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson(when: {'kind': 'within', 'months': 2}, joinGender: 'F', myJoin: 'requested'));
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), size: const Size(320, 1400), textScale: 1.3, pages: _pages);
    expect(t.takeException(), isNull);
    for (final text in ['Within 2 months', 'Women only', SocialStringsB.factWhen, SocialStringsB.factHowLong, SocialStringsB.factWho, SocialStringsB.factSeats]) {
      final f = find.text(text);
      expect(f, findsWidgets, reason: text);
      for (final e in f.evaluate()) {
        expect((e.renderObject! as RenderParagraph).didExceedMaxLines, isFalse, reason: '$text must not be cut');
      }
    }
    await drain(t);
  });

  testWidgets('a 429 join limit closes the sheet and opens the Plus limit sheet', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith(joinUsed: 1));
    server.on('GET', _path, publicTripJson());
    server.refuse('POST', '$_path/join-requests', status: 429, type: 'JoinRequestLimit');
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    await t.tap(find.byKey(TripPostScreen.requestKey));
    await settle(t);
    await t.tap(find.byKey(JoinRequestSheet.sendKey));
    await settle(t);
    expect(find.byKey(JoinRequestSheet.sendKey), findsNothing);
    expect(find.byKey(const ValueKey('plus_limit_sheet')), findsOneWidget);
    await drain(t);
  });

  testWidgets('a Women-only trip seen by a man: the full post shows and the bar says This trip is for women only (spec 22)', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith(gender: 'Male'));
    server.on('GET', _path, publicTripJson(joinGender: 'F', notOpen: true));
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.text(SocialStrings.safetyMeet), findsOneWidget);
    expect(find.textContaining('Dehradun'), findsWidgets);
    expect(find.byType(FollowButton), findsOneWidget);
    expect(find.byKey(TripPostScreen.menuKey), findsOneWidget);
    expect(find.byKey(TripPostScreen.requestKey), findsNothing);
    final only = t.widget<GradientPillButton>(find.byKey(TripPostScreen.onlyForKey));
    expect(only.label, 'This trip is for women only');
    expect(only.enabled, isFalse);
    expect(only.onTap, isNull);
    expect(only.offLabelColor, BuddyLook.subText);
    expect(only.icon, Icons.lock_rounded);
    await drain(t);
  });

  testWidgets('a Women-only trip seen by a woman shows Request to join', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith(gender: 'Female'));
    server.on('GET', _path, publicTripJson(joinGender: 'F', notOpen: false));
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.byKey(TripPostScreen.requestKey), findsOneWidget);
    expect(find.byKey(TripPostScreen.onlyForKey), findsNothing);
    await drain(t);
  });

  testWidgets('a server TripGenderMismatch keeps the sheet open with the message and reloads the post', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith(gender: 'Female'));
    server.on('GET', _path, publicTripJson());
    server.refuse('POST', '$_path/join-requests', status: 403, type: 'TripGenderMismatch', message: 'This trip is for men only.');
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    await t.tap(find.byKey(TripPostScreen.requestKey));
    await settle(t);
    final before = server.calls('GET', _path).length;
    await t.tap(find.byKey(JoinRequestSheet.sendKey));
    await settle(t);
    expect(find.text('This trip is for men only.'), findsOneWidget);
    expect(server.calls('GET', _path).length, greaterThan(before));
    await drain(t);
  });

  testWidgets('my own post: Join requests and Plan this trip, no Request button, the own menu in the cover', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson(isMine: true, ownerId: 'me', ownerName: 'Rahul Verma', waitingRequests: 2));
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.byKey(TripPostScreen.requestKey), findsNothing);
    expect(find.byKey(TripPostScreen.openTripKey), findsOneWidget);
    expect(find.descendant(of: find.byKey(TripPostScreen.openTripKey), matching: find.text(SocialStringsB.planTrip)), findsOneWidget);
    expect(find.text(SocialStringsB.openTrip), findsNothing);
    expect(find.descendant(of: find.byKey(TripPostScreen.coverKey), matching: find.byKey(TripPostScreen.menuKey)), findsOneWidget);
    expect(find.text('${SocialStringsB.joinRequestsTitle} · 2'), findsOneWidget);
    expect(find.descendant(of: find.byKey(TripPostScreen.ownerStatusKey), matching: find.text('2 requests waiting')), findsOneWidget);
    await t.tap(find.byKey(TripPostScreen.joinRequestsKey));
    await settle(t);
    expect(find.text('REQUESTS trip-1'), findsOneWidget);
    await drain(t);
  });

  testWidgets('I-7: Plan this trip asks first; Cancel stays, confirm opens the trip overview', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson(isMine: true, ownerId: 'me', ownerName: 'Rahul Verma', waitingRequests: 0));
    final pages = [..._pages, GetPage(name: AppRoutes.tripOverview, page: () => Scaffold(body: Text('OVERVIEW ${(Get.arguments as Map)['tripId']}')))];
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: pages);
    await t.tap(find.byKey(TripPostScreen.openTripKey));
    await settle(t);
    expect(find.text(SocialStringsB.planTripTitle), findsOneWidget);
    expect(find.text(SocialStringsB.planTripBody), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await settle(t);
    expect(find.text(SocialStringsB.planTripTitle), findsNothing);
    expect(find.text('OVERVIEW trip-1'), findsNothing);
    await t.tap(find.byKey(TripPostScreen.openTripKey));
    await settle(t);
    await t.tap(find.text(SocialStringsB.planTrip).last);
    await settle(t);
    expect(find.text('OVERVIEW trip-1'), findsOneWidget);
    await drain(t);
  });

  testWidgets('I-7: a joined member still sees Open trip', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson(myJoin: 'member'));
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.text(SocialStringsB.openTrip), findsOneWidget);
    expect(find.text(SocialStringsB.planTrip), findsNothing);
    await drain(t);
  });

  testWidgets('a post that is gone shows the not-available state', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.refuse('GET', _path, status: 404, type: 'TripPostNotFound');
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.text(SocialStringsB.postGone), findsOneWidget);
    await drain(t);
  });
  testWidgets('T2: the details card shows Travel by as 3D art and a label, no chip', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson(travelMode: 'train'));
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.text(SocialStringsB.factTravelBy), findsOneWidget);
    expect(find.descendant(of: find.byKey(TripPostScreen.travelKey), matching: find.text('Train')), findsOneWidget);
    expect(find.descendant(of: find.byKey(TripPostScreen.travelKey), matching: find.byType(Art3D)), findsOneWidget);
    expect(find.byType(TravelModeChip), findsNothing);
    await drain(t);
  });

  testWidgets('my own post: the menu opens Edit post / Members · N / Delete trip, not Report or Block', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, {...publicTripJson(isMine: true, ownerId: 'me', ownerName: 'Rahul Verma'), 'members': 2});
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    await t.tap(find.byKey(TripPostScreen.menuKey));
    await settle(t);
    expect(find.byKey(OwnPostMenu.editKey), findsOneWidget);
    expect(find.text(SocialStringsB.editPost), findsOneWidget);
    expect(find.text('Members · 2'), findsOneWidget);
    expect(find.text(SocialStringsB.deleteTrip), findsOneWidget);
    expect(find.text(SocialStringsB.reportTrip), findsNothing);
    expect(find.textContaining('Block '), findsNothing);
    await drain(t);
  });

  testWidgets('my own post: a delete with no other travellers leaves the page', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, {...publicTripJson(isMine: true, ownerId: 'me', ownerName: 'Rahul Verma'), 'members': 0});
    final deleted = <String>[];
    OwnPostMenu.debugDelete = (_, id) async {
      deleted.add(id);
      return true;
    };
    addTearDown(() => OwnPostMenu.debugDelete = null);
    final host = Scaffold(
      body: Builder(
        builder: (c) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const TripPostScreen(tripId: 'trip-1'))),
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await pumpSocial(t, host, pages: _pages);
    await t.tap(find.text('OPEN'));
    await settle(t);
    await t.tap(find.byKey(TripPostScreen.menuKey));
    await settle(t);
    final gets = server.calls('GET', _path).length;
    await t.tap(find.byKey(OwnPostMenu.deleteKey));
    await settle(t);
    expect(deleted, ['trip-1']);
    expect(find.byKey(TripPostScreen.coverKey), findsNothing);
    expect(find.text('OPEN'), findsOneWidget);
    expect(server.calls('GET', _path), hasLength(gets), reason: 'the deleted post is never fetched again while the page leaves');
    expect(find.text(SocialStringsB.postGone), findsNothing);
    await drain(t);
  });

  testWidgets('frame 18: my own post shows members going and requests waiting under the poster', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, {...publicTripJson(isMine: true, ownerId: 'me', ownerName: 'Rahul Verma', waitingRequests: 1), 'members': 2});
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.descendant(of: find.byKey(TripPostScreen.ownerStatusKey), matching: find.text('2 members going · 1 request waiting')), findsOneWidget);
    await drain(t);
  });

  testWidgets('frame 18: no status line with nobody going and no requests', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, {...publicTripJson(isMine: true, ownerId: 'me', ownerName: 'Rahul Verma', waitingRequests: 0), 'members': 0});
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.byKey(TripPostScreen.coverKey), findsOneWidget);
    expect(find.byKey(TripPostScreen.ownerStatusKey), findsNothing);
    await drain(t);
  });

  testWidgets("frame 18: never a status line on someone else's post", (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, {...publicTripJson(waitingRequests: 3), 'members': 2});
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.byKey(TripPostScreen.coverKey), findsOneWidget);
    expect(find.byKey(TripPostScreen.ownerStatusKey), findsNothing);
    await drain(t);
  });

  testWidgets("frame 13: the menu on someone else's post has Report trip and Block person", (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson());
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    await t.tap(find.byKey(TripPostScreen.menuKey));
    await settle(t);
    expect(find.text(SocialStringsB.reportTrip), findsOneWidget);
    expect(find.text(SocialStringsB.reportTripLine), findsOneWidget);
    expect(find.text(SocialStringsB.blockPerson('Kavya S.')), findsOneWidget);
    expect(find.text(SocialStringsB.blockLine), findsOneWidget);
    expect(find.byKey(OwnPostMenu.editKey), findsNothing);
    expect(find.byKey(OwnPostMenu.deleteKey), findsNothing);
    await drain(t);
  });

  testWidgets('blocking the poster from the menu leaves the page and refreshes the trip lists', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson());
    server.on('GET', '/users/kavya/block-context', {'tripsInCommon': []});
    server.on('GET', '/report-reasons', []);
    server.on('POST', '/users/kavya/block', null);
    final host = Scaffold(
      body: Builder(
        builder: (c) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const TripPostScreen(tripId: 'trip-1'))),
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await pumpSocial(t, host, pages: _pages);
    await t.tap(find.text('OPEN'));
    await settle(t);
    final before = SocialLive.posts.value;
    await t.tap(find.byKey(TripPostScreen.menuKey));
    await settle(t);
    await t.tap(find.textContaining('Block '));
    await settle(t);
    await t.tap(find.text(BuddiesStrings.block));
    await settle(t);
    expect(server.calls('POST', '/users/kavya/block'), hasLength(1));
    expect(find.byKey(TripPostScreen.coverKey), findsNothing);
    expect(find.text('OPEN'), findsOneWidget);
    expect(SocialLive.posts.value, before + 1);
    await drain(t);
  });

  testWidgets('T1: a post without a travel mode has no Travel by row', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson());
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.text(SocialStringsB.factTravelBy), findsNothing);
    expect(find.byKey(TripPostScreen.travelKey), findsNothing);
    await drain(t);
  });

  testWidgets('owner row carries the trophy badge and N trips beside the name', (t) async {
    final server = installServer();
    server.on('GET', _path, publicTripJson(ownerTrips: 124, ownerLevel: 4));
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.byKey(TripPostScreen.ownerLevelKey), findsOneWidget);
    expect(find.descendant(of: find.byKey(TripPostScreen.ownerLevelKey), matching: find.text('124 trips')), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Art3D && w.asset == ListingArt.trophyLevel4), findsOneWidget);
    await drain(t);
  });

  testWidgets('a gone post keeps the default Trip post header, no cover', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.refuse('GET', _path, status: 404, type: 'TripPostNotFound');
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.text(SocialStringsB.tripPost), findsOneWidget);
    expect(find.byKey(TripPostScreen.coverKey), findsNothing);
    await drain(t);
  });

  testWidgets('the cover back button pops the page', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson());
    final host = Scaffold(
      body: Builder(
        builder: (c) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const TripPostScreen(tripId: 'trip-1'))),
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await pumpSocial(t, host, pages: _pages);
    await t.tap(find.text('OPEN'));
    await settle(t);
    expect(find.byKey(TripPostScreen.coverKey), findsOneWidget);
    await t.tap(find.byKey(TripPostScreen.backKey));
    await settle(t);
    expect(find.byKey(TripPostScreen.coverKey), findsNothing);
    expect(find.text('OPEN'), findsOneWidget);
    await drain(t);
  });

  testWidgets('the menu sits in the cover for someone else, tapping the poster opens their profile', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson());
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.descendant(of: find.byKey(TripPostScreen.coverKey), matching: find.byKey(TripPostScreen.menuKey)), findsOneWidget);
    await t.tap(find.text('Kavya Sharma'));
    await settle(t);
    expect(find.text('PROFILE'), findsOneWidget);
    await drain(t);
  });

  testWidgets('facts use 3D art; a post without text has no About card', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson(text: '', travelMode: 'bus'));
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    for (final art in [ListingArt.calendar, ListingArt.luggage, ListingArt.shield]) {
      expect(find.byWidgetPredicate((w) => w is Art3D && w.asset == art), findsOneWidget, reason: art);
    }
    expect(find.descendant(of: find.byKey(TripPostScreen.travelKey), matching: find.text('Bus')), findsOneWidget);
    expect(find.text(SocialStringsB.aboutThisTrip), findsNothing);
    await drain(t);
  });

  testWidgets('a full post for others reads Full on the cover and in the facts', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('GET', _path, publicTripJson(seatsLeft: 0));
    await pumpSocial(t, const TripPostScreen(tripId: 'trip-1'), pages: _pages);
    expect(find.descendant(of: find.byKey(TripPostScreen.coverKey), matching: find.text(SocialStringsB.full)), findsOneWidget);
    expect(find.byKey(TripPostScreen.fullKey), findsOneWidget);
    await drain(t);
  });
}
