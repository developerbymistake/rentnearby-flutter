import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/social/a/profile/traveller_profile_screen.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';

final _pages = [GetPage(name: AppRoutes.dmRoom, page: () => Scaffold(body: Text('DM ${(Get.arguments as Map)['userId']}')))];

const _path = '/social/travellers/kavya';

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
      testWidgets('a public traveller: Follow + Message, mutuals line, About ($size, $scale)', (t) async {
        final server = installServer();
        server.on('GET', _path, travellerJson());
        await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), size: size, textScale: scale, pages: _pages);
        expect(find.text('Kavya S.'), findsWidgets);
        expect(find.text('Kavya Sharma'), findsNothing);
        expect(find.text(SocialStrings.follow), findsOneWidget);
        expect(find.text(SocialStrings.message), findsOneWidget);
        expect(find.text('Followed by Aman and 3 others you know'), findsOneWidget);
        expect(find.text('Mountains, chai and long walks.'), findsOneWidget);
        expect(find.byKey(TravellerProfileScreen.buddyKey), findsNothing);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('the buddy star shows only when they follow me, and toggles with PUT then DELETE', (t) async {
    final server = installServer();
    server.on('GET', _path, travellerJson(followsMe: true, iFollow: true));
    server.on('PUT', '/social/buddies/kavya', {'isBuddy': true});
    server.on('DELETE', '/buddies/kavya', {});
    await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
    expect(find.text(SocialStrings.followEachOther), findsOneWidget);
    expect(find.text(SocialStrings.addToBuddies), findsOneWidget);
    await t.tap(find.byKey(TravellerProfileScreen.buddyKey));
    await settle(t);
    expect(server.calls('PUT', '/social/buddies/kavya'), hasLength(1));
    expect(find.text(SocialStrings.buddy), findsNWidgets(2));
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    await drain(t);
    await t.tap(find.byKey(TravellerProfileScreen.buddyKey));
    await settle(t);
    expect(server.calls('DELETE', '/buddies/kavya'), hasLength(1));
    expect(find.text(SocialStrings.addToBuddies), findsOneWidget);
    await drain(t);
  });

  testWidgets('NotFollower refusal rolls the star back', (t) async {
    final server = installServer();
    server.on('GET', _path, travellerJson(followsMe: true));
    server.refuse('PUT', '/social/buddies/kavya', status: 409, type: 'NotFollower', message: 'You can add only people who follow you.');
    await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
    await t.tap(find.byKey(TravellerProfileScreen.buddyKey));
    await settle(t);
    expect(find.text(SocialStrings.addToBuddies), findsOneWidget);
    await drain(t);
  });

  testWidgets('follow on a private profile turns into Requested', (t) async {
    final server = installServer();
    server.on('GET', _path, travellerJson(privateLocked: true, mutualCount: 0));
    server.on('PUT', '$_path/follow', {'state': 'requested'});
    await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
    expect(find.textContaining(SocialStringsA.privateTitle), findsOneWidget);
    expect(find.text('Mountains, chai and long walks.'), findsNothing);
    await t.tap(find.text(SocialStrings.follow));
    await settle(t);
    expect(find.text(SocialStrings.requested), findsOneWidget);
    await drain(t);
  });

  testWidgets('Message opens the direct chat route', (t) async {
    final server = installServer();
    server.on('GET', _path, travellerJson());
    await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
    await t.tap(find.byKey(TravellerProfileScreen.messageKey));
    await settle(t);
    expect(find.text('DM kavya'), findsOneWidget);
    await drain(t);
  });

  testWidgets('an unknown or blocked person shows the not-found state', (t) async {
    final server = installServer();
    server.refuse('GET', _path, status: 404, type: 'PersonNotFound');
    await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
    expect(find.text(SocialStringsA.travellerGone), findsOneWidget);
    expect(find.byKey(TravellerProfileScreen.menuKey), findsNothing);
    await drain(t);
  });
}
