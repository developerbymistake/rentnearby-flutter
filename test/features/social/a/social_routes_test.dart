import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/social/a/social_pages_a.dart';
import 'package:bakhli/features/social/b/feed/travel_buddies_screen.dart';
import 'package:bakhli/features/social/b/social_pages_b.dart';
import 'package:bakhli/features/social/b/wizard/post_trip_screen.dart';
import 'package:bakhli/features/social/shared/social_nav.dart';
import 'package:bakhli/navigation/traveller_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';

const _social = {
  AppRoutes.settings: '/settings',
  AppRoutes.editProfile: '/edit-profile',
  AppRoutes.traveller: '/traveller',
  AppRoutes.people: '/people',
  AppRoutes.addBuddies: '/add-buddies',
  AppRoutes.travelBuddies: '/travel-buddies',
  AppRoutes.tripPost: '/trip-post',
  AppRoutes.postTrip: '/post-trip',
  AppRoutes.joinRequests: '/join-requests',
  AppRoutes.dmRoom: '/dm-room',
  AppRoutes.seekerPlus: '/seeker-plus',
  AppRoutes.travelLevels: '/travel-levels',
};

void main() {
  setUpAll(() => initTestStorage('social_routes_test'));
  late FakeAuth auth;

  setUp(() {
    Get.testMode = true;
    Get.put<TabConfigController>(FakeTabs());
    auth = FakeAuth();
    Get.put<AuthController>(auth);
  });
  tearDown(Get.reset);

  test('the 12 social routes have the contract paths', () {
    _social.forEach((constant, path) => expect(constant, path));
    expect(_social, hasLength(12));
  });

  test('every social route is registered, gated by TravellerOnlyMiddleware and in travellerOnly', () {
    for (final route in _social.keys) {
      expect(AppRoutes.isRegistered(route), isTrue, reason: route);
      expect(AppRoutes.travellerOnly, contains(route));
      final page = AppRoutes.routes.firstWhere((p) => p.name == route);
      expect((page.middlewares ?? const []).whereType<TravellerOnlyMiddleware>(), isNotEmpty, reason: route);
    }
  });

  test('lane A owns settings, editProfile, traveller, people, addBuddies and travelLevels', () {
    expect({for (final p in socialPagesA) p.name}, {AppRoutes.settings, AppRoutes.editProfile, AppRoutes.traveller, AppRoutes.people, AppRoutes.addBuddies, AppRoutes.travelLevels});
  });

  test('a seeker opens every social route; owner shells cannot', () {
    for (final route in _social.keys) {
      auth.signIn(role: UserRoleKeys.seeker);
      expect(auth.canOpenRoute(route), isTrue, reason: '$route as seeker');
      auth.signIn(role: UserRoleKeys.stayOwner, stayStatus: 'Approved');
      expect(auth.canOpenRoute(route), isFalse, reason: '$route as stay owner');
      auth.signIn(role: UserRoleKeys.taxiDriver, taxiStatus: 'Approved');
      expect(auth.canOpenRoute(route), isFalse, reason: '$route as taxi driver');
    }
  });

  test('SocialNav exposes the contract methods', () {
    final List<Object> methods = [
      SocialNav.openSettings,
      SocialNav.openEditProfile,
      SocialNav.openTraveller,
      SocialNav.openPeople,
      SocialNav.openAddBuddies,
      SocialNav.openTravelBuddies,
      SocialNav.openTripPost,
      SocialNav.openPostTrip,
      SocialNav.openEditPost,
      SocialNav.openJoinRequests,
      SocialNav.openChats,
      SocialNav.openDirectChat,
      SocialNav.openRoom,
      SocialNav.openTripChat,
      SocialNav.openPlus,
    ];
    expect(methods, hasLength(15));
  });

  group('I-37 Travel groups tab argument', () {
    Future<void> app(WidgetTester t) async {
      await t.pumpWidget(GetMaterialApp(
        initialRoute: '/home',
        getPages: [
          GetPage(name: '/home', page: () => const Scaffold(body: Text('HOME'))),
          GetPage(
            name: AppRoutes.travelBuddies,
            page: () {
              final w = socialPagesB.firstWhere((p) => p.name == AppRoutes.travelBuddies).page() as TravelBuddiesScreen;
              return Scaffold(body: Text('ARGS ${Get.arguments} posted=${w.posted} mine=${w.myPosts}'));
            },
          ),
        ],
      ));
      await t.pumpAndSettle();
    }

    test('the tab names are explore and mine', () {
      expect(SocialNav.groupsExplore, 'explore');
      expect(SocialNav.groupsMine, 'mine');
    });

    testWidgets('default opens Explore with no tab argument', (t) async {
      await app(t);
      SocialNav.openTravelBuddies();
      await t.pumpAndSettle();
      expect(find.text('ARGS {} posted=false mine=false'), findsOneWidget);
    });

    testWidgets('tab mine opens My posts', (t) async {
      await app(t);
      SocialNav.openTravelBuddies(tab: SocialNav.groupsMine);
      await t.pumpAndSettle();
      expect(find.text('ARGS {tab: mine} posted=false mine=true'), findsOneWidget);
    });

    testWidgets('posted keeps its flag and opens My posts with the live card', (t) async {
      await app(t);
      SocialNav.openTravelBuddies(posted: true);
      await t.pumpAndSettle();
      expect(find.text('ARGS {posted: true} posted=true mine=false'), findsOneWidget);
    });

    testWidgets('an explicit Explore tab sends no argument, and the page on top is never stacked twice', (t) async {
      await app(t);
      SocialNav.openTravelBuddies(tab: SocialNav.groupsExplore);
      await t.pumpAndSettle();
      expect(find.text('ARGS {} posted=false mine=false'), findsOneWidget);
      expect(SocialNav.openTravelBuddies(tab: SocialNav.groupsMine), isNull);
    });
  });

  group('I-38 Edit post', () {
    Future<void> app(WidgetTester t) async {
      await t.pumpWidget(GetMaterialApp(
        initialRoute: '/home',
        getPages: [
          GetPage(name: '/home', page: () => const Scaffold(body: Text('HOME'))),
          GetPage(
            name: AppRoutes.postTrip,
            page: () {
              final w = socialPagesB.firstWhere((p) => p.name == AppRoutes.postTrip).page() as PostTripScreen;
              return Scaffold(body: Text('ARGS ${Get.arguments} trip=${w.tripId} edit=${w.edit}'));
            },
          ),
        ],
      ));
      await t.pumpAndSettle();
    }

    testWidgets('openEditPost sends tripId and edit true; the page reads edit', (t) async {
      await app(t);
      SocialNav.openEditPost('t-9');
      await t.pumpAndSettle();
      expect(find.text('ARGS {tripId: t-9, edit: true} trip=t-9 edit=true'), findsOneWidget);
    });

    testWidgets('openPostTrip stays a publish, not an edit', (t) async {
      await app(t);
      SocialNav.openPostTrip(tripId: 't-9');
      await t.pumpAndSettle();
      expect(find.text('ARGS {tripId: t-9} trip=t-9 edit=false'), findsOneWidget);
    });
  });
}
