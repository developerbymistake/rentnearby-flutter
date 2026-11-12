import 'package:flutter/painting.dart';
import 'design_colors.dart';

abstract final class TypeTokens {
  static const String family = 'Roboto';
  static const double floor = 11;
  static const double chipFloor = 11;

  static const Color secondary = DesignColors.textSecondaryHigh;

  static TextStyle style(
    double size,
    FontWeight weight, {
    Color color = DesignColors.textPrimary,
    double? height,
    double? letterSpacing,
    bool chip = false,
  }) =>
      TextStyle(
        fontFamily: family,
        fontSize: size < (chip ? chipFloor : floor) ? (chip ? chipFloor : floor) : size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static const TextStyle caption = TextStyle(
      fontFamily: family,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: secondary);
  static const TextStyle label = TextStyle(
      fontFamily: family,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: DesignColors.textPrimary);
  static const TextStyle body = TextStyle(
      fontFamily: family,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: DesignColors.textPrimary);
  static const TextStyle bodyStrong = TextStyle(
      fontFamily: family,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: DesignColors.textPrimary);
  static const TextStyle title = TextStyle(
      fontFamily: family,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: DesignColors.textPrimary);
  static const TextStyle price = TextStyle(
      fontFamily: family,
      fontSize: 15,
      fontWeight: FontWeight.w800,
      color: DesignColors.primary);
  static const TextStyle hero = TextStyle(
      fontFamily: family,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: DesignColors.textPrimary);
  static const TextStyle chip = TextStyle(
      fontFamily: family,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: DesignColors.textPrimary);

  static const TextStyle onGradientTitle = TextStyle(
      fontFamily: family,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: DesignColors.textInverse);
  static const TextStyle onGradientBody = TextStyle(
      fontFamily: family,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: DesignColors.whiteHigh);
}
