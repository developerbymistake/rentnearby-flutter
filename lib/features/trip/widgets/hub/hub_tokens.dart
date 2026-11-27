import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

abstract final class HubTokens {
  static const Color ink = Color(0xFF17262A);
  static const Color sub = Color(0xFF4A6572);
  static const Color grey = Color(0xFF767676);
  static const Color accent = DesignColors.brandRoyal;
  static const Color gradientStart = DesignColors.brandNavy;
  static const Color blue = DesignColors.brandNavy;
  static const Color heading = DesignColors.brandNavy;
  static const Color headingSub = DesignColors.brandNavy;
  static const Color trackRing = Color(0xFFE6E9F7);
  static const Color trackBar = Color(0xFFE9ECF6);
  static const Color chipBg = DesignColors.brandTint;
  static const Color line = Color(0xFFEEF0F4);
  static const Color dotOff = DesignColors.brandRing;
  static const Color statusStrip = DesignColors.brandTint;
  static const Color deviceShadowFar = Color(0x611E286E);
  static const Color deviceShadowNear = Color(0x61374196);

  static const List<BoxShadow> _cardShadow = [
    BoxShadow(color: Color(0x303A5160), offset: Offset(1.1, 1.6), blurRadius: 12),
  ];

  static List<BoxShadow> get cardShadow => DS.shadows(_cardShadow);

  static BorderRadius cardRadius(double corner) => DS.br(corner >= 36 ? CardRadius.hero : corner >= 26 ? CardRadius.tile : CardRadius.card);

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      DesignColors.brandTint,
      DesignColors.brandTint,
      DesignColors.brandButton,
      DesignColors.brandLine,
      DesignColors.brandButton,
      DesignColors.brandTint,
      DesignColors.scaffold,
    ],
    stops: [0.0, 0.22, 0.40, 0.56, 0.74, 0.90, 1.0],
  );
}
