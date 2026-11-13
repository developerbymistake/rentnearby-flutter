import 'package:bakhli/design/tokens/template_tokens.dart';
import 'package:flutter/material.dart';

class FitnessAppTheme {
  FitnessAppTheme._();
  static const Color nearlyWhite = TemplateTokens.fitnessNearlyWhite;
  static const Color white = TemplateTokens.white;
  static const Color background = TemplateTokens.fitnessBackground;
  static const Color nearlyDarkBlue = TemplateTokens.nearlyDarkBlue;

  static const Color nearlyBlue = TemplateTokens.nearlyBlue;
  static const Color nearlyBlack = TemplateTokens.nearlyBlack;
  static const Color grey = TemplateTokens.slateGrey;
  static const Color dark_grey = TemplateTokens.darkGrey;

  static const Color darkText = TemplateTokens.darkText;
  static const Color darkerText = TemplateTokens.darkerText;
  static const Color lightText = TemplateTokens.lightText;
  static const Color deactivatedText = TemplateTokens.deactivatedText;
  static const Color dismissibleBackground = TemplateTokens.dismissibleBackground;
  static const Color spacer = TemplateTokens.spacer;
  static const String fontName = 'Poppins';
  static const List<String> fontFallback = ['WorkSans'];

  static const TextTheme textTheme = TextTheme(
    headlineMedium: display1,
    headlineSmall: headline,
    titleLarge: title,
    titleSmall: subtitle,
    bodyMedium: body2,
    bodyLarge: body1,
    bodySmall: caption,
  );

  static const TextStyle display1 = TextStyle(
    fontFamily: fontName,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.bold,
    fontSize: 36,
    letterSpacing: 0.4,
    height: 0.9,
    color: darkerText,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: fontName,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.bold,
    fontSize: 24,
    letterSpacing: 0.27,
    color: darkerText,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontName,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.bold,
    fontSize: 16,
    letterSpacing: 0.18,
    color: darkerText,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: fontName,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    letterSpacing: -0.04,
    color: darkText,
  );

  static const TextStyle body2 = TextStyle(
    fontFamily: fontName,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    letterSpacing: 0.2,
    color: darkText,
  );

  static const TextStyle body1 = TextStyle(
    fontFamily: fontName,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    letterSpacing: -0.05,
    color: darkText,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontName,
    fontFamilyFallback: fontFallback,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    letterSpacing: 0.2,
    color: lightText, // was lightText
  );
}
