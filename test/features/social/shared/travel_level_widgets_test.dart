import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/a/profile/profile_sections.dart';
import 'package:bakhli/features/social/a/profile/seeker_profile_screen.dart';
import 'package:bakhli/features/social/a/profile/travel_levels_screen.dart';
import 'package:bakhli/features/social/a/profile/traveller_profile_screen.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:bakhli/features/social/shared/travel_levels.dart';
import 'package:bakhli/features/social/shared/widgets/level_up_host.dart';
import 'package:bakhli/features/social/shared/widgets/travel_level_widgets.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'social_test_support.dart';

Widget _list(List<Widget> children) => Scaffold(body: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)));

final _pages = [
  GetPage(name: AppRoutes.travelLevels, page: () => const TravelLevelsScreen()),
  GetPage(name: AppRoutes.people, page: () => const Scaffold(body: Text('PEOPLE'))),
  GetPage(name: AppRoutes.settings, page: () => const Scaffold(body: Text('SETTINGS'))),
  GetPage(name: AppRoutes.editProfile, page: () => const Scaffold(body: Text('EDIT'))),
];

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(Get.reset);
  tearDown(Get.reset);

  testWidgets('every level renders its trophy tile; only Travel King carries the gold ring', (t) async {
    await pumpSocial(t, _list([for (final l in TravelLevels.all) TrophyTile(level: l)]));
    for (final l in TravelLevels.all) {
      expect(find.byWidgetPredicate((w) => w is Art3D && w.asset == l.asset), findsOneWidget, reason: l.name);
    }
    expect(find.byKey(TrophyTile.ringKey), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('badge shows the round trophy and N trips; count can be hidden', (t) async {
    await pumpSocial(t, _list(const [TrophyBadge(level: 4, trips: 124), TrophyBadge(level: 0, trips: 0, showCount: false), TrophyBadge(level: 1, trips: 1)]));
    expect(find.text('124 trips'), findsOneWidget);
    expect(find.text('1 trip'), findsOneWidget);
    expect(find.text('0 trips'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is Art3D && w.asset == ListingArt.trophyLevel0), findsOneWidget);
    expect(find.bySemanticsLabel('Pathfinder, 124 trips'), findsOneWidget);
  });

  testWidgets('level panel: name, trips, next level text; King says highest level', (t) async {
    var taps = 0;
    await pumpSocial(t, _list([LevelPanelCard(trips: 124, level: 4, onTap: () => taps++), const LevelPanelCard(trips: 612, level: 6)]));
    expect(find.text('LEVEL 4'), findsOneWidget);
    expect(find.text('Pathfinder'), findsOneWidget);
    expect(find.text('124 trips done'), findsOneWidget);
    expect(find.textContaining('76 more trips'), findsOneWidget);
    expect(find.text('Summit Seeker'), findsOneWidget);
    expect(find.text(SocialStrings.highestLevel), findsOneWidget);
    await t.tap(find.byKey(LevelPanelCard.panelKey).first);
    expect(taps, 1);
  });

  for (final level in [0, 3, 6]) {
    testWidgets('levels list at level $level: done levels ticked, one You are here, the rest dimmed', (t) async {
      await pumpSocial(t, _list([LevelListCard(level: level)]));
      for (var i = 0; i < 7; i++) {
        expect(find.byKey(LevelRow.tickKey(i)), i < level ? findsOneWidget : findsNothing, reason: 'tick $i');
      }
      expect(find.byKey(LevelRow.hereKey), findsOneWidget);
      expect(find.descendant(of: find.byType(LevelRow), matching: find.byType(Opacity)), findsNWidgets(6 - level));
    });
  }

  testWidgets('Travel levels page reads /social/me: top card, 7 rows, footer', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson(completedTrips: 124, level: 4)));
    putSeeker();
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const TravelLevelsScreen());
    expect(find.text(SocialStrings.travelLevelsTitle), findsOneWidget);
    expect(find.byKey(LevelTopCard.cardKey), findsOneWidget);
    expect(find.text('at 200 trips'), findsOneWidget);
    for (var i = 0; i < 7; i++) {
      expect(find.byKey(LevelRow.keyOf(i)), findsOneWidget);
    }
    expect(find.text(SocialStrings.levelsFooter), findsOneWidget);
    await drain(t);
  });

  testWidgets('my profile: white stat tiles, Trips = completed trips, panel opens the Travel levels page', (t) async {
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson(completedTrips: 124, level: 4)));
    putSeeker();
    Get.put(SocialMeController(), permanent: true);
    await pumpSocial(t, const SeekerProfileScreen(), size: const Size(392, 2000), pages: _pages);
    final trips = t.widget<Text>(find.text('124'));
    expect(trips.style!.color, ProfileStatColors.trips);
    expect(t.widget<Text>(find.text('128')).style!.color, ProfileStatColors.followers);
    expect(t.widget<Text>(find.text('41')).style!.color, ProfileStatColors.following);
    await t.tap(find.byKey(LevelPanelCard.panelKey));
    await settle(t);
    expect(find.byType(TravelLevelsScreen), findsOneWidget);
    await drain(t);
  });

  testWidgets('another traveller: trophy and count right of the name row', (t) async {
    final server = installServer();
    server.on('GET', '/social/travellers/kavya', travellerJson(completedTrips: 46, level: 3));
    putSeeker();
    await pumpSocial(t, const TravellerProfileScreen(userId: 'kavya'), pages: _pages);
    expect(find.byKey(TravellerLevelMark.markKey), findsOneWidget);
    expect(t.widget<Text>(find.descendant(of: find.byType(ProfileCounters), matching: find.text('46'))).style!.color, ProfileStatColors.trips);
    expect(find.descendant(of: find.byKey(TravellerLevelMark.markKey), matching: find.text('46')), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Art3D && w.asset == ListingArt.trophyLevel3), findsOneWidget);
    final mark = t.getRect(find.byKey(TravellerLevelMark.markKey));
    final name = t.getRect(find.text('Kavya Sharma').first);
    expect(mark.left, greaterThan(name.right));
    await drain(t);
  });

  testWidgets('level-up sheet: big trophy, new level title, Keep exploring closes it', (t) async {
    await pumpSocial(t, Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => LevelUpSheet.show(c, level: 4, trips: 80), child: const Text('OPEN'))))));
    await t.tap(find.text('OPEN'));
    await settle(t);
    expect(find.text('New level: Pathfinder'), findsOneWidget);
    expect(find.text('120 more trips to Summit Seeker'), findsOneWidget);
    await t.tap(find.byKey(LevelUpSheet.buttonKey));
    await settle(t);
    expect(find.byType(LevelUpSheet), findsNothing);
  });

  test('LevelSeen: first run only records; a higher level is returned once; same or lower level never', () {
    const id = 'level-seen-user';
    StorageService.saveSeenTravelLevel(id, -1);
    expect(LevelSeen.pending('', 3), isNull);
    expect(LevelSeen.pending('fresh-${DateTime.now().microsecondsSinceEpoch}', 4), isNull);
    StorageService.saveSeenTravelLevel(id, 3);
    expect(LevelSeen.pending(id, 3), isNull);
    expect(LevelSeen.pending(id, 4), 4);
    expect(LevelSeen.pending(id, 4), isNull);
    expect(LevelSeen.pending(id, 0), isNull);
    expect(StorageService.getSeenTravelLevel(id), 4);
  });

  testWidgets('LevelUpHost shows the sheet once when /social/me reports a higher level', (t) async {
    StorageService.saveSeenTravelLevel('me', 3);
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson(completedTrips: 80, level: 4)));
    putSeeker();
    final c = Get.put(SocialMeController(), permanent: true);
    await t.runAsync(c.load);
    expect(c.profile!.level, 4);
    await pumpSocial(t, const Scaffold(body: LevelUpHost()));
    expect(find.text('New level: Pathfinder'), findsOneWidget);
    await t.tap(find.byKey(LevelUpSheet.buttonKey));
    await settle(t);
    expect(find.byType(LevelUpSheet), findsNothing);
    await t.runAsync(c.refreshQuiet);
    await settle(t);
    expect(find.byType(LevelUpSheet), findsNothing);
    expect(StorageService.getSeenTravelLevel('me'), 4);
    await drain(t);
  });

  testWidgets('LevelUpHost records but does not show the sheet while the Travel levels page is open', (t) async {
    StorageService.saveSeenTravelLevel('me', 3);
    final server = installServer();
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson(completedTrips: 79, level: 3)));
    putSeeker();
    final c = Get.put(SocialMeController(), permanent: true);
    await t.runAsync(c.load);
    expect(c.profile!.level, 3);
    await pumpSocial(t, const Scaffold(body: LevelUpHost()),
        pages: [GetPage(name: AppRoutes.travelLevels, page: () => const Scaffold(body: SizedBox.shrink()))]);
    expect(find.byType(LevelUpSheet), findsNothing);
    Get.toNamed(AppRoutes.travelLevels);
    await settle(t);
    expect(Get.currentRoute, AppRoutes.travelLevels);
    server.on('GET', '/social/me', socialMeJson(profile: myProfileJson(completedTrips: 80, level: 4)));
    await t.runAsync(c.refreshQuiet);
    expect(c.profile!.level, 4);
    await settle(t);
    expect(find.byType(LevelUpSheet), findsNothing);
    expect(StorageService.getSeenTravelLevel('me'), 4);
    await drain(t);
  });
}
