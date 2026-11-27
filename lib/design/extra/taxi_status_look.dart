import '../tokens/card_tokens.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/design/tokens/design_colors.dart';

class TaxiStatusLook {
  TaxiStatusLook._();

  static const Color goodSoft = Color(0xFFE8F5E9);
  static const Color goodLine = Color(0xFFCFEBD2);
  static const Color holdFill = Color(0xFFE3E5EC);
  static const Color holdText = Color(0xFF4A4F5C);
  static const Color dimCard = Color(0xFFECEDF2);
  static const Color star = Color(0xFFF5B301);
  static const Color warnFill = Color(0xFFFFF4E0);
  static const Color warnText = Color(0xFF8A5200);
  static const Color dayDotOn = DesignColors.brandSky;
  static const Color dayDotOff = DesignColors.brandRing;

  static const List<BoxShadow> chipShadow = <BoxShadow>[BoxShadow(color: Color(0x29000000), offset: Offset(0, 2), blurRadius: 8)];
  static const List<BoxShadow> redPill = <BoxShadow>[BoxShadow(color: Color(0x73E0525C), offset: Offset(1.1, 8), blurRadius: 12)];
  static const List<BoxShadow> greenPill = <BoxShadow>[BoxShadow(color: Color(0x732E7D32), offset: Offset(1.1, 8), blurRadius: 12)];
  static const List<BoxShadow> actionGlow = <BoxShadow>[BoxShadow(color: DesignColors.brandRoyal40, offset: Offset(1.1, 6), blurRadius: 10)];
  static const List<BoxShadow> sheetShadow = <BoxShadow>[BoxShadow(color: Color(0x4D9E9E9E), offset: Offset(0, -2), blurRadius: 16)];

  static const BorderRadius chipRadius = CardRadius.card;
  static const BorderRadius bannerRadius = CardRadius.card;
  static const BorderRadius sheetRadius = BorderRadius.vertical(top: Radius.circular(32));
}
