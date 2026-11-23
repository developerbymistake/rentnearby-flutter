import 'package:flutter/material.dart';

import '../../../design/extra/trip_plan_look.dart';

abstract final class ViewerLook {
  static const String automobileArt = 'assets/images/design/travel3d/automobile.png';
  static const Color ink = Color(0xFF17262A);
  static const Color sub = Color(0xFF4A6572);
  static const Color grey = Color(0xFF767676);
  static const Color greyKey = Color(0xFF6B6B6B);
  static const Color heading = Color(0xFF253840);
  static const Color routeChipBg = Color(0xFFEAF8F6);
  static const Color tealHalo = Color(0x291FA396);
  static const Color redHalo = Color(0x24E0525C);
  static const Color indigoHalo = Color(0x245C5EDD);
  static const Color yesBg = Color(0xFFE8F5E9);
  static const Color yesInk = Color(0xFF17501B);
  static const Color noBg = Color(0xFFFDECEE);
  static const Color noInk = Color(0xFFB83A40);
  static const Color ghostBg = Color(0xFFECEDF2);
  static const Color ghostTitle = Color(0xFF6B6B6B);
  static const Color line = Color(0xFFEEF0F4);
  static const Color chipBg = Color(0xFFEEF0FC);
  static const Color ringTrack = Color(0xFFE6E9F7);
  static const Color barTrack = Color(0xFFE9ECF6);
  static const Color stayFrom = Color(0xFF66BB6A);
  static const Color stayTo = Color(0xFF2E7D32);
  static const Color taxiFrom = Color(0xFFFFC371);
  static const Color taxiTo = Color(0xFFFF8A3D);
  static const Color planFrom = Color(0xFF738AE6);
  static const Color planTo = Color(0xFF5C5EDD);
  static const Color goBg = Color(0xFFFAFAFA);
  static const Color expenseTile = Color(0xFFFFF0F5);
  static const Color legBorder = Color(0xFFD5D9F5);
  static const Color legBg = Color(0xFFEEF0FC);
  static const Color rail = Color(0xFFB5BBEA);
  static const Color roseText = Color(0xFFB0245A);
  static const Color dayIndigo = Color(0xFF738AE6);
  static const Color dayOrange = Color(0xFFFFC371);
  static const Color dayCyan = Color(0xFF4FC3D9);
  static const Color greyBadgeBg = Color(0xFFECEDF2);
  static const Color greyBadgeInk = Color(0xFF4A4F5C);

  static const List<Color> dayColors = [dayIndigo, dayOrange, dayCyan];

  static Color dayColor(int indexInLeg) => dayColors[(indexInLeg - 1) % dayColors.length];

  // Same route colours as the owner trip map (TripMapScreen._routeColors).
  static const List<Color> routeColors = [TripLook.headerGlow, TripLook.mapRouteDay2, TripLook.dayCyan];

  static Color routeColor(int day) => routeColors[(day - 1) % routeColors.length];

  static const List<BoxShadow> card = [BoxShadow(color: Color(0x383A5160), offset: Offset(1.1, 1.1), blurRadius: 10)];
  static const List<BoxShadow> tealStrip = [BoxShadow(color: Color(0x401FA396), offset: Offset(0, 6), blurRadius: 14)];
  static const List<BoxShadow> roseStrip = [BoxShadow(color: Color(0x40FF5287), offset: Offset(0, 6), blurRadius: 14)];
  static const List<BoxShadow> goShadow = [BoxShadow(color: Color(0x2E000000), offset: Offset(3, 5), blurRadius: 8)];
  static const List<BoxShadow> legShadow = [BoxShadow(color: Color(0x595C5EDD), offset: Offset(1.1, 4), blurRadius: 14)];
  static const List<BoxShadow> dayShadow = [BoxShadow(color: Color(0x403A5160), offset: Offset(1.1, 1.1), blurRadius: 12)];
  static const List<BoxShadow> whiteBtn = [BoxShadow(color: Color(0x33000000), offset: Offset(3, 4), blurRadius: 8)];

  static const LinearGradient tealGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1FA396), Color(0xFF14756B)]);
  static const LinearGradient roseGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF0508A), Color(0xFFB0245A)]);
  static const LinearGradient indigoGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF738AE6), Color(0xFF5C5EDD)]);
  static const LinearGradient tripLine = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF4F5FF), Color(0xFFE6E9FF)]);
  static const Color tripLineBorder = Color(0x2E2633C5);
  static const Color tripLineName = Color(0xFF1E1466);
  static const Color tripLineSub = Color(0xFF5A5F9E);
  static const List<BoxShadow> tripLineShadow = [BoxShadow(color: Color(0x471E1466), offset: Offset(1.1, 6), blurRadius: 16)];
}
