import 'dart:io';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:bakhli/features/social/shared/travel_levels.dart';
import 'package:bakhli/utils/notification_visuals.dart';
import 'package:flutter_test/flutter_test.dart';

import 'social_test_support.dart';

void main() {
  test('the table is the decided one (index, min, max, name, asset)', () {
    const want = [
      (0, 0, 0, 'New Traveller', ListingArt.trophyLevel0),
      (1, 1, 9, 'Trail Starter', ListingArt.trophyLevel1),
      (2, 10, 29, 'Wanderer', ListingArt.trophyLevel2),
      (3, 30, 79, 'Trekker', ListingArt.trophyLevel3),
      (4, 80, 199, 'Pathfinder', ListingArt.trophyLevel4),
      (5, 200, 499, 'Summit Seeker', ListingArt.trophyLevel5),
      (6, 500, null, 'Travel King', ListingArt.trophyLevel6),
    ];
    expect(TravelLevels.all, hasLength(7));
    for (final (i, min, max, name, asset) in want) {
      final l = TravelLevels.all[i];
      expect((l.index, l.min, l.max, l.name, l.asset), (i, min, max, name, asset));
      expect(File(l.asset).existsSync(), isTrue, reason: l.asset);
    }
  });

  test('tile tints and text colours come from LevelColors', () {
    expect([for (final l in TravelLevels.all) l.tint],
        [LevelColors.tint0, LevelColors.tint1, LevelColors.tint2, LevelColors.tint3, LevelColors.tint4, LevelColors.tint5, LevelColors.tint6]);
    expect([for (final l in TravelLevels.all) l.ink],
        [LevelColors.ink0, LevelColors.ink1, LevelColors.ink2, LevelColors.ink3, LevelColors.ink4, LevelColors.ink5, LevelColors.ink6]);
    expect([for (final l in TravelLevels.all) l.isKing], [false, false, false, false, false, false, true]);
  });

  test('levelFor at every boundary', () {
    const cases = {0: 0, 1: 1, 9: 1, 10: 2, 29: 2, 30: 3, 79: 3, 80: 4, 199: 4, 200: 5, 499: 5, 500: 6, 10000: 6, -3: 0};
    cases.forEach((trips, level) => expect(TravelLevels.levelFor(trips), level, reason: '$trips trips'));
  });

  test('next level, trips to next and progress', () {
    expect(TravelLevels.next(4)!.name, 'Summit Seeker');
    expect(TravelLevels.next(6), isNull);
    expect(TravelLevels.tripsToNext(124, 4), 76);
    expect(TravelLevels.tripsToNext(80, 4), 120);
    expect(TravelLevels.tripsToNext(0, 0), 1);
    expect(TravelLevels.tripsToNext(600, 6), 0);
    expect(TravelLevels.progress(124, 4), closeTo(0.3667, 0.001));
    expect(TravelLevels.progress(80, 4), 0);
    expect(TravelLevels.progress(0, 0), 0);
    expect(TravelLevels.progress(9, 1), closeTo(8 / 9, 0.001));
    expect(TravelLevels.progress(900, 6), 1);
    expect(TravelLevels.at(99).index, 6);
    expect(TravelLevels.at(-1).index, 0);
  });

  test('range and count strings', () {
    expect(TravelLevels.at(0).range, 'Level 0 · 0 trips');
    expect(TravelLevels.at(1).range, 'Level 1 · 1 to 9 trips');
    expect(TravelLevels.at(6).range, 'Level 6 · 500+ trips');
    expect(SocialStrings.tripsCount(1), '1 trip');
    expect(SocialStrings.tripsDone(124), '124 trips done');
    expect(SocialStrings.moreTripsTo(76, 'Summit Seeker'), '76 more trips to Summit Seeker');
    expect(SocialStrings.moreTrips(1), '1 more trip');
  });

  test('parseLevel: server level wins and is clamped; missing level comes from the count', () {
    expect(TravelLevels.parseLevel(3, 0), 3);
    expect(TravelLevels.parseLevel(9, 0), 6);
    expect(TravelLevels.parseLevel(null, 124), 4);
    expect(TravelLevels.parseLevel(null, 0), 0);
  });

  test('models read completedTrips and level; an older answer gives 0 / 0', () {
    final me = MyProfile.fromJson({...myProfileJson(completedTrips: 124, level: 4)});
    expect((me.completedTrips, me.level, me.travelLevel.name), (124, 4, 'Pathfinder'));
    expect((me.person.completedTrips, me.person.level), (124, 4));

    final old = Map<String, dynamic>.from(myProfileJson())..remove('completedTrips')..remove('level');
    final o = MyProfile.fromJson(old);
    expect((o.completedTrips, o.level), (0, 0));

    final t = TravellerProfile.fromJson(travellerJson(completedTrips: 46, level: 3));
    expect((t.completedTrips, t.level, t.person.completedTrips, t.person.level), (46, 3, 46, 3));

    final p = SocialPerson.fromJson({'userId': 'x', 'name': 'Asha'});
    expect((p.completedTrips, p.level), (0, 0));

    final derived = SocialPerson.fromJson({'userId': 'x', 'name': 'Asha', 'completedTrips': 30});
    expect(derived.level, 3);

    final trip = PublicTrip.fromJson({
      'tripId': 't',
      'owner': {'userId': 'o', 'name': 'Rahul Verma', 'completedTrips': 124, 'level': 4},
    });
    expect((trip.owner.completedTrips, trip.owner.level), (124, 4));
  });

  test('level-up inbox row shows the trophy of the level named in the copy', () {
    const route = '/travel-levels';
    expect(NotificationVisuals.levelLook('travel_level_up', route, 'New level reached Congratulations, Rahul! You are now a Wanderer with 10 trips completed.')!.art,
        ListingArt.trophyLevel2);
    expect(NotificationVisuals.levelLook('TravelLevelUp', route, 'You are the Travel King Congratulations!')!.art, ListingArt.trophyLevel6);
    expect(NotificationVisuals.levelLook('travel_level_up', route, 'Your first trip is done ... reached Trail Starter.')!.art, ListingArt.trophyLevel1);
    expect(NotificationVisuals.levelLook('stay_approved', '/my-stays', 'Wanderer'), isNull);
    expect(NotificationVisuals.listingKind(route, type: 'travel_level_up'), 'LEVEL');
  });

  test('same table as the backend TravelLevels (skipped when the backend repo is not beside the app)', () {
    final f = File('../../Backend/RentNearBy.Core/Models/Social/TravelLevels.cs');
    if (!f.existsSync()) return;
    final rows = RegExp(r'new\((\d+), (\d+), (\d+|null), "([^"]+)"\)').allMatches(f.readAsStringSync()).toList();
    expect(rows, hasLength(TravelLevels.all.length));
    for (final m in rows) {
      final l = TravelLevels.all[int.parse(m.group(1)!)];
      expect((l.min, l.max?.toString() ?? 'null', l.name), (int.parse(m.group(2)!), m.group(3), m.group(4)));
    }
  });
}
