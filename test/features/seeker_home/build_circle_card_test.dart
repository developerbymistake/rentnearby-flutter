import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/features/seeker_home/build_circle_card.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/shared/social_live.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../support/buddy_render.dart';
import '../../support/owner_fakes.dart' show initTestStorage;
import '../social/shared/social_test_support.dart';
import 'seeker_home_harness.dart';

class _Me extends SocialMeController {
  int refreshes = 0;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> refreshQuiet() async => refreshes++;
}

SocialMe _meFollowing(int n) {
  final profile = myProfileJson();
  profile['counters'] = {...(profile['counters'] as Map), 'following': n};
  return SocialMe.fromJson(socialMeJson(profile: profile));
}

_Me _putMe({int? following}) {
  final me = Get.put<SocialMeController>(_Me()) as _Me;
  if (following != null) me.me.value = _meFollowing(following);
  return me;
}

final _pages = [GetPage(name: AppRoutes.people, page: () => Scaffold(body: Text('PEOPLE ${(Get.arguments as Map)['tab']}')))];

Widget _host() => const Scaffold(body: SingleChildScrollView(child: BuildCircleCard()));

void main() {
  group('card', () {
    useBuddyRenderScale();
    setUpAll(initSocialTestStorage);
    setUp(() {
      Get.reset();
      putSeeker();
    });
    tearDown(Get.reset);

    testWidgets('following fewer than 5: title, line and Find travellers; the tap opens Discover', (t) async {
      installServer();
      _putMe(following: 3);
      await pumpSocial(t, _host(), pages: _pages);
      expect(find.byKey(BuildCircleCard.cardKey), findsOneWidget);
      expect(find.text(SocialStringsA.circleTitle), findsOneWidget);
      expect(find.text(SocialStringsA.circleLine), findsOneWidget);
      expect(find.text(SocialStringsA.findTravellers), findsOneWidget);
      await t.tap(find.byKey(BuildCircleCard.cardKey));
      await settle(t);
      expect(find.text('PEOPLE discover'), findsOneWidget);
      await drain(t);
    });

    testWidgets('hidden at 5 and hides by itself when the count reaches 5', (t) async {
      installServer();
      final me = _putMe(following: 5);
      await pumpSocial(t, _host(), pages: _pages);
      expect(find.byKey(BuildCircleCard.cardKey), findsNothing);
      me.me.value = _meFollowing(4);
      await t.pump();
      expect(find.byKey(BuildCircleCard.cardKey), findsOneWidget);
      me.me.value = _meFollowing(5);
      await t.pump();
      expect(find.byKey(BuildCircleCard.cardKey), findsNothing);
      await drain(t);
    });

    testWidgets('a follow refreshes the count while the card shows, not after', (t) async {
      installServer();
      final me = _putMe(following: 4);
      await pumpSocial(t, _host(), pages: _pages);
      SocialLive.followers.value++;
      await t.pump();
      expect(me.refreshes, 1);
      me.me.value = _meFollowing(5);
      await t.pump();
      SocialLive.followers.value++;
      await t.pump();
      expect(me.refreshes, 1);
      await drain(t);
    });

    testWidgets('hidden until the social profile exists', (t) async {
      installServer();
      final me = _putMe();
      await pumpSocial(t, _host(), pages: _pages);
      expect(find.byKey(BuildCircleCard.cardKey), findsNothing);
      me.me.value = SocialMe.fromJson(socialMeJson());
      await t.pump();
      expect(find.byKey(BuildCircleCard.cardKey), findsNothing);
      await drain(t);
    });

    testWidgets('hidden with no social session', (t) async {
      installServer();
      await pumpSocial(t, _host(), pages: _pages);
      expect(find.byKey(BuildCircleCard.cardKey), findsNothing);
      await drain(t);
    });

    testWidgets('an owner never sees it', (t) async {
      Get.reset();
      putSeeker(role: UserRoleKeys.stayOwner);
      installServer();
      _putMe(following: 0);
      await pumpSocial(t, _host(), pages: _pages);
      expect(find.byKey(BuildCircleCard.cardKey), findsNothing);
      await drain(t);
    });
  });

  group('home', () {
    late GetStorage box;
    setUpAll(() async {
      await initTestStorage('build_circle_home');
      box = GetStorage();
    });
    setUp(() async => box.erase());
    tearDown(Get.reset);

    Future<void> pumpHome(WidgetTester t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(392, 2600);
      addTearDown(t.view.reset);
      await t.pumpWidget(GetMaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.theme, getPages: routeStubs(), home: homeHost()));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 300));
      }
    }

    testWidgets('the card sits between the trip card and Post your trip', (t) async {
      registerHome(feed: fixtureNoTrip());
      Get.find<AuthController>().roleKey.value = UserRoleKeys.seeker;
      _putMe(following: 2);
      await pumpHome(t);
      final card = find.byKey(BuildCircleCard.cardKey);
      expect(card, findsOneWidget);
      final trip = t.getTopLeft(find.text('Plan your trip').first).dy;
      final post = t.getTopLeft(find.text('Post your trip').first).dy;
      final top = t.getTopLeft(card).dy;
      expect(top, greaterThan(trip));
      expect(top, lessThan(post));
    });

    testWidgets('no card on Home at 5 follows', (t) async {
      registerHome(feed: fixtureNoTrip());
      Get.find<AuthController>().roleKey.value = UserRoleKeys.seeker;
      _putMe(following: 5);
      await pumpHome(t);
      expect(find.byKey(BuildCircleCard.cardKey), findsNothing);
      expect(find.text('Your updates'), findsWidgets);
    });
  });
}
