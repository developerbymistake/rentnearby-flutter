import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/seeker_home/home_updates.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/buddy_render.dart';
import '../social/shared/social_test_support.dart';

class _Me extends SocialMeController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> refreshQuiet() async {}
}

class _NoTripsAuth extends FakeAuth {
  @override
  bool get tripsEnabled => false;
}

SocialMe _me({int invites = 2, int follow = 3, int join = 1}) {
  final j = socialMeJson(profile: myProfileJson());
  j['counts'] = {
    ...(j['counts'] as Map),
    'followRequests': follow,
    'tripInvites': invites,
    'joinRequests': join,
  };
  return SocialMe.fromJson(j);
}

void _putMe(SocialMe? me) {
  final c = Get.put<SocialMeController>(_Me());
  c.me.value = me;
}

final List<String> _visited = [];

List<GetPage<dynamic>> _pages() => [
      for (final r in [AppRoutes.myTrips, AppRoutes.people, AppRoutes.joinRequests, AppRoutes.travelBuddies])
        GetPage(
          name: r,
          page: () {
            _visited.add(r);
            return Scaffold(body: Text('$r ${Get.arguments}'));
          },
        ),
    ];

Widget _host() => const Scaffold(body: SingleChildScrollView(child: HomeUpdates()));

const _ids = ['invites', 'follow', 'join'];

Color? _pillColor(WidgetTester t, String id) {
  final boxes = find.descendant(of: find.byKey(ValueKey('home-upd-$id')), matching: find.byType(IgnorePointer));
  final c = t.widget<Container>(find.descendant(of: boxes.last, matching: find.byType(Container)).first);
  return (c.decoration as BoxDecoration).color;
}

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    _visited.clear();
    putSeeker();
  });
  tearDown(Get.reset);

  for (final w in [360.0, 412.0]) {
    testWidgets('three tiles in order, equal width, inside the screen ($w)', (t) async {
      _putMe(_me());
      await pumpSocial(t, _host(), size: Size(w, 900), pages: _pages());
      final rects = [for (final id in _ids) t.getRect(find.byKey(ValueKey('home-upd-$id')))];
      expect(find.text('Your updates'), findsOneWidget);
      expect(rects[0].left, lessThan(rects[1].left));
      expect(rects[1].left, lessThan(rects[2].left));
      for (final r in rects) {
        expect(r.width, moreOrLessEquals(rects.first.width, epsilon: 0.5));
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(w));
      }
      expect(t.takeException(), isNull);
      await drain(t);
    });
  }

  testWidgets('pills show the counts: red above 0, grey at 0, 99+ cap', (t) async {
    _putMe(_me(invites: 2, follow: 0, join: 120));
    await pumpSocial(t, _host(), pages: _pages());
    expect(find.text('2'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('99+'), findsOneWidget);
    expect(_pillColor(t, 'invites'), const Color(0xFFFF5287));
    expect(_pillColor(t, 'follow'), Ink3D.grey);
    expect(find.bySemanticsLabel('Trip invites, 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Follow requests, 0'), findsOneWidget);
    await drain(t);
  });

  testWidgets('counts update live when me changes', (t) async {
    _putMe(_me(invites: 2, follow: 3, join: 1));
    await pumpSocial(t, _host(), pages: _pages());
    expect(find.text('3'), findsOneWidget);
    SocialMeController.to.me.value = _me(invites: 0, follow: 5, join: 0);
    await t.pump();
    expect(find.text('5'), findsOneWidget);
    expect(find.text('3'), findsNothing);
    await drain(t);
  });

  testWidgets('taps open My trips Joined and People Requests', (t) async {
    _putMe(_me());
    await pumpSocial(t, _host(), pages: _pages());
    await t.tap(find.byKey(const ValueKey('home-upd-invites')));
    await settle(t);
    expect(Get.arguments, {'tab': 'joined'});
    Get.back();
    await settle(t);
    await t.tap(find.byKey(const ValueKey('home-upd-follow')));
    await settle(t);
    expect(Get.arguments, {'tab': 'requests'});
    expect(_visited, [AppRoutes.myTrips, AppRoutes.people]);
    await drain(t);
  });

  for (final join in [0, 1, 7]) {
    testWidgets('join tile always opens Travel groups on My posts ($join requests)', (t) async {
      _putMe(_me(join: join));
      await pumpSocial(t, _host(), pages: _pages());
      await t.tap(find.byKey(const ValueKey('home-upd-join')));
      await settle(t);
      expect(_visited, [AppRoutes.travelBuddies]);
      expect(Get.arguments, {'tab': 'mine'});
      await drain(t);
    });
  }

  testWidgets('Trips module off: no Trip invites tile', (t) async {
    Get.reset();
    Get.put<TabConfigController>(FakeTabs());
    Get.put<AuthController>(_NoTripsAuth()).roleKey.value = UserRoleKeys.seeker;
    _putMe(_me());
    await pumpSocial(t, _host(), pages: _pages());
    expect(find.byKey(const ValueKey('home-upd-invites')), findsNothing);
    expect(find.byKey(const ValueKey('home-upd-follow')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-upd-join')), findsOneWidget);
    await drain(t);
  });

  testWidgets('not a traveller: nothing', (t) async {
    Get.reset();
    putSeeker(role: UserRoleKeys.stayOwner);
    _putMe(_me());
    await pumpSocial(t, _host(), pages: _pages());
    expect(find.text('Your updates'), findsNothing);
    for (final id in _ids) {
      expect(find.byKey(ValueKey('home-upd-$id')), findsNothing);
    }
    await drain(t);
  });

  testWidgets('me not loaded: three tiles with 0', (t) async {
    _putMe(null);
    await pumpSocial(t, _host(), pages: _pages());
    for (final id in _ids) {
      expect(find.byKey(ValueKey('home-upd-$id')), findsOneWidget);
    }
    expect(find.text('0'), findsNWidgets(3));
    await drain(t);
  });
}
