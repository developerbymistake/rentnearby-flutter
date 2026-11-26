import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/social/b/rail/trips_to_join_rail.dart';
import 'package:bakhli/features/social/b/rail/trips_rail_controller.dart';
import 'package:bakhli/features/social/b/social_bindings_b.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

final _pages = [
  GetPage(name: AppRoutes.tripPost, page: () => Scaffold(body: Text('POST ${(Get.arguments as Map)['tripId']}'))),
  GetPage(name: AppRoutes.travelBuddies, page: () => const Scaffold(body: Text('FEED'))),
];

const _rail = '/social/trips/rail';

Widget _host() => const Scaffold(body: SingleChildScrollView(child: TripsToJoinRail()));

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
  });
  tearDown(Get.reset);

  test('Home places Trips to join right after Quick actions', () {
    final src = File('lib/screens/home_screen.dart').readAsStringSync();
    final qa = src.indexOf('StaggerItem(index: 1, child: SeekerQuickActions())');
    final rail = src.indexOf('StaggerItem(index: 2, child: TripsToJoinRail())');
    expect(qa, greaterThan(0));
    expect(rail, greaterThan(qa));
    expect(src, contains('_sections = 5'));
  });

  test('bindings put the rail controller once and the session clear removes it', () {
    SocialBindingsB.ensure();
    SocialBindingsB.ensure();
    expect(Get.isRegistered<TripsRailController>(), isTrue);
    SocialSessionB.clear();
    expect(Get.isRegistered<TripsRailController>(), isFalse);
  });

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('rail shows live posts; a tap opens the post ($size, $scale)', (t) async {
        final server = installServer();
        server.on('GET', _rail, {
          'items': [publicTripJson(id: 'trip-1'), publicTripJson(id: 'trip-2', cities: ['Spiti'], joinGender: 'M')],
        });
        Get.put(TripsRailController(), permanent: true);
        await pumpSocial(t, _host(), size: size, textScale: scale, pages: _pages);
        expect(find.text(SocialStringsB.tripsToJoin), findsOneWidget);
        expect(find.text('Rishikesh'), findsOneWidget);
        await t.tap(find.text('Rishikesh'));
        await settle(t);
        expect(find.text('POST trip-1'), findsOneWidget);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('with no posts the Bakhli team samples show and open the feed', (t) async {
    final server = installServer();
    server.on('GET', _rail, {
      'items': [
        publicTripJson(id: '00000000-0000-0000-0000-000000000001', ownerId: '', ownerName: 'Bakhli team', cities: ['Manali'], sample: true),
      ],
    });
    Get.put(TripsRailController(), permanent: true);
    await pumpSocial(t, _host(), pages: _pages);
    expect(find.text('Manali'), findsOneWidget);
    await t.tap(find.text('Manali'));
    await settle(t);
    expect(find.text('FEED'), findsOneWidget);
    await drain(t);
  });

  testWidgets('See all opens the feed', (t) async {
    final server = installServer();
    server.on('GET', _rail, {'items': [publicTripJson()]});
    Get.put(TripsRailController(), permanent: true);
    await pumpSocial(t, _host(), pages: _pages);
    await t.tap(find.text(SocialStringsB.seeAll));
    await settle(t);
    expect(find.text('FEED'), findsOneWidget);
    await drain(t);
  });

  testWidgets('the rail hides on error and without a controller', (t) async {
    final server = installServer();
    server.refuse('GET', _rail, status: 400, type: 'Bad');
    await pumpSocial(t, _host(), pages: _pages);
    expect(find.text(SocialStringsB.tripsToJoin), findsNothing);
    Get.put(TripsRailController(), permanent: true);
    await pumpSocial(t, _host(), pages: _pages);
    expect(find.text(SocialStringsB.tripsToJoin), findsNothing);
    await drain(t);
  });
}
