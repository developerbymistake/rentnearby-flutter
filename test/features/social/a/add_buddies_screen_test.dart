import 'package:bakhli/features/buddy/shared/buddy_look.dart';
import 'package:bakhli/features/social/a/people/add_buddies_screen.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';

SocialFakeServer _server() {
  final s = installServer();
  s.on('GET', '/social/followers', {
    'items': [
      rowJson('rohan', 'Rohan Mehta', isBuddy: true),
      rowJson('aman', 'Aman Kumar'),
    ],
    'nextCursor': null,
    'total': 128,
    'buddies': 3,
  });
  return s;
}

Color? _starColor(WidgetTester t, String id) => t.widget<Icon>(find.descendant(of: find.byKey(ValueKey('star_$id')), matching: find.byType(Icon))).color;

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
      testWidgets('lists followers with stars and the not-told note ($size, $scale)', (t) async {
        _server();
        await pumpSocial(t, const AddBuddiesScreen(), size: size, textScale: scale);
        expect(find.text(SocialStringsA.addBuddiesTitle), findsOneWidget);
        expect(find.text(SocialStringsA.followersAndBuddies(128, 3).toUpperCase()), findsOneWidget);
        expect(find.byKey(const ValueKey('star_rohan')), findsOneWidget);
        expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
        expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
        expect(_starColor(t, 'rohan'), BuddyLook.amberText);
        expect(_starColor(t, 'aman'), BuddyLook.checkOff);
        expect(find.text(SocialStringsA.starNote), findsOneWidget);
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('a star tap adds with one call and no request; tapping again removes', (t) async {
    final s = _server();
    s.on('PUT', '/social/buddies/aman', {'isBuddy': true});
    s.on('DELETE', '/buddies/aman', {});
    await pumpSocial(t, const AddBuddiesScreen());
    await t.tap(find.byKey(const ValueKey('star_aman')));
    await settle(t);
    expect(s.calls('PUT', '/social/buddies/aman'), hasLength(1));
    expect(_starColor(t, 'aman'), BuddyLook.amberText);
    await t.tap(find.byKey(const ValueKey('star_aman')));
    await settle(t);
    expect(s.calls('DELETE', '/buddies/aman'), hasLength(1));
    expect(_starColor(t, 'aman'), BuddyLook.checkOff);
    await drain(t);
  });

  testWidgets('search is debounced and sends q', (t) async {
    final s = _server();
    await pumpSocial(t, const AddBuddiesScreen());
    final before = s.calls('GET', '/social/followers').length;
    await t.enterText(find.byKey(AddBuddiesScreen.searchKey), 'Ro');
    await t.pump(const Duration(milliseconds: 100));
    expect(s.calls('GET', '/social/followers').length, before);
    await t.pump(const Duration(milliseconds: 300));
    await settle(t);
    final last = s.calls('GET', '/social/followers').last;
    expect(last.queryParameters['q'], 'Ro');
    await drain(t);
  });
}
