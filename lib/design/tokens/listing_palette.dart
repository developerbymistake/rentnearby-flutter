import 'package:flutter/material.dart';

import '../extra/kit_tone.dart';

class ListingPalette {
  const ListingPalette({
    required this.g1,
    required this.g2,
    required this.text,
    required this.page,
    required this.tint,
    required this.line,
    required this.shadow,
    required this.button,
  });

  final Color g1;
  final Color g2;
  final Color text;
  final Color page;
  final Color tint;
  final Color line;
  final Color shadow;
  final Color button;

  LinearGradient get gradient => LinearGradient(colors: [g1, g2], begin: Alignment.topLeft, end: Alignment.bottomRight);

  KitTone get tone => KitTone(accent: g1, accentDark: text, tint: tint, gradient: gradient, glow: g2);

  static const double haloAlpha = 0.16;
  static const double shadowAlpha = 0.55;

  Color get haloColor => shadow.withValues(alpha: haloAlpha);
  Color get glowShadow => shadow.withValues(alpha: shadowAlpha);

  static const ListingPalette indigo = ListingPalette(
    g1: Color(0xFF738AE6),
    g2: Color(0xFF5C5EDD),
    text: Color(0xFF2633C5),
    page: Color(0xFFF2F3F8),
    tint: Color(0xFFEEF0FC),
    line: Color(0xFFD5D9F5),
    shadow: Color(0xFF5C5EDD),
    button: Color(0xFFDADDF7),
  );

  static const ListingPalette forest = ListingPalette(
    g1: Color(0xFF66BB6A),
    g2: Color(0xFF2E7D32),
    text: Color(0xFF17501B),
    page: Color(0xFFD8EEDA),
    tint: Color(0xFFEDF8EE),
    line: Color(0xFFBFE0C2),
    shadow: Color(0xFF2E7D32),
    button: Color(0xFFC4E2C6),
  );

  static const ListingPalette teal = ListingPalette(
    g1: Color(0xFF54D3C2),
    g2: Color(0xFF1FA396),
    text: Color(0xFF1FA396),
    page: Color(0xFFE0F5F2),
    tint: Color(0xFFEAF8F6),
    line: Color(0xFFBFE8E2),
    shadow: Color(0xFF1FA396),
    button: Color(0xFF1FA396),
  );

  static const ListingPalette coral = ListingPalette(
    g1: Color(0xFFFA7D82),
    g2: Color(0xFFE0525C),
    text: Color(0xFFB83A40),
    page: Color(0xFFFFE3DA),
    tint: Color(0xFFFFF1EC),
    line: Color(0xFFF8C8BB),
    shadow: Color(0xFFFA7D82),
    button: Color(0xFFF6CDC1),
  );
}

class MealsGradient {
  const MealsGradient({required this.g1, required this.g2, required this.shadow, required this.shadowAlpha, this.buttonColor});

  final Color g1;
  final Color g2;
  final Color shadow;
  final double shadowAlpha;
  final Color? buttonColor;

  LinearGradient get gradient => LinearGradient(colors: [g1, g2], begin: Alignment.topLeft, end: Alignment.bottomRight);
  Color get shadowColor => shadow.withValues(alpha: shadowAlpha);
  Color get button => buttonColor ?? g2;

  static const double haloAlpha = 0.16;

  static const MealsGradient cA = MealsGradient(g1: Color(0xFFFA7D82), g2: Color(0xFFFFB295), shadow: Color(0xFFFFB295), shadowAlpha: 0.6, buttonColor: Color(0xFFFA7D82));
  static const MealsGradient cB = MealsGradient(g1: Color(0xFF738AE6), g2: Color(0xFF5C5EDD), shadow: Color(0xFF5C5EDD), shadowAlpha: 0.6);
  static const MealsGradient cC = MealsGradient(g1: Color(0xFFFE95B6), g2: Color(0xFFFF5287), shadow: Color(0xFFFF5287), shadowAlpha: 0.6);
  static const MealsGradient cD = MealsGradient(g1: Color(0xFF6F72CA), g2: Color(0xFF1E1466), shadow: Color(0xFF1E1466), shadowAlpha: 0.6);
  static const MealsGradient cE = MealsGradient(g1: Color(0xFF66BB6A), g2: Color(0xFF2E7D32), shadow: Color(0xFF2E7D32), shadowAlpha: 0.55);
  static const MealsGradient cF = MealsGradient(g1: Color(0xFFFFC371), g2: Color(0xFFFF8A3D), shadow: Color(0xFFF57C00), shadowAlpha: 0.5, buttonColor: Color(0xFFF57C00));

  static const List<MealsGradient> all = [cA, cB, cC, cD, cE, cF];

  static MealsGradient at(int i) => all[i % all.length];
}

abstract final class ListingArt {
  static const String _dir = 'assets/images/design/travel3d/';

  static const String taxi = '${_dir}taxi.png';
  static const String bus = '${_dir}bus.png';
  static const String hotel = '${_dir}hotel.png';
  static const String bed = '${_dir}bed.png';
  static const String key = '${_dir}key.png';
  static const String luggage = '${_dir}luggage.png';
  static const String compass = '${_dir}compass.png';
  static const String backpack = '${_dir}backpack.png';
  static const String airplane = '${_dir}airplane.png';
  static const String mountain = '${_dir}mountain.png';
  static const String camping = '${_dir}camping.png';
  static const String tent = '${_dir}tent.png';
  static const String beach = '${_dir}beach_with_umbrella.png';
  static const String worldMap = '${_dir}world_map.png';
  static const String roundPushpin = '${_dir}round_pushpin.png';
  static const String star = '${_dir}star.png';
  static const String moneyBag = '${_dir}money_bag.png';
  static const String speechBalloon = '${_dir}speech_balloon.png';
  static const String clipboard = '${_dir}clipboard.png';
  static const String pushpin = '${_dir}pushpin.png';
  static const String calendar = '${_dir}calendar.png';
  static const String camera = '${_dir}camera.png';
  static const String sunrise = '${_dir}sunrise.png';
  static const String bell = 'assets/images/design/fitness_app/bell.png';

  static String forVehicle(String? name) {
    final v = (name ?? '').toLowerCase();
    if (v.contains('bus') || v.contains('tempo') || v.contains('traveller') || v.contains('traveler')) return bus;
    return taxi;
  }
}
