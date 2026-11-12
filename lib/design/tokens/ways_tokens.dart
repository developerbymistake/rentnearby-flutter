import 'package:flutter/material.dart';
import 'design_colors.dart';

class WaysTokens {
  WaysTokens._();

  static const Color changeAccent = DesignColors.statusAttention;
  static const Color changeAccentSoft = Color(0xFFFFB295);
  static const Color confirmStart = Color(0xFFFE95B6);
  static const Color confirmEnd = Color(0xFFFF5287);
  static const Color legSky = Color(0xFF5C5EDD);
  static const Color legDusk = Color(0xFF6F72CA);
  static const Color presenceDot = confirmEnd;
  static const List<Color> legColors = [DesignColors.primaryLight, legSky, legDusk];
}
