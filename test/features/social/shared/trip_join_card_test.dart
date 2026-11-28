import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/b/post/join_request_sheet.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/b/widgets/social_widgets_b.dart';
import 'package:bakhli/features/social/shared/social_error_types.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:bakhli/features/social/shared/widgets/trip_join_card.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../b/social_b_test_kit.dart';
import 'social_test_support.dart';

final _pages = [
  GetPage(name: AppRoutes.tripPost, page: () => Scaffold(body: Text('POST ${(Get.arguments as Map)['tripId']}'))),
  GetPage(name: AppRoutes.joinRequests, page: () => Scaffold(body: Text('REQUESTS ${(Get.arguments as Map)['tripId']}'))),
  GetPage(name: AppRoutes.tripView, page: () => Scaffold(body: Text('TRIP ${(Get.arguments as Map)['tripId']}'))),
];

Widget _host(Widget child) => Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child)));

PublicTrip _trip({
  bool isMine = false,
  int? waitingRequests,
  String myJoin = 'none',
  String joinGender = 'A',
  bool notOpen = false,
  int seatsLeft = 2,
  bool requestsFull = false,
  bool sample = false,
  int ownerLevel = 3,
}) =>
    PublicTrip.fromJson({
      ...publicTripJson(
        isMine: isMine,
        waitingRequests: waitingRequests,
        myJoin: myJoin,
        joinGender: joinGender,
        notOpen: notOpen,
        seatsLeft: seatsLeft,
        sample: sample,
        ownerLevel: ownerLevel,
        ownerTrips: 40,
      ),
      'requestsFull': requestsFull,
    });

String _label(Finder action) {
  final w = action.evaluate().single.widget;
  return switch (w) {
    GradientPillButton(:final label) => label,
    WhitePillButton(:final label) => label,
    _ => '',
  };
}

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    CityCoverLookup.debugReset();
    putSeeker();
  });
  tearDown(Get.reset);

  group('actionOf', () {
    test('every state maps to one action, in the feed order', () {
      expect(TripJoinCard.actionOf(_trip(sample: true)), TripCardAction.none);
      expect(TripJoinCard.actionOf(_trip(isMine: true, waitingRequests: 3)), TripCardAction.requests);
      expect(TripJoinCard.actionOf(_trip(isMine: true, waitingRequests: 0)), TripCardAction.noRequests);
      expect(TripJoinCard.actionOf(_trip(isMine: true)), TripCardAction.noRequests);
      expect(TripJoinCard.actionOf(_trip(isMine: true, seatsLeft: 0, requestsFull: true)), TripCardAction.noRequests);
      expect(TripJoinCard.actionOf(_trip(myJoin: 'requested')), TripCardAction.requested);
      expect(TripJoinCard.actionOf(_trip(myJoin: 'member')), TripCardAction.openTrip);
      expect(TripJoinCard.actionOf(_trip(myJoin: 'declined')), TripCardAction.declined);
      expect(TripJoinCard.actionOf(_trip(myJoin: 'removed')), TripCardAction.removed);
      expect(TripJoinCard.actionOf(_trip(joinGender: 'F', notOpen: true)), TripCardAction.onlyFor);
      expect(TripJoinCard.actionOf(_trip(joinGender: 'F', notOpen: true, seatsLeft: 0)), TripCardAction.onlyFor);
      expect(TripJoinCard.actionOf(_trip(seatsLeft: 0)), TripCardAction.full);
      expect(TripJoinCard.actionOf(_trip(requestsFull: true)), TripCardAction.full);
      expect(TripJoinCard.actionOf(_trip(myJoin: 'requested', seatsLeft: 0)), TripCardAction.requested);
      expect(TripJoinCard.actionOf(_trip()), TripCardAction.join);
    });
  });

  group('labels', () {
    final cases = <(String, PublicTrip, String, bool)>[
      ('join', _trip(), SocialStringsB.join, true),
      ('requested', _trip(myJoin: 'requested'), SocialStringsB.requested, true),
      ('requests', _trip(isMine: true, waitingRequests: 3), SocialStringsB.requests(3), true),
      ('no requests', _trip(isMine: true, waitingRequests: 0), SocialStringsB.noRequests, false),
      ('member', _trip(myJoin: 'member'), SocialStringsB.openTrip, true),
      ('declined', _trip(myJoin: 'declined'), SocialStringsB.notThisTime, false),
      ('removed', _trip(myJoin: 'removed'), SocialStringsB.cannotJoin, false),
      ('only for', _trip(joinGender: 'F', notOpen: true), SocialStrings.womenOnly, false),
      ('full', _trip(seatsLeft: 0), SocialStringsB.full, false),
    ];
    for (final (name, trip, label, live) in cases) {
      testWidgets('$name reads $label${live ? '' : ' and is off'}', (t) async {
        installServer();
        await pumpSocial(t, _host(TripJoinCard(trip: trip)), pages: _pages);
        final action = find.byKey(TripJoinCard.actionKey(trip.tripId));
        expect(action, findsOneWidget);
        expect(_label(action), label);
        final w = action.evaluate().single.widget;
        final on = switch (w) {
          GradientPillButton(:final enabled, :final onTap) => enabled && onTap != null,
          WhitePillButton(:final enabled, :final onTap) => enabled && onTap != null,
          _ => false,
        };
        expect(on, live);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('a sample card has no action button', (t) async {
      installServer();
      final trip = _trip(sample: true);
      await pumpSocial(t, _host(TripJoinCard(trip: trip)), pages: _pages);
      expect(find.byKey(TripJoinCard.actionKey(trip.tripId)), findsNothing);
      expect(find.byKey(TripJoinCard.followKey), findsNothing);
      expect(find.byKey(TripJoinCard.levelKey), findsNothing);
    });

    testWidgets('the only-for button carries the lock icon', (t) async {
      installServer();
      final trip = _trip(joinGender: 'F', notOpen: true);
      await pumpSocial(t, _host(TripJoinCard(trip: trip)), pages: _pages);
      expect(t.widget<GradientPillButton>(find.byKey(TripJoinCard.actionKey(trip.tripId))).icon, Icons.lock_rounded);
    });
  });

  testWidgets('Join opens the request sheet, sends, calls onRequested and shows the snack', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.on('POST', '/social/trips/trip-1/join-requests', {'id': 'jr-1', 'status': 'Waiting'});
    final requested = <String>[];
    await pumpSocial(t, _host(TripJoinCard(trip: _trip(), onRequested: requested.add)), pages: _pages);
    await t.tap(find.byKey(TripJoinCard.actionKey('trip-1')));
    await settle(t);
    expect(find.byKey(JoinRequestSheet.sendKey), findsOneWidget);
    await t.tap(find.byKey(JoinRequestSheet.sendKey));
    await settle(t);
    expect(server.calls('POST', '/social/trips/trip-1/join-requests'), hasLength(1));
    expect(requested, ['trip-1']);
    expect(find.text(SocialStringsB.requestSent), findsOneWidget);
    await drain(t);
  });

  testWidgets('a refused request reports the stale type and does not call onRequested', (t) async {
    final server = installServer();
    putSocialMe(server, socialMeWith());
    server.refuse('POST', '/social/trips/trip-1/join-requests', status: 409, type: SocialErrorTypes.tripRequestsFull);
    final requested = <String>[];
    final stale = <(String, String?)>[];
    await pumpSocial(t, _host(TripJoinCard(trip: _trip(), onRequested: requested.add, onStale: (id, type) => stale.add((id, type)))), pages: _pages);
    await t.tap(find.byKey(TripJoinCard.actionKey('trip-1')));
    await settle(t);
    await t.tap(find.byKey(JoinRequestSheet.sendKey));
    await settle(t);
    expect(requested, isEmpty);
    expect(stale, [('trip-1', SocialErrorTypes.tripRequestsFull)]);
    await drain(t);
  });

  testWidgets('N requests opens Join requests', (t) async {
    installServer();
    await pumpSocial(t, _host(TripJoinCard(trip: _trip(isMine: true, waitingRequests: 3))), pages: _pages);
    await t.tap(find.byKey(TripJoinCard.actionKey('trip-1')));
    await settle(t);
    expect(find.text('REQUESTS trip-1'), findsOneWidget);
  });

  testWidgets('coming back from Join requests or the trip post calls onBack, so My posts reloads its counts', (t) async {
    installServer();
    var backs = 0;
    await pumpSocial(t, _host(TripJoinCard(trip: _trip(isMine: true, waitingRequests: 3), onBack: () => backs++)), pages: _pages);
    await t.tap(find.byKey(TripJoinCard.actionKey('trip-1')));
    await settle(t);
    expect(backs, 0);
    Get.back();
    await settle(t);
    expect(backs, 1);
    await t.tap(find.text('Rishikesh'));
    await settle(t);
    expect(find.text('POST trip-1'), findsOneWidget);
    Get.back();
    await settle(t);
    expect(backs, 2);
  });

  testWidgets('Requested opens the trip post', (t) async {
    installServer();
    await pumpSocial(t, _host(TripJoinCard(trip: _trip(myJoin: 'requested'))), pages: _pages);
    await t.tap(find.byKey(TripJoinCard.actionKey('trip-1')));
    await settle(t);
    expect(find.text('POST trip-1'), findsOneWidget);
  });

  testWidgets('a member opens the trip', (t) async {
    installServer();
    await pumpSocial(t, _host(TripJoinCard(trip: _trip(myJoin: 'member'))), pages: _pages);
    await t.tap(find.byKey(TripJoinCard.actionKey('trip-1')));
    await settle(t);
    expect(find.text('TRIP trip-1'), findsOneWidget);
  });

  testWidgets('tapping the card opens the trip post', (t) async {
    installServer();
    await pumpSocial(t, _host(TripJoinCard(trip: _trip())), pages: _pages);
    expect(find.byKey(TripJoinCard.cardKey('trip-1')), findsOneWidget);
    await t.tap(find.text('Rishikesh'));
    await settle(t);
    expect(find.text('POST trip-1'), findsOneWidget);
  });

  testWidgets('someone else: Follow at the right of the poster row below the cover, short name with Level N; no chips', (t) async {
    installServer();
    await pumpSocial(t, _host(TripJoinCard(trip: _trip(ownerLevel: 3))), pages: _pages);
    expect(find.text('Kavya S.'), findsOneWidget);
    expect(find.descendant(of: find.byKey(TripJoinCard.levelKey), matching: find.text(SocialStringsB.levelN(3))), findsOneWidget);
    expect(find.byKey(TripJoinCard.followKey), findsOneWidget);
    expect(find.text(SocialStrings.follow), findsOneWidget);
    final follow = t.getRect(find.byKey(TripJoinCard.followKey));
    final city = t.getRect(find.text('Rishikesh'));
    final name = t.getRect(find.text('Kavya S.'));
    final level = t.getRect(find.byKey(TripJoinCard.levelKey));
    final card = t.getRect(find.byKey(TripJoinCard.cardKey('trip-1')));
    expect(follow.top, greaterThan(city.bottom));
    expect(name.top, greaterThan(city.bottom));
    expect(follow.left, greaterThan(name.right));
    expect(follow.left, greaterThan(level.right));
    expect(follow.top, lessThan(level.bottom));
    expect(follow.bottom, greaterThan(name.top));
    expect(card.right - follow.right, lessThan(30));
    expect(level.top, greaterThan(name.top));
    expect(find.byType(InfoPill), findsNothing);
    expect(find.byType(TravelModeChip), findsNothing);
    expect(find.text('Rishikesh'), findsOneWidget);
    expect(find.text('December'), findsOneWidget);
    expect(find.text('2 seats left'), findsOneWidget);
    expect(find.text('5 days'), findsOneWidget);
    expect(find.text('Anyone'), findsOneWidget);
  });

  testWidgets('Follow reports the new state', (t) async {
    final server = installServer();
    server.on('PUT', '/social/travellers/kavya/follow', {'state': 'following'});
    final changes = <(String, bool)>[];
    await pumpSocial(t, _host(TripJoinCard(trip: _trip(), onFollowChanged: (id, f) => changes.add((id, f)))), pages: _pages);
    await t.tap(find.byKey(TripJoinCard.followKey));
    await settle(t);
    expect(changes.first, ('kavya', true));
    await drain(t);
  });

  testWidgets('my own post: You with my level, no Follow', (t) async {
    installServer();
    await pumpSocial(t, _host(TripJoinCard(trip: _trip(isMine: true, ownerLevel: 2))), pages: _pages);
    expect(find.text(SocialStringsB.you), findsOneWidget);
    expect(find.text('Kavya S.'), findsNothing);
    expect(find.text(SocialStringsB.levelN(2)), findsOneWidget);
    expect(find.byKey(TripJoinCard.followKey), findsNothing);
  });

  testWidgets('my own post: the more button sits at the right of the city title row', (t) async {
    installServer();
    await pumpSocial(t, _host(TripJoinCard(trip: _trip(isMine: true))), pages: _pages);
    expect(find.byKey(TripJoinCard.menuKey), findsOneWidget);
    final menu = t.getRect(find.byKey(TripJoinCard.menuKey));
    final city = t.getRect(find.text('Rishikesh'));
    expect(menu.left, greaterThan(city.right));
    expect(menu.top, lessThan(city.bottom));
  });

  testWidgets('my own post: the more button opens Edit post / Members / Delete trip', (t) async {
    installServer();
    await pumpSocial(t, _host(TripJoinCard(trip: _trip(isMine: true))), pages: _pages);
    await t.tap(find.byKey(TripJoinCard.menuKey));
    await settle(t);
    expect(find.text(SocialStringsB.editPost), findsOneWidget);
    expect(find.text(SocialStringsB.membersN(0)), findsOneWidget);
    expect(find.text(SocialStringsB.deleteTrip), findsOneWidget);
    expect(find.text('POST trip-1'), findsNothing);
  });

  testWidgets('no more button on others\' posts or a sample; Follow unchanged for others', (t) async {
    installServer();
    await pumpSocial(t, _host(Column(children: [TripJoinCard(trip: _trip()), TripJoinCard(trip: _trip(sample: true))])), pages: _pages);
    expect(find.byKey(TripJoinCard.menuKey), findsNothing);
    expect(find.byKey(TripJoinCard.followKey), findsOneWidget);
  });

  testWidgets('showOwner false hides the poster row', (t) async {
    installServer();
    await pumpSocial(t, _host(TripJoinCard(trip: _trip(), showOwner: false)), pages: _pages);
    expect(find.text('Kavya S.'), findsNothing);
    expect(find.byKey(TripJoinCard.levelKey), findsNothing);
    expect(find.byKey(TripJoinCard.followKey), findsNothing);
    expect(find.byKey(TripJoinCard.actionKey('trip-1')), findsOneWidget);
  });

  testWidgets('Full on the seats pill for others, not on my own post', (t) async {
    installServer();
    await pumpSocial(t, _host(Column(children: [TripJoinCard(trip: _trip(requestsFull: true)), TripJoinCard(trip: _trip(isMine: true, requestsFull: true))])), pages: _pages);
    expect(find.byKey(TripJoinCard.fullKey), findsOneWidget);
  });

  for (final (name, trip) in [
    ('join', _trip()),
    ('requests', _trip(isMine: true, waitingRequests: 12)),
    ('only for', _trip(joinGender: 'F', notOpen: true)),
    ('requested', _trip(myJoin: 'requested', joinGender: 'F')),
  ]) {
    testWidgets('$name: facts and the button stay on one line at 320 dp and text scale 1.3', (t) async {
      installServer();
      await pumpSocial(t, _host(TripJoinCard(trip: trip)), size: const Size(320, 1400), textScale: 1.3, pages: _pages);
      expect(t.takeException(), isNull);
      final action = t.getRect(find.byKey(TripJoinCard.actionKey(trip.tripId)));
      final fact = t.getRect(find.text('5 days'));
      expect((action.center.dy - fact.center.dy).abs(), lessThan(1.0));
      expect(action.left, greaterThan(fact.right));
      expect(t.renderObject<RenderParagraph>(find.text('5 days')).didExceedMaxLines, isFalse, reason: 'days must stay readable');
    });
  }

  group('city photo on the cover', () {
    const withPhoto = TripCityModel(cityKey: 201, name: 'Rishikesh', latitude: 30.1, longitude: 78.3, coverUrl: 'https://example.com/rishikesh.jpg');
    const noPhoto = TripCityModel(cityKey: 202, name: 'Chopta', latitude: 30.4, longitude: 79.2);

    testWidgets('the city photo fills the cover, Follow stays on the poster row below it', (t) async {
      installServer();
      TripCityCatalog.to.seedForTest(const [withPhoto, noPhoto]);
      final trip = PublicTrip.fromJson(publicTripJson(cityKey: 201));
      await pumpSocial(t, _host(TripJoinCard(trip: trip)), pages: _pages);
      expect(find.byKey(TripJoinCard.photoKey), findsOneWidget);
      expect(find.byType(TripCoverArt), findsNothing);
      expect(find.byKey(TripJoinCard.followKey), findsOneWidget);
      expect(find.descendant(of: find.byKey(TripJoinCard.photoKey), matching: find.byKey(TripJoinCard.followKey)), findsNothing);
      expect(t.getRect(find.byKey(TripJoinCard.followKey)).top, greaterThanOrEqualTo(t.getRect(find.byKey(TripJoinCard.photoKey)).bottom));
      expect(find.text('Rishikesh'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(minutes: 1));
    });

    testWidgets('a city without a photo keeps the gradient cover and art', (t) async {
      installServer();
      TripCityCatalog.to.seedForTest(const [withPhoto, noPhoto]);
      final trip = PublicTrip.fromJson(publicTripJson(cityKey: 202, cities: const ['Chopta']));
      await pumpSocial(t, _host(TripJoinCard(trip: trip)), pages: _pages);
      expect(find.byKey(TripJoinCard.photoKey), findsNothing);
      expect(find.byType(TripCoverArt), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
