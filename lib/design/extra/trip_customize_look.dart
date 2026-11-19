import 'package:flutter/material.dart';

import '../tokens/design_colors.dart';
import '../tokens/type_tokens.dart';

class TripCustomizeLook {
  TripCustomizeLook._();

  static const List<BoxShadow> removeShadow = <BoxShadow>[BoxShadow(color: Color(0x73E0525C), offset: Offset(1.1, 4), blurRadius: 8)];
  static const List<BoxShadow> liftShadow = <BoxShadow>[BoxShadow(color: Color(0x5217262A), offset: Offset(0, 12), blurRadius: 24)];
  static const List<BoxShadow> softPill = <BoxShadow>[BoxShadow(color: Color(0x735C5EDD), offset: Offset(1.1, 4), blurRadius: 8)];
  static const List<BoxShadow> dayMenu = <BoxShadow>[BoxShadow(color: Color(0x33000000), offset: Offset(2, 3), blurRadius: 6)];

  static const BorderRadius errorRadius = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(28),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );
  static const BorderRadius tripLineRadius = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(32),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );
  static const BorderRadius addDayRadius = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(40),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );
  static const BorderRadius barRadius = BorderRadius.vertical(top: Radius.circular(24));
  static TextStyle get headerTitle => TypeTokens.style(20, FontWeight.w700, color: DesignColors.textInverse, letterSpacing: 0);
  static TextStyle get headerSubtitle => TypeTokens.style(12.5, FontWeight.w400, color: DesignColors.textInverse, letterSpacing: 0);
}
