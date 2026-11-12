import 'package:flutter/material.dart';
import '../template/fitness_app_theme.dart';
import '../tokens/design_colors.dart';
import 'travel_icon.dart';
import 'travel_palette.dart';

class TripSpotLook {
  TripSpotLook._();

  static const String _dir = 'assets/images/design/travel3d/';

  static LinearGradient gradientOf(String category) {
    final pair = switch (category) {
      'temple' || 'fort' || 'palace' || 'museum' || 'historic' || 'cave' || 'bridge' => [TravelPalette.sunriseStart, TravelPalette.sunriseEnd],
      'lake' || 'waterfall' || 'ghat' || 'beach' => [TravelPalette.skyStart, TravelPalette.skyEnd],
      'viewpoint' || 'park' || 'garden' || 'zoo' || 'wildlife' => [FitnessAppTheme.nearlyBlue, FitnessAppTheme.nearlyDarkBlue],
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
        'temple' || 'fort' || 'palace' || 'museum' || 'historic' || 'cave' || 'bridge' => TravelIcon.star,
        'lake' || 'waterfall' || 'ghat' || 'beach' => '${_dir}beach_with_umbrella.png',
        'viewpoint' => '${_dir}sunrise.png',
        'park' || 'garden' || 'zoo' || 'wildlife' => '${_dir}camping.png',
        _ => TravelIcon.place,
      };
}
