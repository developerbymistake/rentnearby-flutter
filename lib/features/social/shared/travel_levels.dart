import 'dart:ui';

import '../../../design/tokens/listing_palette.dart';
import '../../../design/tokens/travel_level_tokens.dart';
import 'social_strings.dart';

class TravelLevel {
  const TravelLevel({required this.index, required this.min, this.max, required this.name, required this.asset, required this.tint, required this.ink});

  final int index;
  final int min;
  final int? max;
  final String name;
  final String asset;
  final Color tint;
  final Color ink;

  bool get isKing => index == TravelLevels.king;

  String get range => SocialStrings.levelRange(index, min, max);
}

// Same table as the backend TravelLevels (Core); the level is computed from Users.CompletedTripsCount, never stored.
abstract final class TravelLevels {
  static const int king = 6;

  static const List<TravelLevel> all = [
    TravelLevel(index: 0, min: 0, max: 0, name: SocialStrings.levelNewTraveller, asset: ListingArt.trophyLevel0, tint: LevelColors.tint0, ink: LevelColors.ink0),
    TravelLevel(index: 1, min: 1, max: 9, name: SocialStrings.levelTrailStarter, asset: ListingArt.trophyLevel1, tint: LevelColors.tint1, ink: LevelColors.ink1),
    TravelLevel(index: 2, min: 10, max: 29, name: SocialStrings.levelWanderer, asset: ListingArt.trophyLevel2, tint: LevelColors.tint2, ink: LevelColors.ink2),
    TravelLevel(index: 3, min: 30, max: 79, name: SocialStrings.levelTrekker, asset: ListingArt.trophyLevel3, tint: LevelColors.tint3, ink: LevelColors.ink3),
    TravelLevel(index: 4, min: 80, max: 199, name: SocialStrings.levelPathfinder, asset: ListingArt.trophyLevel4, tint: LevelColors.tint4, ink: LevelColors.ink4),
    TravelLevel(index: 5, min: 200, max: 499, name: SocialStrings.levelSummitSeeker, asset: ListingArt.trophyLevel5, tint: LevelColors.tint5, ink: LevelColors.ink5),
    TravelLevel(index: 6, min: 500, name: SocialStrings.levelTravelKing, asset: ListingArt.trophyLevel6, tint: LevelColors.tint6, ink: LevelColors.ink6),
  ];

  static TravelLevel at(int index) => all[index.clamp(0, king)];

  static int levelFor(int trips) {
    for (var i = king; i > 0; i--) {
      if (trips >= all[i].min) return i;
    }
    return 0;
  }

  static TravelLevel forTrips(int trips) => all[levelFor(trips)];

  static TravelLevel? next(int index) => index >= king ? null : all[index.clamp(0, king) + 1];

  static int tripsToNext(int trips, int index) {
    final n = next(index);
    if (n == null) return 0;
    final left = n.min - trips;
    return left < 0 ? 0 : left;
  }

  static double progress(int trips, int index) {
    final here = at(index);
    final n = next(index);
    if (n == null) return 1;
    final span = n.min - here.min;
    if (span <= 0) return 0;
    return ((trips - here.min) / span).clamp(0.0, 1.0).toDouble();
  }

  // Server level when the field is there; else computed from the count (an older answer gives 0 / 0).
  static int parseLevel(Object? level, int trips) => level is num ? level.toInt().clamp(0, king) : levelFor(trips);
}
