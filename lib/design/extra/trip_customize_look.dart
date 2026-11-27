import 'package:flutter/material.dart';

import '../tokens/design_colors.dart';
import '../tokens/type_tokens.dart';
import '../tokens/card_tokens.dart';

class TripCustomizeLook {
  TripCustomizeLook._();

  static const List<BoxShadow> removeShadow = <BoxShadow>[BoxShadow(color: Color(0x73E0525C), offset: Offset(1.1, 4), blurRadius: 8)];
  static const List<BoxShadow> liftShadow = <BoxShadow>[BoxShadow(color: Color(0x5217262A), offset: Offset(0, 12), blurRadius: 24)];
  static const List<BoxShadow> softPill = <BoxShadow>[BoxShadow(color: DesignColors.brandRoyal45, offset: Offset(1.1, 4), blurRadius: 8)];
  static const List<BoxShadow> dayMenu = <BoxShadow>[BoxShadow(color: Color(0x33000000), offset: Offset(2, 3), blurRadius: 6)];

  static const BorderRadius errorRadius = CardRadius.card;
  static const BorderRadius tripLineRadius = CardRadius.tile;
  static const LinearGradient tripCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFF4F5FF), Color(0xFFE6E9FF)],
  );
  static const Color tripCardBorder = DesignColors.brandNavy18;
  static const List<BoxShadow> tripCardShadow = <BoxShadow>[BoxShadow(color: Color(0x471E1466), offset: Offset(1.1, 6), blurRadius: 16)];
  static const Color tripCardName = Color(0xFF1E1466);
  static const Color tripCardSub = Color(0xFF5A5F9E);
  static const BorderRadius addDayRadius = CardRadius.hero;
  static const BorderRadius addRowRadius = CardRadius.card;
  static const BorderRadius barRadius = BorderRadius.vertical(top: Radius.circular(24));
  static TextStyle get headerTitle => TypeTokens.style(20, FontWeight.w700, color: DesignColors.textInverse, letterSpacing: 0);
  static TextStyle get headerSubtitle => TypeTokens.style(12.5, FontWeight.w400, color: DesignColors.textInverse, letterSpacing: 0);
}
