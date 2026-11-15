import 'package:flutter/painting.dart';
import 'design_colors.dart';
import 'design_scale.dart';

abstract final class TypeTokens {
  static const String family = 'Poppins';
  static const List<String> fallback = ['WorkSans'];
  static double get floor => DS.fontFloor;
  static double get chipFloor => DS.fontFloor;

  static const Color secondary = DesignColors.textSecondaryHigh;

  static double _size(double size, bool chip, bool scaled) {
    final v = scaled ? size * DS.font : size;
    final fl = chip ? chipFloor : floor;
    return v < fl ? fl : v;
  }

  static TextStyle _fixed(double size, FontWeight weight, Color color) => TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: DS.f(size),
      fontWeight: weight,
      color: color);

  static TextStyle style(
    double size,
    FontWeight weight, {
    Color color = DesignColors.textPrimary,
    double? height,
    double? letterSpacing,
    bool chip = false,
    bool scaled = true,
  }) =>
      TextStyle(
        fontFamily: family,
      fontFamilyFallback: fallback,
        fontSize: _size(size, chip, scaled),
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle get caption => _fixed(11, FontWeight.w500, secondary);
  static TextStyle get label => _fixed(12, FontWeight.w600, DesignColors.textPrimary);
  static TextStyle get body => _fixed(14, FontWeight.w400, DesignColors.textPrimary);
  static TextStyle get bodyStrong => _fixed(14, FontWeight.w600, DesignColors.textPrimary);
  static TextStyle get title => _fixed(16, FontWeight.w700, DesignColors.textPrimary);
  static TextStyle get price => _fixed(15, FontWeight.w700, DesignColors.primary);
  static TextStyle get priceBig => _fixed(22, FontWeight.w700, DesignColors.primary);
  static TextStyle get hero => _fixed(22, FontWeight.w700, DesignColors.textPrimary);
  static TextStyle get chip => _fixed(11, FontWeight.w700, DesignColors.textPrimary);

  static TextStyle get onGradientTitle => _fixed(16, FontWeight.w700, DesignColors.textInverse);
  static TextStyle get onGradientBody => _fixed(12, FontWeight.w600, DesignColors.whiteHigh);
}
