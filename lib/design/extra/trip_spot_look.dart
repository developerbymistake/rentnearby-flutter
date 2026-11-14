import 'package:flutter/material.dart';
import '../template/fitness_app_theme.dart';
import '../tokens/design_colors.dart';
import '../tokens/listing_palette.dart';
import 'travel_palette.dart';

class TripSpotLook {
  TripSpotLook._();

  static LinearGradient gradientOf(String category) {
    final pair = switch (category) {
      'temple' || 'fort' || 'palace' || 'museum' || 'historic' || 'cave' || 'bridge' => [TravelPalette.sunriseStart, TravelPalette.sunriseEnd],
      'lake' || 'waterfall' || 'ghat' || 'beach' => [TravelPalette.skyStart, TravelPalette.skyEnd],
      'viewpoint' || 'park' || 'garden' || 'zoo' || 'wildlife' => [FitnessAppTheme.nearlyBlue, FitnessAppTheme.nearlyDarkBlue],
      'attraction' => [ListingPalette.teal.g1, ListingPalette.teal.g2],
      _ => [TravelPalette.roseStart, TravelPalette.roseEnd],
    };
    return LinearGradient(colors: pair, begin: Alignment.topLeft, end: Alignment.bottomRight);
  }

  static const List<List<Color>> _pairs = [
    [TravelPalette.sunriseStart, TravelPalette.sunriseEnd],
    [TravelPalette.skyStart, TravelPalette.skyEnd],
    [TravelPalette.roseStart, TravelPalette.roseEnd],
    [TravelPalette.duskStart, TravelPalette.duskEnd],
    [DesignColors.hotelStart, DesignColors.hotelEnd],
    [DesignColors.ringLight, DesignColors.primary],
    [DesignColors.accentTeal, DesignColors.skyDeepStart],
    [DesignColors.breakfastEnd, DesignColors.snackEnd],
  ];

  static LinearGradient hashedGradient(String key) {
    var h = 0;
    for (final u in key.toLowerCase().codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    final pair = _pairs[h % _pairs.length];
    return LinearGradient(colors: pair, begin: Alignment.topLeft, end: Alignment.bottomRight);
  }

  static String assetOf(String category) => switch (category) {
        'temple' => ListingArt.hinduTemple,
        'viewpoint' => ListingArt.sunriseMountains,
        'lake' => ListingArt.canoe,
        'attraction' => ListingArt.ferrisWheel,
        'historic' => ListingArt.classicalBuilding,
        'wildlife' => ListingArt.tiger,
        'waterfall' => ListingArt.droplet,
        'cave' => ListingArt.rock,
        'museum' => ListingArt.framedPicture,
        'zoo' => ListingArt.lion,
        'bridge' => ListingArt.bridge,
        'beach' => ListingArt.beach,
        'fort' => ListingArt.castle,
        'palace' => ListingArt.crown,
        'ghat' => ListingArt.diyaLamp,
        'park' => ListingArt.tree,
        'garden' => ListingArt.tulip,
        _ => ListingArt.roundPushpin,
      };
}
