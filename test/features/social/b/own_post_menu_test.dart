import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/social/b/post/own_post_menu.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/shared/post_removal.dart';
import 'package:bakhli/features/social/shared/social_live.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

final _pages = [
  GetPage(name: AppRoutes.postTrip, page: () => Scaffold(body: Text('POST TRIP ${Get.arguments}'))),
  GetPage(name: AppRoutes.tripTravellers, page: () => Scaffold(body: Text('TRAVELLERS ${(Get.arguments as Map)['tripId']}'))),
];

PublicTrip _mine({int? members}) => PublicTrip.fromJson({
      ...publicTripJson(isMine: true, ownerId: 'me', ownerName: 'Rahul Verma'),
      'members': members,
    });

class _Calls {
  int changed = 0;
  int deleted = 0;
  int? postsAtDelete;
}

Widget _host(PublicTrip trip, _Calls calls) => Scaffold(
      body: Builder(
        builder: (c) => Center(
          child: TextButton(
            onPressed: () => OwnPostMenu.show(c, trip: trip, onChanged: () => calls.changed++, onDeleted: () {
              calls.deleted++;
              calls.postsAtDelete = SocialLive.posts.value;
            }),
            child: const Text('MENU'),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester t, PublicTrip trip, _Calls calls) async {
  await pumpSocial(t, _host(trip, calls), pages: _pages);
  await t.tap(find.text('MENU'));
  await settle(t);
}

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
    installServer();
  });
  tearDown(() {
    OwnPostMenu.debugDelete = null;
    PostRemovalNotice.debugOpenTravellers = null;
    Get.reset();
  });

  testWidgets('three rows: Edit post, Members · N, Delete trip', (t) async {
    final calls = _Calls();
    await _open(t, _mine(members: 2), calls);
    expect(find.byKey(OwnPostMenu.editKey), findsOneWidget);
    expect(find.byKey(OwnPostMenu.membersKey), findsOneWidget);
    expect(find.byKey(OwnPostMenu.deleteKey), findsOneWidget);
    expect(find.text(SocialStringsB.editPost), findsOneWidget);
    expect(find.text(SocialStringsB.editPostLine), findsOneWidget);
    expect(find.text('Members · 2'), findsOneWidget);
    expect(find.text(SocialStringsB.membersLine), findsOneWidget);
    expect(find.text(SocialStringsB.deleteTrip), findsOneWidget);
    expect(find.text(SocialStringsB.deleteTripBlocked), findsOneWidget);
    expect(find.text(SocialStrings.removeMembersFirstLine(2)), findsNothing, reason: 'frame 16: no count on the delete line');
    expect(find.text('Rishikesh'), findsNothing, reason: 'frames 16/18: a grab handle and three rows, no header');
    await drain(t);
  });

  testWidgets('no other travellers: Members without a count and no block line', (t) async {
    final calls = _Calls();
    await _open(t, _mine(members: 0), calls);
    expect(find.text('Members'), findsOneWidget);
    expect(find.textContaining('Members ·'), findsNothing);
    expect(find.textContaining('Remove the other travellers'), findsNothing);
    await drain(t);
  });

  testWidgets('a blocked delete opens the members-first notice and never deletes', (t) async {
    final calls = _Calls();
    var deletes = 0;
    OwnPostMenu.debugDelete = (ctx, id) async {
      deletes++;
      return true;
    };
    final opened = <String>[];
    PostRemovalNotice.debugOpenTravellers = (id) async => opened.add(id);
    final before = SocialLive.posts.value;
    await _open(t, _mine(members: 2), calls);
    await t.tap(find.byKey(OwnPostMenu.deleteKey));
    await settle(t);
    expect(find.text(SocialStrings.removeMembersFirstTitle), findsOneWidget);
    await t.tap(find.text(SocialStrings.seeTravellers));
    await settle(t);
    expect(opened, ['trip-1']);
    expect(deletes, 0);
    expect(SocialLive.posts.value, before + 1);
    expect(calls.changed, 1);
    expect(calls.deleted, 0);
    await drain(t);
  });

  testWidgets('an unblocked delete runs the delete flow, refreshes the posts and calls onDeleted', (t) async {
    final calls = _Calls();
    final ids = <String>[];
    OwnPostMenu.debugDelete = (_, id) async {
      ids.add(id);
      return true;
    };
    final before = SocialLive.posts.value;
    await _open(t, _mine(members: 0), calls);
    await t.tap(find.byKey(OwnPostMenu.deleteKey));
    await settle(t);
    expect(ids, ['trip-1']);
    expect(SocialLive.posts.value, before + 1);
    expect(calls.deleted, 1);
    expect(calls.postsAtDelete, before, reason: 'onDeleted runs before the lists reload');
    await drain(t);
  });

  testWidgets('a cancelled delete changes nothing', (t) async {
    final calls = _Calls();
    OwnPostMenu.debugDelete = (ctx, id) async => false;
    final before = SocialLive.posts.value;
    await _open(t, _mine(), calls);
    await t.tap(find.byKey(OwnPostMenu.deleteKey));
    await settle(t);
    expect(SocialLive.posts.value, before);
    expect(calls.deleted, 0);
    await drain(t);
  });

  testWidgets('Edit post opens the post wizard in edit mode', (t) async {
    final calls = _Calls();
    await _open(t, _mine(), calls);
    await t.tap(find.byKey(OwnPostMenu.editKey));
    await settle(t);
    expect(find.text('POST TRIP {tripId: trip-1, edit: true}'), findsOneWidget);
    Get.back<void>();
    await settle(t);
    expect(calls.changed, 1);
    await drain(t);
  });

  testWidgets('Members opens the travellers page, then refreshes the posts', (t) async {
    final calls = _Calls();
    final before = SocialLive.posts.value;
    await _open(t, _mine(members: 1), calls);
    await t.tap(find.byKey(OwnPostMenu.membersKey));
    await settle(t);
    expect(find.text('TRAVELLERS trip-1'), findsOneWidget);
    Get.back<void>();
    await settle(t);
    expect(SocialLive.posts.value, before + 1);
    expect(calls.changed, 1);
    await drain(t);
  });
}
