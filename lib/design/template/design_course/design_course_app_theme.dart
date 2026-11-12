import 'package:bakhli/design/tokens/template_tokens.dart';
import 'package:flutter/material.dart';

class DesignCourseAppTheme {
  DesignCourseAppTheme._();

  static const Color notWhite = TemplateTokens.courseNotWhite;
  static const Color nearlyWhite = TemplateTokens.white;
  static const Color nearlyBlue = TemplateTokens.nearlyBlue;
  static const Color nearlyBlack = TemplateTokens.nearlyBlack;
  static const Color grey = TemplateTokens.slateGrey;
  static const Color dark_grey = TemplateTokens.darkGrey;

  static const Color darkText = TemplateTokens.darkText;
  static const Color darkerText = TemplateTokens.darkerText;
  static const Color lightText = TemplateTokens.lightText;
  static const Color deactivatedText = TemplateTokens.deactivatedText;
  static const Color dismissibleBackground = TemplateTokens.dismissibleBackground;
  static const Color chipBackground = TemplateTokens.courseChipBackground;
  static const Color spacer = TemplateTokens.spacer;

  static const TextTheme textTheme = TextTheme(
    headlineMedium: display1,
    headlineSmall: headline,
    titleLarge: title,
    titleSmall: subtitle,
    bodyLarge: body2,
    bodyMedium: body1,
    bodySmall: caption,
  );

  static const TextStyle display1 = TextStyle(
    // h4 -> display1
    fontFamily: 'WorkSans',
    fontWeight: FontWeight.bold,
    fontSize: 36,
    letterSpacing: 0.4,
    height: 0.9,
    color: darkerText,
  );

  static const TextStyle headline = TextStyle(
    // h5 -> headline
    fontFamily: 'WorkSans',
    fontWeight: FontWeight.bold,
    fontSize: 24,
    letterSpacing: 0.27,
    color: darkerText,
  );

  static const TextStyle title = TextStyle(
    // h6 -> title
    fontFamily: 'WorkSans',
    fontWeight: FontWeight.bold,
    fontSize: 16,
    letterSpacing: 0.18,
    color: darkerText,
  );

  static const TextStyle subtitle = TextStyle(
    // subtitle2 -> subtitle
    fontFamily: 'WorkSans',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    letterSpacing: -0.04,
    color: darkText,
  );

  static const TextStyle body2 = TextStyle(
    // body1 -> body2
    fontFamily: 'WorkSans',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    letterSpacing: 0.2,
    color: darkText,
  );

  static const TextStyle body1 = TextStyle(
    // body2 -> body1
    fontFamily: 'WorkSans',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    letterSpacing: -0.05,
    color: darkText,
  );

  static const TextStyle caption = TextStyle(
    // Caption -> caption
    fontFamily: 'WorkSans',
    fontWeight: FontWeight.w400,
    fontSize: 12,
    letterSpacing: 0.2,
    color: lightText, // was lightText
  );
}
