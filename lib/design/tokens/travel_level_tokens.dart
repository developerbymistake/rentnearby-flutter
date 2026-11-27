import 'package:flutter/painting.dart';

import '../extra/art_3d.dart';
import 'design_colors.dart';

// Travel levels (SPEC primary_blue_levels B): one tile tint and one text colour per level, the gold of the profile
// level panel and the Travel King ring. The primary blue is never copied here: widgets read ListingPalette.indigo.
abstract final class LevelColors {
  static const Color tint0 = Color(0xFFD6F1E2);
  static const Color tint1 = Color(0xFFFADFCB);
  static const Color tint2 = Color(0xFFE4DAF7);
  static const Color tint3 = Color(0xFFFFF0DC);
  static const Color tint4 = Color(0xFFE3F3FC);
  static const Color tint5 = Color(0xFFFFF1CC);
  static const Color tint6 = Color(0xFFFFF6D6);

  static const Color ink0 = Color(0xFF1E7A4C);
  static const Color ink1 = Color(0xFFA5501A);
  static const Color ink2 = Color(0xFF5B3FA0);
  static const Color ink3 = Color(0xFF9A5A00);
  static const Color ink4 = Color(0xFF0B6A9A);
  static const Color ink5 = Color(0xFF8A6500);
  static const Color ink6 = Color(0xFF8A6500);

  // Travel King tile ring and its soft glow.
  static const Color kingRing = Color(0xFFF2C94C);

  // Profile level panel: gold round trophy tile, its ring and the LEVEL eyebrow.
  static const Color medalLight = Color(0xFFFFF6DA);
  static const Color medalDeep = Color(0xFFFFE3A0);
  static const Color medalRing = Color(0xFFF5C76A);
  static const Color eyebrow = Color(0xFF8A6A12);

  // Progress: primary blue (from the palette) to this gold on a neutral track.
  static const Color progressGold = Color(0xFFFFB547);
  static const Color track = Color(0xFFE8EAF2);
}

// Profile header stats (white tiles, coloured numbers).
abstract final class ProfileStatColors {
  static const Color trips = Color(0xFFD9730D);
  static const Color followers = DesignColors.tealDeep;
  static const Color following = Color(0xFFD8452B);
  static const Color label = Ink3D.sub;
  // Hard drop shadow under the white tiles and the level panel (deep navy, used with Alpha.v22).
  static const Color tileShadow = Color(0xFF0C1846);
}

// Travel level widget sizes (unscaled logical values, always passed through the DS scale API).
abstract final class LevelSizes {
  static const double tile = 50;
  static const double badge = 24;
  static const double medal = 62;
  static const double medalArt = 46;
  static const double markArt = 48;
  static const double hero = 104;
  static const double heroArt = 74;
  static const double nextArt = 22;
  static const double arrow = 30;
  static const double arrowIcon = 20;
  static const double tickIcon = 16;
  static const double bar = 10;
  static const double sheetBar = 8;
  static const double rowMinHeight = 76;
  static const double rowAccent = 4;
  static const double kingRing = 2.5;
  static const double medalBorder = 3;
  static const double medalRing = 2;
  static const double skeleton = 200;
  // Trophy art against its tile: round badge art, square tile art (overhangs) and the overhang above the tile.
  static const double roundArtRatio = 0.78;
  static const double tileArtRatio = 1.08;
  static const double tileArtLift = 0.14;
  // Small 3D art drop shadow (same preset as the other small Art3D icons of the app).
  static const double artShadowBlur = 3;
  static const Offset artShadowOffset = Offset(2, 4);
  static const double kingGlowBlur = 10;
  static const double kingGlowSpread = 1;
  static const double rowLine = 1;
  static const Alignment medalLightCentre = Alignment(0, -0.3);
  // Hard drop shadow offsets: the level panel and the profile stat tiles.
  static const Offset panelShadowOffset = Offset(0, 4);
  static const Offset statShadowOffset = Offset(0, 3);
}
