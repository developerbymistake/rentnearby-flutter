import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Single source of truth for the app-wide UI scale (identity = 1.0 until [applyApproved]).
abstract final class DS {
  /// Approved size factor (height, width, art, icon, radius, shadow, inner padding).
  static const double approvedSize = 0.80;

  /// Approved font factor (keep <= size so text never clips).
  static const double approvedFont = 0.80;

  /// Approved gap factor relative to size (effective gap = size * gapRel).
  static const double approvedGapRel = 0.90;

  /// Font floor at approved values.
  static const double approvedFontFloor = 9;

  /// Font floor at identity (the legacy TypeTokens floor, so identity is pixel-identical).
  static const double identityFontFloor = 11;

  static double size = 1.0;
  static double font = 1.0;
  static double gapRel = 1.0;

  /// Minimum rendered font size used by TypeTokens.style and DS.f when scaling is active.
  static double fontFloor = identityFontFloor;

  /// Flips the app to the approved values (call once, from one place, before runApp).
  static void applyApproved() {
    size = approvedSize;
    font = approvedFont;
    gapRel = approvedGapRel;
    fontFloor = approvedFontFloor;
  }

  /// Test-only: pin the scale values.
  @visibleForTesting
  static void debugSet({double? size, double? font, double? gapRel, double? fontFloor}) {
    if (size != null) DS.size = size;
    if (font != null) DS.font = font;
    if (gapRel != null) DS.gapRel = gapRel;
    if (fontFloor != null) DS.fontFloor = fontFloor;
  }

  /// Test-only: back to identity.
  @visibleForTesting
  static void debugReset() {
    size = 1.0;
    font = 1.0;
    gapRel = 1.0;
    fontFloor = identityFontFloor;
  }

  /// Effective vertical gap factor.
  static double get gapV => size * gapRel;

  /// Effective horizontal gap factor.
  static double get gapH => size * gapRel;

  /// Size scale: height, width, icon, art, padding inside a widget, line spacing inside a card.
  static double s(double n, {bool scaled = true}) => scaled ? n * size : n;

  /// Font scale with floor; returns n untouched at font == 1.0.
  static double f(double n, {bool scaled = true}) {
    if (!scaled || font == 1.0) return n;
    return math.max(n * font, fontFloor);
  }

  /// Vertical gap between sibling widgets.
  static double gv(double n, {bool scaled = true}) => scaled ? n * gapV : n;

  /// Horizontal gap between sibling widgets.
  static double gh(double n, {bool scaled = true}) => scaled ? n * gapH : n;

  /// Corner radius (follows size).
  static double radius(double n, {bool scaled = true}) => s(n, scaled: scaled);

  /// Circular BorderRadius with a scaled radius.
  static BorderRadius circular(double n, {bool scaled = true}) => BorderRadius.circular(radius(n, scaled: scaled));

  /// Scales every corner of an existing BorderRadius (use for the const CardRadius.* values).
  static BorderRadius br(BorderRadius r, {bool scaled = true}) {
    if (!scaled || size == 1.0) return r;
    Radius k(Radius x) => Radius.elliptical(x.x * size, x.y * size);
    return BorderRadius.only(topLeft: k(r.topLeft), topRight: k(r.topRight), bottomLeft: k(r.bottomLeft), bottomRight: k(r.bottomRight));
  }

  /// Scaled shadow blur.
  static double shadowBlur(double n, {bool scaled = true}) => s(n, scaled: scaled);

  /// Scaled shadow offset.
  static Offset shadowOffset(Offset o, {bool scaled = true}) => scaled ? o * size : o;

  /// Scales offset, blur and spread of a shadow list (color untouched).
  static List<BoxShadow> shadows(List<BoxShadow> list, {bool scaled = true}) {
    if (!scaled || size == 1.0) return list;
    return [
      for (final b in list)
        BoxShadow(color: b.color, offset: b.offset * size, blurRadius: b.blurRadius * size, spreadRadius: b.spreadRadius * size, blurStyle: b.blurStyle),
    ];
  }

  /// All-sides inside padding (size).
  static EdgeInsets all(double n, {bool scaled = true}) => EdgeInsets.all(s(n, scaled: scaled));

  /// Inside padding, every side follows size (use for padding inside one widget's own box).
  static EdgeInsets insets({double l = 0, double t = 0, double r = 0, double b = 0, bool scaled = true}) =>
      EdgeInsets.fromLTRB(s(l, scaled: scaled), s(t, scaled: scaled), s(r, scaled: scaled), s(b, scaled: scaled));

  /// Symmetric inside padding (size).
  static EdgeInsets sym({double h = 0, double v = 0, bool scaled = true}) =>
      EdgeInsets.symmetric(horizontal: s(h, scaled: scaled), vertical: s(v, scaled: scaled));

  /// Padding where top/bottom are vertical gaps and left/right follow size (a gap-padded section).
  static EdgeInsets gapInsets({double l = 0, double t = 0, double r = 0, double b = 0, bool scaled = true}) =>
      EdgeInsets.fromLTRB(s(l, scaled: scaled), gv(t, scaled: scaled), s(r, scaled: scaled), gv(b, scaled: scaled));
}

/// Gap spacers between sibling widgets.
abstract final class Gap {
  /// Vertical gap between stacked widgets: SizedBox(height: DS.gv(n)).
  static Widget v(double n, {bool scaled = true}) => SizedBox(height: DS.gv(n, scaled: scaled));

  /// Horizontal gap between side-by-side widgets: SizedBox(width: DS.gh(n)).
  static Widget h(double n, {bool scaled = true}) => SizedBox(width: DS.gh(n, scaled: scaled));
}
