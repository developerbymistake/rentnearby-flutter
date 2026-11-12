import 'package:flutter/material.dart';
import 'design_colors.dart';

class StayBrowseTokens {
  StayBrowseTokens._();

  static const Color sheetHandle = Color(0x66767676);
  static const Color glass = Color(0xE6FFFFFF);
  static const Color glassStrong = Color(0xD9FFFFFF);
  static const Color dotInactive = Color(0x80FFFFFF);
  static const Color dotActive = DesignColors.surface;
  static const Color buttonGlow = Color(0x802633C5);
  static const Color greyShadow = DesignColors.border;
  static const Color greyShadowStrong = DesignColors.borderStrong;

  static const List<BoxShadow> buttonGlowShadow = [
    BoxShadow(color: buttonGlow, offset: Offset(1.1, 4.0), blurRadius: 8.0),
  ];
  static const List<BoxShadow> topBarShadow = [
    BoxShadow(color: greyShadow, offset: Offset(0, -2), blurRadius: 8),
  ];
  static const List<BoxShadow> chipShadow = [
    BoxShadow(color: greyShadow, offset: Offset(0, 2), blurRadius: 8),
  ];
  static const List<BoxShadow> pinShadow = [
    BoxShadow(color: greyShadowStrong, blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: greyShadow, offset: Offset(1.1, 1.1), blurRadius: 10),
  ];
}
